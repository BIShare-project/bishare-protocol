import Foundation

/// File request message (reverse flow — requesting files from another device).
public struct FileRequestMessage: Codable, Sendable {
    public let requestId: String
    public let requesterAlias: String
    public let requesterFingerprint: String
    public let requesterHost: String
    public let requesterPort: UInt16
    public let message: String?
    public let requestedTypes: [String]?

    public init(
        requestId: String,
        requesterAlias: String,
        requesterFingerprint: String,
        requesterHost: String,
        requesterPort: UInt16 = BISharePort.main,
        message: String? = nil,
        requestedTypes: [String]? = nil
    ) {
        self.requestId = requestId
        self.requesterAlias = requesterAlias
        self.requesterFingerprint = requesterFingerprint
        self.requesterHost = requesterHost
        self.requesterPort = requesterPort
        self.message = message
        self.requestedTypes = requestedTypes
    }
}

/// Response to a file request.
public struct FileRequestResponse: Codable, Sendable {
    public let requestId: String
    public let accepted: Bool

    public init(requestId: String, accepted: Bool) {
        self.requestId = requestId
        self.accepted = accepted
    }
}
