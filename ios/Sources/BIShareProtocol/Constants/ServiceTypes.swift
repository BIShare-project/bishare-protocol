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

    /// Wi-Fi Aware service type (iOS 26+ WiFiAwareServices naming)
    public static let aware = "_bishare-aware._tcp"

    /// Android Wi-Fi Aware (NAN) service name, for cross-platform matching
    public static let awareNan = "bishare-aware"
}
