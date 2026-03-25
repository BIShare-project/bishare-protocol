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
    /// URL scheme for remote transfers
    public static let remoteScheme = "bishare-remote"

    // MARK: - Code Generation

    /// Character set for room codes and remote codes (no I, O, 0, 1)
    public static let codeCharset = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    /// Room code length
    public static let roomCodeLength = 4
    /// Remote transfer lookup code length
    public static let remoteCodeLength = 6
    /// Remote transfer full code length (includes encryption key material)
    public static let remoteFullLength = 16

    // MARK: - Relay

    /// Cloudflare Workers relay base URL
    public static let relayBaseURL = "https://bishare-relay.cakrabudiman.workers.dev"

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
    /// Maximum file size for remote transfer (500 MB)
    public static let remoteFileMaxSize = 500 * 1024 * 1024
    /// Remote transfer expiry in hours
    public static let remoteExpiryHours = 24
}
