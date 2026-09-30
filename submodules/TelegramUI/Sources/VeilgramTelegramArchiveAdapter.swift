import Foundation
import Postbox
import TelegramCore

/// Converts already-local Telegram message values into Veilgram-owned archive
/// DTOs. It performs no reads, network requests, database writes or update
/// interception.
enum VeilgramTelegramArchiveAdapter {
    static func eligibility(for message: Message) -> VeilgramMessageArchiveEligibility {
        let isSecretPeer = message.id.peerId.namespace == Namespaces.Peer.SecretChat
        let isOrdinaryCloud = message.id.namespace == Namespaces.Message.Cloud && !isSecretPeer
        let timeout = message.minAutoremoveOrClearTimeout
        let hasEphemeralAttribute = message.attributes.contains {
            $0 is EphemeralMessageAttribute || $0 is EphemeralOutgoingMessageAttribute
        }

        return VeilgramMessageArchiveEligibility(
            isCloudMessage: isOrdinaryCloud,
            isSecretChat: isSecretPeer,
            isViewOnce: timeout == viewOnceTimeout,
            hasSelfDestructTimeout: timeout != nil || hasEphemeralAttribute
        )
    }

    static func editEligibility(for message: Message) -> VeilgramEditHistoryEligibility {
        let value = eligibility(for: message)
        return VeilgramEditHistoryEligibility(
            isCloudMessage: value.isCloudMessage,
            isSecretChat: value.isSecretChat,
            isViewOnce: value.isViewOnce,
            hasSelfDestructTimeout: value.hasSelfDestructTimeout
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

        return VeilgramArchivedMessage(
            key: VeilgramArchivedMessageKey(
                peerId: message.id.peerId.toInt64(),
                namespace: message.id.namespace,
                id: message.id.id
            ),
            messageTimestamp: message.timestamp,
            archivedAt: archivedAt,
            text: message.text,
            entities: archiveEntities(from: message),
            hadMedia: !message.media.isEmpty
        )
    }

    static func editRevision(
        from message: Message,
        observedAt: Int32
    ) throws -> VeilgramEditHistoryRevision? {
        let eligibility = editEligibility(for: message)
        guard VeilgramEditHistoryEngine.isEligible(eligibility) else {
            return nil
        }

        let revision = VeilgramEditHistoryRevision(
            timestamp: observedAt,
            text: message.text,
            entities: editEntities(from: message)
        )
        try VeilgramEditHistoryEngine.validate(revision)
        return revision
    }

    static func messageKey(from message: Message) -> VeilgramEditHistoryMessageKey {
        return VeilgramEditHistoryMessageKey(
            peerId: message.id.peerId.toInt64(),
            namespace: message.id.namespace,
            id: message.id.id
        )
    }

    private static func archiveEntities(from message: Message) -> [VeilgramArchivedMessageEntity] {
        guard let attribute = message.attributes.first(where: {
            $0 is TextEntitiesMessageAttribute
        }) as? TextEntitiesMessageAttribute else {
            return []
        }
        return attribute.entities.compactMap { entity in
            guard let kind = entityKind(entity.type) else {
                return nil
            }
            return VeilgramArchivedMessageEntity(
                offset: entity.range.lowerBound,
                length: entity.range.count,
                kind: kind
            )
        }
    }

    private static func editEntities(from message: Message) -> [VeilgramEditHistoryEntity] {
        guard let attribute = message.attributes.first(where: {
            $0 is TextEntitiesMessageAttribute
        }) as? TextEntitiesMessageAttribute else {
            return []
        }
        return attribute.entities.compactMap { entity in
            guard let kind = entityKind(entity.type) else {
                return nil
            }
            return VeilgramEditHistoryEntity(
                offset: entity.range.lowerBound,
                length: entity.range.count,
                kind: kind
            )
        }
    }

    /// Archive metadata intentionally records only semantic formatting kind.
    /// Associated URL/peer/file identifiers are not duplicated into this
    /// generic field. The visible text remains the source of displayed data.
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
