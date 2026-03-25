import Foundation

/// All API endpoint paths used by BIShare protocol.
public enum BIShareAPI {
    // MARK: - Transfer Endpoints (port: main)

    /// Device info probe
    public static let info = "/api/v1/info"
    /// Request to send files
    public static let prepare = "/api/v1/prepare"
    /// Upload file binary
    public static let upload = "/api/v1/upload"
    /// Cancel active session
    public static let cancel = "/api/v1/cancel"
    /// File list JSON (browser)
    public static let files = "/api/v1/files"
    /// Download file (browser)
    public static let download = "/api/v1/download"
    /// Download all as ZIP
    public static let downloadAll = "/api/v1/download-all"
    /// Upload from browser
    public static let browserUpload = "/api/v1/browser-upload"
    /// QR instant download (one-time token)
    public static let instant = "/api/v1/instant"
    /// File request (reverse flow)
    public static let request = "/api/v1/request"
    /// Verify PIN (browser)
    public static let verifyPin = "/api/v1/verify-pin"
    /// Disconnect notification
    public static let goodbye = "/api/v1/goodbye"

    // MARK: - Room Endpoints (port: room)

    /// Room metadata
    public static let roomInfo = "/api/v1/room/info"
    /// Join room
    public static let roomJoin = "/api/v1/room/join"
    /// List room files
    public static let roomFiles = "/api/v1/room/files"
    /// Download file from room owner
    public static let roomDownload = "/api/v1/room/download"
    /// Notify new file added to room
    public static let roomFileAdded = "/api/v1/room/file-added"
    /// Host closes room
    public static let roomKicked = "/api/v1/room/kicked"
    /// Notify member joined
    public static let roomMemberJoined = "/api/v1/room/member-joined"
    /// Notify member left
    public static let roomMemberLeft = "/api/v1/room/member-left"
}
