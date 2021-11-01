//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

import Foundation
import SignalMessaging
import UIKit

@objc
class ProfileSettingsViewController: OWSTableViewController2 {

    private var hasUnsavedChanges = false {
        didSet { updateNavigationItem() }
    }

    private var avatarData: Data?
    private var givenName: String?
    private var familyName: String?
    private var username: String?
    private var bio: String?
    private var bioEmoji: String?
    private var primaryBadge: ProfileBadge?

    override func viewDidLoad() {
        super.viewDidLoad()

        owsAssertDebug(navigationController != nil)

        title = NSLocalizedString("PROFILE_VIEW_TITLE", comment: "Title for the profile view.")

        defaultSeparatorInsetLeading = Self.cellHInnerMargin + 24 + OWSTableItem.iconSpacing

        let snapshot = profileManagerImpl.localProfileSnapshot(shouldIncludeAvatar: true)
        avatarData = snapshot.avatarData
        givenName = snapshot.givenName
        familyName = snapshot.familyName
        username = snapshot.username
        bio = snapshot.bio
        bioEmoji = snapshot.bioEmoji
        primaryBadge = nil// snapshot.profileBadgeInfo.first?

        updateTableContents()
    }

    private var fullName: String? {
        guard givenName?.isEmpty == false || familyName?.isEmpty == false else { return nil }
        var nameComponents = PersonNameComponents()
        nameComponents.givenName = givenName
        nameComponents.familyName = familyName
        return OWSFormat.formatNameComponents(nameComponents)
    }

    func updateTableContents() {
        let contents = OWSTableContents()

        let avatarSection = OWSTableSection(header: nil, items: [
            OWSTableItem(customCellBlock: { [weak self] in
                self?.avatarCell() ?? UITableViewCell()
            }, actionBlock: nil),

            OWSTableItem(customCellBlock: { [weak self] in
                self?.changeAvatarCell() ?? UITableViewCell()
            }, actionBlock: { [weak self] in
                self?.presentAvatarSettingsView()
            })
        ])
        avatarSection.hasBackground = false
        contents.addSection(avatarSection)

        let mainSection = OWSTableSection()
        mainSection.footerAttributedTitle = NSAttributedString.composed(of: [
            NSLocalizedString("PROFILE_VIEW_PROFILE_DESCRIPTION",
                              comment: "Description of the user profile."),
            " ",
            CommonStrings.learnMore.styled(
                with: .link(URL(string: "https://support.signal.org/hc/articles/360007459591")!)
            )
        ]).styled(
            with: .font(.ows_dynamicTypeCaption1Clamped),
            .color(Theme.secondaryTextAndIconColor)
        )
        mainSection.add(.disclosureItem(
            icon: .settingsProfile,
            name: fullName ?? NSLocalizedString(
                "PROFILE_SETTINGS_NAME_PLACEHOLDER",
                comment: "Placeholder when the user doesn't have a 'name' defined for profile settings screen."
            ),
            accessibilityIdentifier: UIView.accessibilityIdentifier(in: self, name: "name"),
            actionBlock: { [weak self] in
                guard let self = self else { return }
                let vc = ProfileNameViewController(givenName: self.givenName, familyName: self.familyName, profileDelegate: self)
                self.presentFormSheet(OWSNavigationController(rootViewController: vc), animated: true)
            }
        ))
        if RemoteConfig.usernames {
            mainSection.add(.disclosureItem(
                icon: .settingsMention,
                name: username ?? NSLocalizedString(
                    "PROFILE_SETTINGS_USERNAME_PLACEHOLDER",
                    comment: "Placeholder when the user doesn't have a 'username' defined for profile settings screen."
                ),
                accessibilityIdentifier: UIView.accessibilityIdentifier(in: self, name: "username"),
                actionBlock: { [weak self] in
                    let vc = UsernameViewController(username: self?.username)
                    self?.presentFormSheet(OWSNavigationController(rootViewController: vc), animated: true)
                }
            ))
        }
        mainSection.add(.disclosureItem(
            icon: .settingsAbout,
            name: OWSUserProfile.bioForDisplay(bio: bio, bioEmoji: bioEmoji) ?? NSLocalizedString(
                "PROFILE_SETTINGS_BIO_PLACEHOLDER",
                comment: "Placeholder when the user doesn't have an 'about' for profile settings screen."
            ),
            accessibilityIdentifier: UIView.accessibilityIdentifier(in: self, name: "about"),
            actionBlock: { [weak self] in
                guard let self = self else { return }
                let vc = ProfileBioViewController(bio: self.bio, bioEmoji: self.bioEmoji, profileDelegate: self)
                self.presentFormSheet(OWSNavigationController(rootViewController: vc), animated: true)
            }
        ))
        contents.addSection(mainSection)

        self.contents = contents
    }

    func presentAvatarSettingsView() {
        let currentAvatarImage: UIImage? = {
            guard let avatarData = avatarData else { return nil }
            return UIImage(data: avatarData)
        }()

        let vc = AvatarSettingsViewController(
            context: .profile,
            currentAvatarImage: currentAvatarImage
        ) { [weak self] newAvatarImage in
            self?.setAvatarImage(newAvatarImage)
        }
        presentFormSheet(OWSNavigationController(rootViewController: vc), animated: true)
    }

    // MARK: - Event Handling

    override func themeDidChange() {
        super.themeDidChange()
        updateTableContents()
    }

    private func leaveViewCheckingForUnsavedChanges() {
        if !hasUnsavedChanges {
            // If user made no changes, return to conversation settings view.
            profileCompleted()
            return
        }

        OWSActionSheets.showPendingChangesActionSheet(discardAction: { [weak self] in
            self?.profileCompleted()
        })
    }

