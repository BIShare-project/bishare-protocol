import Foundation

/// Metadata for a file being transferred.
public struct FileMetadata: Codable, Sendable {
    public let id: String
    public let fileName: String
    public let size: Int64
    public let fileType: String
    public let sha256: String?
    public let preview: String?
    public let expiresInSeconds: Int?

    public init(
        id: String,
        fileName: String,
        size: Int64,
        fileType: String,
        sha256: String? = nil,
        preview: String? = nil,
        expiresInSeconds: Int? = nil
    ) {
        self.id = id
        self.fileName = fileName
        self.size = size
        self.fileType = fileType
        self.sha256 = sha256
        self.preview = preview
        self.expiresInSeconds = expiresInSeconds
    }
}
