import Foundation

/// Active transfer session (in-memory tracking on server side).
public struct TransferSession: Sendable {
    public let sessionId: String
    public let senderInfo: DeviceInfo
    public let files: [String: FileMetadata]
    public let tokens: [String: String]
    public var uploadedFiles: Set<String>
    public let createdAt: Date
    public var encryptionKey: Data?

    public init(
        sessionId: String,
        senderInfo: DeviceInfo,
        files: [String: FileMetadata],
        tokens: [String: String],
        uploadedFiles: Set<String> = [],
        createdAt: Date = Date(),
        encryptionKey: Data? = nil
    ) {
        self.sessionId = sessionId
        self.senderInfo = senderInfo
        self.files = files
        self.tokens = tokens
        self.uploadedFiles = uploadedFiles
        self.createdAt = createdAt
        self.encryptionKey = encryptionKey
    }
}

/// Received file metadata (no file Data in memory — only metadata + path).
public struct ReceivedFile: Identifiable, Sendable {
    public let id: String
    public let fileName: String
    public let size: Int64
    public let fileType: String
    public let savedURL: URL
    public let senderAlias: String
    public let receivedAt: Date
    public let verified: Bool
    public var encrypted: Bool
    public var expiresAt: Date?

    public init(
        id: String,
        fileName: String,
        size: Int64,
        fileType: String,
        savedURL: URL,
        senderAlias: String,
        receivedAt: Date = Date(),
        verified: Bool,
        encrypted: Bool = false,
        expiresAt: Date? = nil
    ) {
        self.id = id
        self.fileName = fileName
        self.size = size
        self.fileType = fileType
        self.savedURL = savedURL
        self.senderAlias = senderAlias
        self.receivedAt = receivedAt
        self.verified = verified
        self.encrypted = encrypted
        self.expiresAt = expiresAt
    }

    /// Whether this file has expired (self-destruct).
    public var isExpired: Bool {
        guard let exp = expiresAt else { return false }
        return Date() >= exp
    }

    /// Human-readable remaining time before expiry.
    public var timeRemaining: String? {
        guard let exp = expiresAt else { return nil }
        let remaining = exp.timeIntervalSince(Date())
        if remaining <= 0 { return "Expired" }
        if remaining < 60 { return "\(Int(remaining))s" }
        if remaining < 3600 { return "\(Int(remaining / 60))m" }
        if remaining < 86400 { return "\(Int(remaining / 3600))h" }
        return "\(Int(remaining / 86400))d"
    }
}

/// File info for browser download list.
public struct SharedFileInfo: Codable, Sendable {
    public let index: Int
    public let fileName: String
    public let fileType: String
    public let size: Int64

    public init(index: Int, fileName: String, fileType: String, size: Int64) {
        self.index = index
        self.fileName = fileName
        self.fileType = fileType
        self.size = size
    }
}
