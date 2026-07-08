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
    public var supportsBinary: Bool?
    public var supportsCompression: Bool?
    public var supportsKeepAlive: Bool?
    /// The device's own LAN IPv4 address, self-reported so peers don't have to rely on the
    /// transport-resolved endpoint. Over Apple's AWDL peer-to-peer Wi-Fi, Bonjour resolves
    /// Apple↔Apple peers to an IPv6 link-local address (fe80::…%enX) that later direct HTTP
    /// connections can't reach — trusting this field instead makes discovery reliable.
    public var ip: String?

    enum CodingKeys: String, CodingKey {
        case alias, version, deviceModel, deviceType, fingerprint, port
        case protocol_ = "protocol"
        case download, publicKey, supportsBinary, supportsCompression, supportsKeepAlive, ip
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
        publicKey: String? = nil,
        supportsBinary: Bool? = true,
        supportsCompression: Bool? = nil,
        supportsKeepAlive: Bool? = nil,
        ip: String? = nil
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
        self.supportsBinary = supportsBinary
        self.supportsCompression = supportsCompression
        self.supportsKeepAlive = supportsKeepAlive
        self.ip = ip
    }
}
