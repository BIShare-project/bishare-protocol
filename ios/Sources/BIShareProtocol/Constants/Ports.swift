import Foundation

/// BIShare network port definitions.
/// All ports are in the dynamic/private range (49152–65535).
public enum BISharePort {
    /// Main transfer server — TCP HTTP (was 53317, now independent from LocalSend)
    public static let main: UInt16 = 58317

    /// QUIC transport + Clipboard sync — UDP (was 53318)
    public static let quic: UInt16 = 58318

    /// Transfer Rooms — TCP HTTP (was 53319)
    public static let room: UInt16 = 58319

    /// WebDAV Server — TCP (was 53320, iOS/macOS only)
    public static let webdav: UInt16 = 58320
}
