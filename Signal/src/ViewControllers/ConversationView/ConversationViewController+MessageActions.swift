//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

import Foundation

extension ConversationViewController {

    func presentMessageActions(_ messageActions: [MessageAction],
                               withFocusedCell cell: UICollectionViewCell,
                               itemViewModel: CVItemViewModelImpl) {
        guard let window = view.window,
              let navigationController = navigationController else {
            owsFailDebug("Missing window or navigationController.")
            return
        }
        if FeatureFlags.contextMenus {
            let interaction = ChatHistoryContextMenuInteraction(delegate: self, itemViewModel: itemViewModel, thread: thread, messageActions: messageActions, initiatingGestureRecognizer: collectionViewLongPressGestureRecognizer)
            collectionViewActiveContextMenuInteraction = interaction
            cell.addInteraction(interaction)
            let cellCenterPoint = cell.frame.center
            let screenPoint = self.collectionView .convert(cellCenterPoint, from: cell)
            interaction.presentMenu(locationInView: screenPoint)
        } else {
            let messageActionsViewController = MessageActionsViewController(itemViewModel: itemViewModel,
                                                                            focusedView: cell,
                                                                            actions: messageActions)
            messageActionsViewController.delegate = self

            self.messageActionsViewController = messageActionsViewController

            setupMessageActionsState(forCell: cell)

            messageActionsViewController.present(on: window,
                                                 prepareConstraints: {
                                                    // In order to ensure the bottom bar remains above the keyboard, we pin it
                                                    // to our bottom bar which follows the inputAccessoryView
                                                    messageActionsViewController.bottomBar.autoPinEdge(.bottom,
                                                                                                       to: .bottom,
                                                                                                       of: self.bottomBar)

                                                    // We only want the message actions to show up over the detail view, in
                                                    // the case where we are expanded. So match its edges to our nav controller.
                                                    messageActionsViewController.view.autoPinEdges(toEdgesOf: navigationController.view)
                                                 },
                                                 animateAlongside: {
                                                    self.bottomBar.alpha = 0
                                                 },
                                                 completion: nil)
        }
    }

    func updateMessageActionsState(forCell cell: UIView) {
        // While presenting message actions, cache the original content offset.
        // This allows us to restore the user to their original scroll position
        // when they dismiss the menu.
        self.messageActionsOriginalContentOffset = self.collectionView.contentOffset
        self.messageActionsOriginalFocusY = self.view.convert(cell.frame.origin, from: self.collectionView).y
    }

    func setupMessageActionsState(forCell cell: UIView) {
        guard let navigationController = navigationController else {
            owsFailDebug("Missing navigationController.")
            return
        }
        updateMessageActionsState(forCell: cell)

        // While the menu actions are presented, temporarily use extra content
        // inset padding so that interactions near the top or bottom of the
        // collection view can be scrolled anywhere within the viewport.
        // This allows us to keep the message position constant even when
        // messages dissappear above / below the focused message to the point
        // that we have less than one screen worth of content.
        let navControllerSize = navigationController.view.frame.size
        self.messageActionsExtraContentInsetPadding = max(navControllerSize.width, navControllerSize.height)

        var contentInset = self.collectionView.contentInset
        contentInset.top += self.messageActionsExtraContentInsetPadding
        contentInset.bottom += self.messageActionsExtraContentInsetPadding
        self.collectionView.contentInset = contentInset
    }

    func clearMessageActionsState() {
        self.bottomBar.alpha = 1

        var contentInset = self.collectionView.contentInset
        contentInset.top -= self.messageActionsExtraContentInsetPadding
        contentInset.bottom -= self.messageActionsExtraContentInsetPadding
        self.collectionView.contentInset = contentInset

        // TODO: This isn't safe. We should capture a token that represents scroll state.
        self.collectionView.contentOffset = self.messageActionsOriginalContentOffset
        self.messageActionsOriginalContentOffset = .zero
        self.messageActionsExtraContentInsetPadding = 0
        self.messageActionsViewController = nil
    }

    public var isPresentingMessageActions: Bool {
        self.messageActionsViewController != nil
    }

    @objc
    public func dismissMessageActions(animated: Bool) {
        dismissMessageActions(animated: animated, completion: nil)
    }

    public typealias MessageActionsCompletion = () -> Void

    public func dismissMessageActions(animated: Bool, completion: MessageActionsCompletion?) {
        Logger.verbose("")

        guard let messageActionsViewController = messageActionsViewController else {
            return
        }

        if animated {
            messageActionsViewController.dismiss(animateAlongside: {
                self.bottomBar.alpha = 1
            }, completion: {
                self.clearMessageActionsState()
                completion?()
            })
        } else {
            messageActionsViewController.dismissWithoutAnimating()
            clearMessageActionsState()
            completion?()
        }
    }

    func dismissMessageActionsIfNecessary() {
        if shouldDismissMessageActions {
            dismissMessageActions(animated: true)
        }
    }

