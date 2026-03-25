import Foundation

/// Bonjour/mDNS service type identifiers for discovery.
public enum BIShareService {
    /// Main device discovery service type
    public static let discovery = "_bishare._tcp"

    /// Transfer room discovery service type
    public static let room = "_bishare-room._tcp"

    /// MultipeerConnectivity nearby service type
    public static let nearby = "bishare-nearby"

    /// QUIC ALPN protocol identifier
    public static let quicALPN = ["bishare-quic"]
}
