//
// Copyright 2024 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

#if TESTABLE_BUILD

open class AttachmentStoreMock: AttachmentStore {

    public var attachmentReferences = [AttachmentReference]()
    public var attachments = [Attachment]()

    open func fetchReferences(owners: [AttachmentReference.OwnerId], tx: DBReadTransaction) -> [AttachmentReference] {
        return attachmentReferences.filter { ref in
            return owners.contains(ref.owner.id)
        }
    }

    open func fetch(ids: [Attachment.IDType], tx: DBReadTransaction) -> [Attachment] {
        return attachments.filter { attachment in
            return ids.contains(attachment.id)
        }
    }

    open func enumerateAllReferences(
        toAttachmentId: Attachment.IDType,
        tx: DBReadTransaction,
        block: (AttachmentReference) -> Void
    ) {
        attachmentReferences
            .lazy
            .filter { $0.attachmentRowId == toAttachmentId }
            .forEach(block)
    }

    open func duplicateExistingMessageOwner(
        _ existingOwnerSource: AttachmentReference.Owner.MessageSource,
        with reference: AttachmentReference,
        newOwnerMessageRowId: Int64,
        newOwnerThreadRowId: Int64,
        tx: DBWriteTransaction
    ) throws {}

    open func duplicateExistingThreadOwner(
        _ existingOwnerSource: AttachmentReference.Owner.ThreadSource,
        with reference: AttachmentReference,
        newOwnerThreadRowId: Int64,
        tx: DBWriteTransaction
    ) throws {}

    open func update(
        _ reference: AttachmentReference,
        withReceivedAtTimestamp: UInt64,
        tx: DBWriteTransaction
    ) throws {
        // do nothings
    }

    open func addOwner(
        _ reference: AttachmentReference.ConstructionParams,
        for attachmentId: Attachment.IDType,
        tx: DBWriteTransaction
    ) throws {
        // do nothing
    }

    open func removeOwner(
        _ owner: AttachmentReference.OwnerId,
        for attachmentId: Attachment.IDType,
        tx: DBWriteTransaction
    ) throws {
        // do nothing
    }

    open func insert(
        _ attachment: Attachment.ConstructionParams,
        reference: AttachmentReference.ConstructionParams,
        tx: DBWriteTransaction
    ) throws {
        // do nothing
    }

    open func removeAllThreadOwners(tx: DBWriteTransaction) throws {
        // do nothing
    }
}

#endif