    private func updateNavigationItem() {
        if hasUnsavedChanges {
            // If we have a unsaved changes, right item should be a "save" button.
            let saveButton = UIBarButtonItem(
                barButtonSystemItem: .save,
                target: self,
                action: #selector(updateProfile),
                accessibilityIdentifier: "save_button"
            )
            navigationItem.rightBarButtonItem = saveButton
        } else {
            navigationItem.rightBarButtonItem = nil
        }
    }

    @objc
    func updateProfile() {

        let normalizedGivenName = self.normalizedGivenName
        let normalizedFamilyName = self.normalizedFamilyName
        let normalizedBio = self.normalizedBio
        let normalizedBioEmoji = self.normalizedBioEmoji

        if !self.reachabilityManager.isReachable {
            OWSActionSheets.showErrorAlert(message: NSLocalizedString("PROFILE_VIEW_NO_CONNECTION",
                                                                      comment: "Error shown when the user tries to update their profile when the app is not connected to the internet."))
            return
        }

        // Show an activity indicator to block the UI during the profile upload.
        let avatarData = self.avatarData
        ModalActivityIndicatorViewController.present(fromViewController: self,
                                                     canCancel: false) { modalActivityIndicator in
            firstly(on: .global()) { () -> Promise<Void> in
                OWSProfileManager.updateLocalProfilePromise(profileGivenName: normalizedGivenName,
                                                            profileFamilyName: normalizedFamilyName,
                                                            profileBio: normalizedBio,
                                                            profileBioEmoji: normalizedBioEmoji,
                                                            profileAvatarData: avatarData,
                                                            userProfileWriter: .localUser)
            }.done(on: .main) { _ in
                modalActivityIndicator.dismiss { [weak self] in
                    AssertIsOnMainThread()
                    self?.profileCompleted()
                }
            }.catch(on: .main) { error in
                owsFailDebug("Error: \(error)")
                modalActivityIndicator.dismiss { [weak self] in
                    AssertIsOnMainThread()
                    self?.profileCompleted()
                }
            }
        }
    }

    private var normalizedGivenName: String {
        (givenName ?? "").ows_stripped()
    }

    private var normalizedFamilyName: String {
        (familyName ?? "").ows_stripped()
    }

    private var normalizedBio: String? {
        bio?.ows_stripped()
    }

    private var normalizedBioEmoji: String? {
        bioEmoji?.ows_stripped()
    }

    private func profileCompleted() {
        AssertIsOnMainThread()
        Logger.verbose("")

        navigationController?.popViewController(animated: true)
    }

    // MARK: - Avatar

    private func avatarCell() -> UITableViewCell {
        let cell = OWSTableItem.newCell()

        cell.selectionStyle = .none

        let badgedAvatarView = ConversationAvatarView(sizeClass: .xlarge, badged: true)
        badgedAvatarView.updateWithSneakyTransactionIfNecessary { config in
            if let avatarData = avatarData {
                config.dataSource = .asset(avatar: UIImage(data: avatarData), badge: nil)
            } else if let address = tsAccountManager.localAddress {
                config.dataSource = .address(address)
            } else {
                config.dataSource = nil
            }
            return .asynchronously
        }

        cell.contentView.addSubview(badgedAvatarView)
        badgedAvatarView.autoPinHeightToSuperviewMargins()
        badgedAvatarView.autoHCenterInSuperview()
        return cell
    }

    private func changeAvatarCell() -> UITableViewCell {
        let cell = OWSTableItem.newCell()
        cell.selectionStyle = .none

        let changeLabel = UILabel()
        changeLabel.font = .ows_dynamicTypeBody2.ows_semibold
        changeLabel.textAlignment = .center
        changeLabel.text = "Change Photo" // localize

        // TODO: Badges — Dark theme?
        changeLabel.textColor = Theme.isDarkThemeEnabled ? .ows_gray05 : .ows_gray95

        cell.contentView.addSubview(changeLabel)
        changeLabel.autoPinEdgesToSuperviewMargins()
        return cell
    }

    private func setAvatarImage(_ avatarImage: UIImage?) {
        AssertIsOnMainThread()

        var avatarData: Data?
        if let avatarImage = avatarImage {
            avatarData = OWSProfileManager.avatarData(forAvatarImage: avatarImage)
        }
        hasUnsavedChanges = hasUnsavedChanges || avatarData != self.avatarData
        self.avatarData = avatarData

        updateTableContents()
    }
}

extension ProfileSettingsViewController: OWSNavigationView {

    @available(iOS 13, *)
    override public var isModalInPresentation: Bool {
        get { hasUnsavedChanges }
        set { /* noop superclass requirement */ }
    }

    public func shouldCancelNavigationBack() -> Bool {
        let result = hasUnsavedChanges
        if result {
            leaveViewCheckingForUnsavedChanges()
        }
        return result
    }
}

extension ProfileSettingsViewController: ProfileBioViewControllerDelegate {

    public func profileBioViewDidComplete(bio: String?, bioEmoji: String?) {
        hasUnsavedChanges = hasUnsavedChanges || bio != self.bio || bioEmoji != self.bioEmoji

        self.bio = bio
        self.bioEmoji = bioEmoji

        updateTableContents()
    }
}

extension ProfileSettingsViewController: ProfileNameViewControllerDelegate {
    func profileNameViewDidComplete(givenName: String?, familyName: String?) {
        hasUnsavedChanges = hasUnsavedChanges || givenName != self.givenName || familyName != self.familyName

        self.givenName = givenName
        self.familyName = familyName

        updateTableContents()
    }
}
