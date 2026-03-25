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

    /// Derive a shared symmetric key from a peer's public key using ECDH + HKDF.
    /// - Parameter peerPublicKeyBase64: The peer's base64-encoded Curve25519 public key.
    /// - Returns: A `SymmetricKey` for AES-256-GCM, or `nil` if key agreement fails.
    public func deriveSharedKey(peerPublicKeyBase64: String) -> SymmetricKey? {
        guard let peerKeyData = Data(base64Encoded: peerPublicKeyBase64),
              let peerKey = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: peerKeyData),
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

    // MARK: - Remote Key Derivation (from share code)

    /// Derive a symmetric key from a remote transfer share code using HKDF.
    /// - Parameter shareCode: The full share code string (16 characters).
    /// - Returns: A `SymmetricKey` for AES-256-GCM, or `nil` if code is too short.
    public static func deriveRemoteKey(from shareCode: String) -> SymmetricKey? {
        let codeData = Data(shareCode.utf8)
        guard codeData.count >= BIShareConfig.remoteCodeLength else { return nil }
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: codeData),
            salt: Data(BIShareCrypto.remoteSalt.utf8),
            info: Data(BIShareCrypto.remoteInfo.utf8),
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
    public static func peerFingerprint(base64Key: String) -> String {
        guard let data = Data(base64Encoded: base64Key) else { return "—" }
        return fingerprint(of: data)
    }

    private static func fingerprint(of keyData: Data) -> String {
        let hash = SHA256.hash(data: keyData)
        return hash.prefix(BIShareCrypto.fingerprintBytes)
            .map { String(format: "%02X", $0) }
            .joined(separator: " ")
    }
}
