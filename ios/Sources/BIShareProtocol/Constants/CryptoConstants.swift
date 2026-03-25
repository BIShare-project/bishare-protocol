import Foundation

/// Cryptographic constants for BIShare E2E encryption.
public enum BIShareCrypto {
    // MARK: - E2E File Transfer (Curve25519 ECDH)

    /// HKDF salt for local E2E file transfer
    public static let e2eSalt = "BIShare-E2E"
    /// HKDF info for local E2E file transfer
    public static let e2eInfo = "file-transfer"

    // MARK: - Remote Transfer (symmetric key from share code)

    /// HKDF salt for remote transfer via relay
    public static let remoteSalt = "BIShare-Remote"
    /// HKDF info for remote transfer via relay
    public static let remoteInfo = "remote-transfer-v2"

    // MARK: - AES-256-GCM Parameters

    /// AES key size in bytes (256 bits)
    public static let aesKeySize = 32
    /// GCM nonce size in bytes
    public static let gcmNonceSize = 12
    /// GCM authentication tag size in bits
    public static let gcmTagBits = 128

    // MARK: - Key Fingerprint

    /// Number of SHA-256 hash bytes used for visual fingerprint
    public static let fingerprintBytes = 8
}
