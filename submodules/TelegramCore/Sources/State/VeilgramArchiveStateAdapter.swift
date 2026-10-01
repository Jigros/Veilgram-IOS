import Foundation
import Postbox
import VeilgramLocalFeatures

enum VeilgramArchiveStateAdapter {
    static func eligibility(for message: Message) -> VeilgramArchiveEligibility {
        let isSecretPeer = message.id.peerId.namespace == Namespaces.Peer.SecretChat
        let isOrdinaryCloud = message.id.namespace == Namespaces.Message.Cloud && !isSecretPeer
        let timeout = message.minAutoremoveOrClearTimeout
        let hasEphemeralAttribute = message.attributes.contains {
            $0 is EphemeralMessageAttribute || $0 is EphemeralOutgoingMessageAttribute
        }

        return VeilgramArchiveEligibility(
            isCloudMessage: isOrdinaryCloud,
            isSecretChat: isSecretPeer,
            isViewOnce: timeout == viewOnceTimeout,
            hasSelfDestructTimeout: timeout != nil || hasEphemeralAttribute
        )
    }

    static func shouldRetainDeletedMessage(
        accountPeerId: PeerId,
        message: Message
    ) -> Bool {
        return VeilgramArchiveRuntimePreferences.messageArchiveEnabled(
            accountPeerId: accountPeerId.toInt64()
        ) && eligibility(for: message).isEligibleForLocalRetention
    }

    static func retainedDeletedStoreMessage(
        _ message: Message,
        deletedAt: Int32
    ) -> StoreMessage {
        var attributes = message.attributes.filter { !($0 is VeilgramDeletedMessageAttribute) }
        attributes.append(VeilgramDeletedMessageAttribute(deletedAt: deletedAt))
        return StoreMessage(
            id: message.id,
            customStableId: nil,
            globallyUniqueId: message.globallyUniqueId,
            groupingKey: message.groupingKey,
            threadId: message.threadId,
            timestamp: message.timestamp,
            flags: StoreMessageFlags(message.flags),
            tags: message.tags,
            globalTags: message.globalTags,
            localTags: message.localTags,
            forwardInfo: message.forwardInfo.flatMap(StoreMessageForwardInfo.init),
            authorId: message.author?.id,
            text: message.text,
            attributes: attributes,
            media: message.media
        )
    }

    static func enqueueDeletedMessage(
        accountPeerId: PeerId,
        message: Message,
        observedAt: Int32
    ) {
        let eligibility = eligibility(for: message)
        guard eligibility.isEligibleForLocalRetention else {
            return
        }

        let snapshot = VeilgramArchivedMessage(
            key: messageKey(message),
            messageTimestamp: message.timestamp,
            archivedAt: observedAt,
            text: message.text,
            entities: entities(from: message),
            hadMedia: !message.media.isEmpty
        )
        guard (try? VeilgramMessageArchiveEngine.validate(snapshot)) != nil else {
            return
        }

        VeilgramArchiveRuntimeWriter.enqueueDeletedMessage(
            accountPeerId: accountPeerId.toInt64(),
            message: snapshot,
            eligibility: eligibility
        )
    }

    static func enqueuePreviousEditRevision(
        accountPeerId: PeerId,
        message: Message,
        observedAt: Int32
    ) {
        let eligibility = eligibility(for: message)
        guard eligibility.isEligibleForLocalRetention else {
            return
        }

        let revision = VeilgramEditRevision(
            timestamp: observedAt,
            text: message.text,
            entities: entities(from: message)
        )
        guard (try? VeilgramEditHistoryEngine.validate(revision)) != nil else {
            return
        }

        VeilgramArchiveRuntimeWriter.enqueuePreviousEditRevision(
            accountPeerId: accountPeerId.toInt64(),
            key: messageKey(message),
            revision: revision,
            eligibility: eligibility
        )
    }

    private static func messageKey(_ message: Message) -> VeilgramMessageKey {
        return VeilgramMessageKey(
            peerId: message.id.peerId.toInt64(),
            namespace: message.id.namespace,
            id: message.id.id
        )
    }

    private static func entities(from message: Message) -> [VeilgramTextEntity] {
        guard let attribute = message.attributes.first(where: {
            $0 is TextEntitiesMessageAttribute
        }) as? TextEntitiesMessageAttribute else {
            return []
        }
        return attribute.entities.compactMap { entity in
            guard let kind = entityKind(entity.type) else {
                return nil
            }
            return VeilgramTextEntity(
                offset: entity.range.lowerBound,
                length: entity.range.count,
                kind: kind
            )
        }
    }

    private static func entityKind(_ type: MessageTextEntityType) -> String? {
        switch type {
        case .Unknown:
            return nil
        case .Mention:
            return "mention"
        case .Hashtag:
            return "hashtag"
        case .BotCommand:
            return "botCommand"
        case .Url:
            return "url"
        case .Email:
            return "email"
        case .Bold:
            return "bold"
        case .Italic:
            return "italic"
        case .Code:
            return "code"
        case .Pre:
            return "pre"
        case .TextUrl:
            return "textUrl"
        case .TextMention:
            return "textMention"
        case .PhoneNumber:
            return "phoneNumber"
        case .Strikethrough:
            return "strikethrough"
        case .BlockQuote:
            return "blockQuote"
        case .Underline:
            return "underline"
        case .BankCard:
            return "bankCard"
        case .Spoiler:
            return "spoiler"
        case .CustomEmoji:
            return "customEmoji"
        case .FormattedDate:
            return "formattedDate"
        case .Custom:
            return "custom"
        }
    }
}
