import Foundation
import CryptoKit

/// Core encryption engine for BIShare E2E file transfers.
///
/// Handles Curve25519 key agreement, HKDF key derivation, and AES-256-GCM encryption/decryption.
/// This class does NOT manage key persistence — the app is responsible for storing/loading `privateKeyData`.
public final class BIShareEncryption: @unchecked Sendable {

    private let privateKey: Curve25519.KeyAgreement.PrivateKey
    public let publicKey: Curve25519.KeyAgreement.PublicKey

    /// Base64-encoded public key for sharing with peers.
    public var publicKeyBase64: String {
        publicKey.rawRepresentation.base64EncodedString()
    }

    /// Raw private key bytes for persistence by the app.
    public var privateKeyData: Data {
        privateKey.rawRepresentation
    }

    /// Initialize with existing private key data, or generate a new key pair.
    /// - Parameter privateKeyData: Previously stored private key bytes. Pass `nil` to generate new.
    public init(privateKeyData: Data? = nil) {
        if let data = privateKeyData,
           let key = try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: data) {
            self.privateKey = key
        } else {
            self.privateKey = Curve25519.KeyAgreement.PrivateKey()
        }
        self.publicKey = self.privateKey.publicKey
    }

    // MARK: - E2E Key Derivation (Curve25519 ECDH)

    /// Fixed 12-byte DER SubjectPublicKeyInfo header for X25519 (RFC 8410)
    private static let x509X25519Prefix = Data([0x30, 0x2a, 0x30, 0x05, 0x06, 0x03, 0x2b, 0x65, 0x6e, 0x03, 0x21, 0x00])

    /// Normalize a peer key to raw 32 bytes: accepts raw 32-byte keys and legacy 44-byte X.509 SPKI (old Android)
    private static func normalizeRawKey(_ data: Data) -> Data? {
        if data.count == 32 { return data }
        if data.count == 44, data.prefix(12) == x509X25519Prefix {
            return data.suffix(32)
        }
        return nil
    }

    /// Derive a shared symmetric key from a peer's public key using ECDH + HKDF.
    /// - Parameter peerPublicKeyBase64: The peer's base64-encoded Curve25519 public key.
    /// - Returns: A `SymmetricKey` for AES-256-GCM, or `nil` if key agreement fails.
    public func deriveSharedKey(peerPublicKeyBase64: String) -> SymmetricKey? {
        guard let peerKeyData = Data(base64Encoded: peerPublicKeyBase64),
              let rawKeyData = Self.normalizeRawKey(peerKeyData),
              let peerKey = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: rawKeyData),
              let shared = try? privateKey.sharedSecretFromKeyAgreement(with: peerKey) else {
            return nil
        }
        return shared.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(BIShareCrypto.e2eSalt.utf8),
            sharedInfo: Data(BIShareCrypto.e2eInfo.utf8),
            outputByteCount: BIShareCrypto.aesKeySize
        )
    }

    // MARK: - AES-256-GCM Encrypt / Decrypt

    /// Encrypt data with AES-256-GCM.
    /// - Returns: Combined data: `nonce(12) + ciphertext + tag(16)`, or `nil` on failure.
    public static func encrypt(data: Data, using key: SymmetricKey) -> Data? {
        guard let sealed = try? AES.GCM.seal(data, using: key) else { return nil }
        return sealed.combined
    }

    /// Decrypt AES-256-GCM combined data.
    /// - Parameter data: Combined format: `nonce(12) + ciphertext + tag(16)`.
    /// - Returns: Decrypted plaintext, or `nil` on failure.
    public static func decrypt(data: Data, using key: SymmetricKey) -> Data? {
        guard let box = try? AES.GCM.SealedBox(combined: data),
              let decrypted = try? AES.GCM.open(box, using: key) else {
            return nil
        }
        return decrypted
    }

    // MARK: - Key Fingerprint

    /// Visual fingerprint of this device's public key (e.g., "A1 B2 C3 D4 E5 F6 G7 H8").
    public var keyFingerprint: String {
        Self.fingerprint(of: publicKey.rawRepresentation)
    }

    /// Generate a visual fingerprint for a peer's base64-encoded public key.
    /// The fingerprint is always computed over the raw 32 key bytes (legacy X.509 keys are normalized first).
    public static func peerFingerprint(base64Key: String) -> String {
        guard let data = Data(base64Encoded: base64Key),
              let rawKey = normalizeRawKey(data) else { return "—" }
        return fingerprint(of: rawKey)
    }

    private static func fingerprint(of keyData: Data) -> String {
        let hash = SHA256.hash(data: keyData)
        return hash.prefix(BIShareCrypto.fingerprintBytes)
            .map { String(format: "%02X", $0) }
            .joined(separator: " ")
    }

    // MARK: - Streaming Chunk Encryption (v2.2)

    /// Generate a random 12-byte base nonce for a file transfer session.
    public static func generateBaseNonce() -> Data {
        var bytes = [UInt8](repeating: 0, count: BIShareCrypto.gcmNonceSize)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
    }

    /// Derive a unique nonce for a specific chunk by XORing baseNonce with chunkIndex.
    private static func deriveChunkNonce(baseNonce: Data, chunkIndex: UInt64) -> AES.GCM.Nonce? {
        guard baseNonce.count == BIShareCrypto.gcmNonceSize else { return nil }
        var nonceBytes = [UInt8](baseNonce)
        // XOR chunkIndex (8 bytes big-endian) into the last 8 bytes of nonce
        var idx = chunkIndex.bigEndian
        withUnsafeBytes(of: &idx) { indexBytes in
            for i in 0..<8 {
                nonceBytes[4 + i] ^= indexBytes[i]
            }
        }
        return try? AES.GCM.Nonce(data: nonceBytes)
    }

    /// Encrypt a single chunk with a deterministic nonce derived from chunkIndex.
    /// Format: nonce(12) + ciphertext + tag(16)
    public static func encryptChunk(data: Data, using key: SymmetricKey, chunkIndex: UInt64, baseNonce: Data) -> Data? {
        guard let nonce = deriveChunkNonce(baseNonce: baseNonce, chunkIndex: chunkIndex),
              let sealed = try? AES.GCM.seal(data, using: key, nonce: nonce) else {
            return nil
        }
        return sealed.combined
    }

    /// Decrypt a single chunk using the same deterministic nonce scheme.
    public static func decryptChunk(data: Data, using key: SymmetricKey, chunkIndex: UInt64, baseNonce: Data) -> Data? {
        guard let nonce = deriveChunkNonce(baseNonce: baseNonce, chunkIndex: chunkIndex),
              let box = try? AES.GCM.SealedBox(combined: data) else {
            return nil
        }
        // Verify the nonce in the combined data matches our derived nonce
        let boxNonceBytes = [UInt8](box.nonce)
        let expectedNonceBytes = [UInt8](nonce)
        guard boxNonceBytes == expectedNonceBytes else { return nil }
        return try? AES.GCM.open(box, using: key)
    }
}
