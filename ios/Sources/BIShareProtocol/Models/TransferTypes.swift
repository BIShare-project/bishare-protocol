import Foundation

/// Request body for POST /api/v1/prepare.
public struct PrepareRequest: Codable, Sendable {
    public let info: DeviceInfo
    public let files: [String: FileMetadata]

    public init(info: DeviceInfo, files: [String: FileMetadata]) {
        self.info = info
        self.files = files
    }
}

/// Response body from POST /api/v1/prepare.
public struct PrepareResponse: Codable, Sendable {
    public let sessionId: String
    public let files: [String: String]
    public let publicKey: String?
    public let maxConcurrent: Int?
    public let chunkSize: Int?
    public let windowSize: Int?
    public let supportsCompression: Bool?

    public init(
        sessionId: String,
        files: [String: String],
        publicKey: String? = nil,
        maxConcurrent: Int? = nil,
        chunkSize: Int? = nil,
        windowSize: Int? = nil,
        supportsCompression: Bool? = nil
    ) {
        self.sessionId = sessionId
        self.files = files
        self.publicKey = publicKey
        self.maxConcurrent = maxConcurrent
        self.chunkSize = chunkSize
        self.windowSize = windowSize
        self.supportsCompression = supportsCompression
    }
}

/// Response body from POST /api/v1/upload.
public struct UploadResponse: Codable, Sendable {
    public let success: Bool
    public let verified: Bool?
    public let encrypted: Bool?
    public let message: String?

    public init(success: Bool, verified: Bool? = nil, encrypted: Bool? = nil, message: String? = nil) {
        self.success = success
        self.verified = verified
        self.encrypted = encrypted
        self.message = message
    }
}

/// Standard error response body.
public struct ErrorResponse: Codable, Sendable {
    public let message: String

    public init(message: String) {
        self.message = message
    }
}
