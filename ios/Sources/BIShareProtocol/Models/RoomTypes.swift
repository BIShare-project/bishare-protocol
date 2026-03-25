import Foundation

/// A file shared within a transfer room.
public struct RoomFileItem: Codable, Identifiable, Sendable {
    public let id: String
    public let fileName: String
    public let fileType: String
    public let size: Int64
    public let ownerAlias: String
    public let ownerFingerprint: String
    public let addedAt: String

    public init(
        id: String,
        fileName: String,
        fileType: String,
        size: Int64,
        ownerAlias: String,
        ownerFingerprint: String,
        addedAt: String
    ) {
        self.id = id
        self.fileName = fileName
        self.fileType = fileType
        self.size = size
        self.ownerAlias = ownerAlias
        self.ownerFingerprint = ownerFingerprint
        self.addedAt = addedAt
    }
}

/// A member within a transfer room.
public struct RoomMember: Codable, Identifiable, Sendable {
    public var id: String { fingerprint }
    public let fingerprint: String
    public let alias: String
    public let deviceType: String
    public let host: String
    public let port: Int

    public init(fingerprint: String, alias: String, deviceType: String, host: String, port: Int) {
        self.fingerprint = fingerprint
        self.alias = alias
        self.deviceType = deviceType
        self.host = host
        self.port = port
    }
}

/// Room metadata returned by GET /api/v1/room/info.
public struct RoomInfo: Codable, Sendable {
    public let code: String
    public let hostAlias: String
    public let hostFingerprint: String
    public let memberCount: Int
    public let fileCount: Int

    public init(code: String, hostAlias: String, hostFingerprint: String, memberCount: Int, fileCount: Int) {
        self.code = code
        self.hostAlias = hostAlias
        self.hostFingerprint = hostFingerprint
        self.memberCount = memberCount
        self.fileCount = fileCount
    }
}
