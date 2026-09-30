import Foundation
import Postbox
import TelegramCore
import VeilgramLocalFeatures

/// Telegram-specific conversion layer for Veilgram's local archive core.
/// It performs no network requests, database writes or update interception.
enum VeilgramTelegramArchiveAdapter {
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

    static func messageSnapshot(
        from message: Message,
        archivedAt: Int32
    ) throws -> VeilgramArchivedMessage? {
        let eligibility = eligibility(for: message)
        guard VeilgramMessageArchiveEngine.isEligible(eligibility) else {
            return nil
        }

        let snapshot = VeilgramArchivedMessage(
            key: VeilgramMessageKey(
                peerId: message.id.peerId.toInt64(),
                namespace: message.id.namespace,
                id: message.id.id
            ),
            messageTimestamp: message.timestamp,
            archivedAt: archivedAt,
            text: message.text,
            entities: entities(from: message),
            hadMedia: !message.media.isEmpty
        )
        try VeilgramMessageArchiveEngine.validate(snapshot)
        return snapshot
    }

    static func editRevision(
        from message: Message,
        observedAt: Int32
    ) throws -> VeilgramEditRevision? {
        let eligibility = eligibility(for: message)
        guard eligibility.isEligibleForLocalRetention else {
            return nil
        }

        let revision = VeilgramEditRevision(
            timestamp: observedAt,
            text: message.text,
            entities: entities(from: message)
        )
        try VeilgramEditHistoryEngine.validate(revision)
        return revision
    }

    static func messageKey(from message: Message) -> VeilgramMessageKey {
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
