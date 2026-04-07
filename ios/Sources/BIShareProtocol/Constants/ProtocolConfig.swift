import Foundation

/// Protocol-level configuration constants.
public enum BIShareConfig {
    /// Protocol version sent in DeviceInfo
    public static let version = "2.2"
    /// Default protocol scheme
    public static let protocolScheme = "https"

    // MARK: - Deep Links

    /// URL scheme for local transfers
    public static let scheme = "bishare"

    // MARK: - Code Generation

    /// Character set for room codes (no I, O, 0, 1)
    public static let codeCharset = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    /// Room code length
    public static let roomCodeLength = 4

    // MARK: - Limits

    /// Maximum received files kept in memory (rest persisted to database)
    public static let maxReceivedFilesInMemory = 100
    /// Maximum clipboard history items
    public static let clipboardHistoryMax = 20
    /// Clipboard polling interval in seconds (iOS)
    public static let clipboardPollInterval: TimeInterval = 1.5
    /// Accept/reject dialog timeout in seconds
    public static let acceptRejectTimeout: TimeInterval = 30.0
    /// Device considered stale after this many seconds without being seen
    public static let staleDeviceTimeout: TimeInterval = 15.0

    // MARK: - Parallel Transfer

    /// Default max concurrent file uploads allowed by server
    public static let defaultMaxConcurrent = 4

    // MARK: - Binary Protocol

    /// Protocol version that supports binary transfer (version negotiation)
    public static let binaryProtocolMinVersion = "2.1"
    /// Port offset for binary protocol (main port + 2)
    public static let binaryPortOffset: UInt16 = 2

    // MARK: - Speed Protocol (v2.2)

    /// Protocol version that supports v2.2 speed optimizations
    public static let speedProtocolMinVersion = "2.2"

    /// Default chunk size for binary file data frames (256 KB)
    public static let defaultChunkSize = 256 * 1024

    /// Minimum chunk size allowed in negotiation (64 KB)
    public static let minChunkSize = 64 * 1024

    /// Maximum chunk size allowed in negotiation (1 MB)
    public static let maxChunkSize = 1024 * 1024

    /// Default max concurrent file uploads for v2.2+ peers
    public static let defaultMaxConcurrentV2 = 8

    /// Flow control: number of chunks sender can have in-flight before waiting for ACK
    public static let defaultWindowSize = 16

    /// Compression minimum size threshold — don't compress below this
    public static let compressionMinSize: Int64 = 1024

    /// MIME type prefixes considered compressible
    public static let compressibleMimeTypes: Set<String> = [
        "text/",
        "application/json",
        "application/xml",
        "application/javascript",
        "application/x-yaml",
        "application/svg+xml",
        "application/xhtml+xml",
    ]

    /// Check if a MIME type is likely compressible.
    public static func isCompressible(mimeType: String) -> Bool {
        compressibleMimeTypes.contains { mimeType.hasPrefix($0) || mimeType == $0 }
    }
}
