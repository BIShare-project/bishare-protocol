import Foundation

/// Payload for UDP clipboard sync broadcast.
public struct ClipboardPayload: Codable, Sendable {
    public let type: String
    public let text: String
    public let sender: String
    public let alias: String

    public init(text: String, senderFingerprint: String, alias: String) {
        self.type = "clipboard"
        self.text = text
        self.sender = senderFingerprint
        self.alias = alias
    }
}
