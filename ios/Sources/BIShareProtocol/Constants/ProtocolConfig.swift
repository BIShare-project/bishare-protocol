import Foundation

/// Protocol-level configuration constants.
public enum BIShareConfig {
    /// Protocol version sent in DeviceInfo
    public static let version = "2.0"
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
}
