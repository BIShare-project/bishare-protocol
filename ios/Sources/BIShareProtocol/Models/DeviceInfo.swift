import Foundation

/// Device information exchanged during discovery and transfer.
public struct DeviceInfo: Codable, Sendable {
    public var alias: String
    public var version: String
    public var deviceModel: String?
    public var deviceType: String?
    public var fingerprint: String
    public var port: Int
    public var protocol_: String
    public var download: Bool
    public var publicKey: String?

    enum CodingKeys: String, CodingKey {
        case alias, version, deviceModel, deviceType, fingerprint, port
        case protocol_ = "protocol"
        case download, publicKey
    }

    public init(
        alias: String,
        version: String = BIShareConfig.version,
        deviceModel: String? = nil,
        deviceType: String? = nil,
        fingerprint: String,
        port: Int = Int(BISharePort.main),
        protocol_: String = BIShareConfig.protocolScheme,
        download: Bool = false,
        publicKey: String? = nil
    ) {
        self.alias = alias
        self.version = version
        self.deviceModel = deviceModel
        self.deviceType = deviceType
        self.fingerprint = fingerprint
        self.port = port
        self.protocol_ = protocol_
        self.download = download
        self.publicKey = publicKey
    }
}