    var shouldDismissMessageActions: Bool {
        guard let messageActionsViewController = messageActionsViewController else {
            return false
        }
        let messageActionInteractionId = messageActionsViewController.focusedInteraction.uniqueId
        // Check whether there is still a view item for this interaction.
        return self.indexPath(forInteractionUniqueId: messageActionInteractionId) == nil
    }

    public func reloadReactionsDetailSheet(transaction: SDSAnyReadTransaction) {
        AssertIsOnMainThread()

        guard let reactionsDetailSheet = self.reactionsDetailSheet else {
            return
        }

        let messageId = reactionsDetailSheet.messageId

        guard let indexPath = self.indexPath(forInteractionUniqueId: messageId),
              let renderItem = self.renderItem(forIndex: indexPath.row) else {
            // The message no longer exists, dismiss the sheet.
            dismissReactionsDetailSheet(animated: true)
            return
        }
        guard let reactionState = renderItem.reactionState,
              reactionState.hasReactions else {
            // There are no longer reactions on this message, dismiss the sheet.
            dismissReactionsDetailSheet(animated: true)
            return
        }

        // Update the detail sheet with the latest reaction
        // state, in case the reactions have changed.
        reactionsDetailSheet.setReactionState(reactionState, transaction: transaction)
    }

    public func dismissReactionsDetailSheet(animated: Bool) {
        AssertIsOnMainThread()

        guard let reactionsDetailSheet = self.reactionsDetailSheet else {
            return
        }

        reactionsDetailSheet.dismiss(animated: animated) {
            self.reactionsDetailSheet = nil
        }
    }
}

extension ConversationViewController: ContextMenuInteractionDelegate {

    public func contextMenuInteraction(
        _ interaction: ContextMenuInteraction,
        configurationForMenuAtLocation location: CGPoint) -> ContextMenuConfiguration? {

        return ContextMenuConfiguration.init(identifier: UUID() as NSCopying, actionProvider: { _ in
            let defaultState = ContextMenuAction.init(title: "Default", image: Theme.iconImage(.messageActionReply), attributes: [], handler: { _ in
                Logger.debug("default state handler")
            })

            let disabled = ContextMenuAction.init(title: "Disabled", image: Theme.iconImage(.messageActionSave), attributes: [.disabled], handler: { _ in
                Logger.debug("disabled state handler")
            })

            let highlighted = ContextMenuAction.init(title: "Default 2", image: Theme.iconImage(.messageActionForward), attributes: [], handler: { _ in
                Logger.debug("default 2 state handler")
            })

            let destructive = ContextMenuAction.init(title: "Destructive", image: Theme.iconImage(.messageActionDelete), attributes: [.destructive], handler: { _ in
                Logger.debug("destructive state handler")
            })

            return ContextMenu([defaultState, disabled, highlighted, destructive])
        })
    }

    public func contextMenuInteraction(
        _ interaction: ContextMenuInteraction,
        previewForHighlightingMenuWithConfiguration configuration: ContextMenuConfiguration) -> ContextMenuTargetedPreview? {

        guard let contextInteraction = interaction as? ChatHistoryContextMenuInteraction else {
            owsFailDebug("Expected ChatHistoryContextMenuInteraction.")
            return nil
        }

        guard let cell = contextInteraction.view as? CVCell else {
            owsFailDebug("Expected context interaction view to be of CVCell type")
            return nil
        }

        guard let componentView = cell.componentView else {
            owsFailDebug("Expected cell to have component view")
            return nil
        }

        var accessories = cell.rootComponent?.contextMenuAccessoryViews(componentView: componentView) ?? []

        // Add reaction bar if necessary
        if thread.canSendReactionToThread && shouldShowReactionPickerForInteraction(contextInteraction.itemViewModel.interaction) {
            let reactionBarAccessory = ContextMenuRectionBarAccessory.init(thread: self.thread, itemViewModel: contextInteraction.itemViewModel)
            reactionBarAccessory.didSelectReactionHandler = {(message: TSMessage, reaction: String, isRemoving: Bool) in
                self.databaseStorage.asyncWrite { transaction in
                    ReactionManager.localUserReactedWithDurableSend(to: message,
                                                                    emoji: reaction,
                                                                    isRemoving: isRemoving,
                                                                    transaction: transaction)
                }
            }
            accessories.append(reactionBarAccessory)
        }

        if let componentView = cell.componentView, let contentView = componentView.contextMenuContentView?() {
            return ContextMenuTargetedPreview(view: contentView, accessoryViews: accessories)
        } else {
            return ContextMenuTargetedPreview(view: cell, accessoryViews: accessories)

        }
    }

    public func contextMenuInteraction(_ interaction: ContextMenuInteraction, willEndForConfiguration: ContextMenuConfiguration) {
        collectionViewActiveContextMenuInteraction = nil
    }

}
