import Foundation
import Postbox

public final class VeilgramDeletedMessageAttribute: MessageAttribute, Equatable {
    public let deletedAt: Int32

    public var associatedMessageIds: [MessageId] {
        return []
    }

    public var associatedPeerIds: [PeerId] {
        return []
    }

    public var automaticTimestampBasedAttribute: (UInt32, Int32)? {
        return nil
    }

    public init(deletedAt: Int32) {
        self.deletedAt = deletedAt
    }

    public required init(decoder: PostboxDecoder) {
        self.deletedAt = decoder.decodeInt32ForKey("t", orElse: 0)
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.deletedAt, forKey: "t")
    }

    public static func == (lhs: VeilgramDeletedMessageAttribute, rhs: VeilgramDeletedMessageAttribute) -> Bool {
        return lhs.deletedAt == rhs.deletedAt
    }
}

public extension Message {
    var veilgramDeletedMessageAttribute: VeilgramDeletedMessageAttribute? {
        return self.attributes.first(where: { $0 is VeilgramDeletedMessageAttribute }) as? VeilgramDeletedMessageAttribute
    }

    var veilgramIsLocallyRetainedDeletedMessage: Bool {
        return self.veilgramDeletedMessageAttribute != nil
    }
}
