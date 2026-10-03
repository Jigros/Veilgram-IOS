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
        observedAt: Int32,
        mediaBox: MediaBox? = nil
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

        if let mediaBox {
            enqueueDeletedMedia(
                accountPeerId: accountPeerId,
                messages: [message],
                observedAt: observedAt,
                mediaBox: mediaBox
            )
        }
    }

    static func enqueueDeletedMedia(
        accountPeerId: PeerId,
        messages: [Message],
        observedAt: Int32,
        mediaBox: MediaBox,
        completion: (() -> Void)? = nil
    ) {
        let candidates = messages.flatMap { message in
            localMediaCandidates(
                message: message,
                observedAt: observedAt,
                mediaBox: mediaBox
            )
        }
        VeilgramArchiveRuntimeWriter.enqueueLocalMediaCandidates(
            accountPeerId: accountPeerId.toInt64(),
            candidates: candidates,
            completion: completion
        )
    }

    static func localMediaCandidates(
        message: Message,
        observedAt: Int32,
        mediaBox: MediaBox
    ) -> [VeilgramLocalMediaArchiveCandidate] {
        let eligibility = eligibility(for: message)
        guard eligibility.isEligibleForLocalRetention else {
            return []
        }

        var candidates: [VeilgramLocalMediaArchiveCandidate] = []
        for (mediaIndex, media) in message.effectiveMedia.enumerated() {
            let resource: MediaResource
            let fileExtension: String?
            if let image = media as? TelegramMediaImage,
               let imageResource = image.representations.last?.resource {
                resource = imageResource
                fileExtension = "jpg"
            } else if let file = media as? TelegramMediaFile {
                resource = file.resource
                fileExtension = preferredExtension(for: file)
            } else {
                continue
            }
            candidates.append(
                VeilgramLocalMediaArchiveCandidate(
                    key: VeilgramMediaKey(
                        peerId: message.id.peerId.toInt64(),
                        messageNamespace: message.id.namespace,
                        messageId: message.id.id,
                        mediaIndex: mediaIndex
                    ),
                    sourcePath: mediaBox.completedResourcePath(resource),
                    archivedAt: observedAt,
                    fileExtension: fileExtension,
                    eligibility: eligibility
                )
            )
        }
        return candidates
    }

    private static func preferredExtension(for file: TelegramMediaFile) -> String? {
        if let fileName = file.fileName {
            let pathExtension = (fileName as NSString).pathExtension
            if !pathExtension.isEmpty {
                return pathExtension
            }
        }
        switch file.mimeType.lowercased() {
        case "video/mp4":
            return "mp4"
        case "video/webm":
            return "webm"
        case "application/pdf":
            return "pdf"
        case "application/zip":
            return "zip"
        case "image/jpeg":
            return "jpg"
        case "image/png":
            return "png"
        case "image/webp":
            return "webp"
        case "image/gif":
            return "gif"
        case "audio/ogg", "application/ogg":
            return "ogg"
        case "audio/mpeg":
            return "mp3"
        case "audio/mp4":
            return "m4a"
        default:
            return nil
        }
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
