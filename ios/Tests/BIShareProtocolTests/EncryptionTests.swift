import XCTest
import CryptoKit
@testable import BIShareProtocol

final class EncryptionTests: XCTestCase {

    func testKeyGeneration() {
        let enc = BIShareEncryption()
        XCTAssertFalse(enc.publicKeyBase64.isEmpty)
        XCTAssertFalse(enc.privateKeyData.isEmpty)
    }

    func testKeyPersistence() {
        let enc1 = BIShareEncryption()
        let enc2 = BIShareEncryption(privateKeyData: enc1.privateKeyData)
        XCTAssertEqual(enc1.publicKeyBase64, enc2.publicKeyBase64)
    }

    func testEncryptDecryptRoundTrip() {
        let key = SymmetricKey(size: .bits256)
        let plaintext = Data("Hello, BIShare!".utf8)

        guard let encrypted = BIShareEncryption.encrypt(data: plaintext, using: key) else {
            XCTFail("Encryption failed"); return
        }

        // Encrypted data should be larger: nonce(12) + ciphertext + tag(16)
        XCTAssertGreaterThan(encrypted.count, plaintext.count)

        guard let decrypted = BIShareEncryption.decrypt(data: encrypted, using: key) else {
            XCTFail("Decryption failed"); return
        }

        XCTAssertEqual(decrypted, plaintext)
    }

    func testDecryptWithWrongKeyFails() {
        let key1 = SymmetricKey(size: .bits256)
        let key2 = SymmetricKey(size: .bits256)
        let plaintext = Data("Secret data".utf8)

        guard let encrypted = BIShareEncryption.encrypt(data: plaintext, using: key1) else {
            XCTFail("Encryption failed"); return
        }

        let decrypted = BIShareEncryption.decrypt(data: encrypted, using: key2)
        XCTAssertNil(decrypted)
    }

    func testE2EKeyExchange() {
        let alice = BIShareEncryption()
        let bob = BIShareEncryption()

        guard let aliceKey = alice.deriveSharedKey(peerPublicKeyBase64: bob.publicKeyBase64),
              let bobKey = bob.deriveSharedKey(peerPublicKeyBase64: alice.publicKeyBase64) else {
            XCTFail("Key derivation failed"); return
        }

        // Both sides should derive the same key
        let plaintext = Data("Cross-device message".utf8)
        guard let encrypted = BIShareEncryption.encrypt(data: plaintext, using: aliceKey),
              let decrypted = BIShareEncryption.decrypt(data: encrypted, using: bobKey) else {
            XCTFail("E2E encrypt/decrypt failed"); return
        }
        XCTAssertEqual(decrypted, plaintext)
    }

    func testKeyFingerprint() {
        let enc = BIShareEncryption()
        let fp = enc.keyFingerprint
        // Format: "XX XX XX XX XX XX XX XX" (8 hex pairs)
        let parts = fp.split(separator: " ")
        XCTAssertEqual(parts.count, 8)
        for part in parts {
            XCTAssertEqual(part.count, 2)
        }
    }

    // MARK: - v2.2 Streaming Chunk Encryption

    func testChunkEncryptDecryptRoundTrip() {
        let key = SymmetricKey(size: .bits256)
        let baseNonce = BIShareEncryption.generateBaseNonce()
        let plaintext = Data("Chunk data for BIShare v2.2".utf8)

        guard let encrypted = BIShareEncryption.encryptChunk(data: plaintext, using: key, chunkIndex: 0, baseNonce: baseNonce) else {
            XCTFail("Chunk encryption failed"); return
        }

        XCTAssertGreaterThan(encrypted.count, plaintext.count)

        guard let decrypted = BIShareEncryption.decryptChunk(data: encrypted, using: key, chunkIndex: 0, baseNonce: baseNonce) else {
            XCTFail("Chunk decryption failed"); return
        }

        XCTAssertEqual(decrypted, plaintext)
    }

    func testDifferentChunkIndicesProduceDifferentCiphertext() {
        let key = SymmetricKey(size: .bits256)
        let baseNonce = BIShareEncryption.generateBaseNonce()
        let plaintext = Data("Same plaintext".utf8)

        guard let enc0 = BIShareEncryption.encryptChunk(data: plaintext, using: key, chunkIndex: 0, baseNonce: baseNonce),
              let enc1 = BIShareEncryption.encryptChunk(data: plaintext, using: key, chunkIndex: 1, baseNonce: baseNonce) else {
            XCTFail("Chunk encryption failed"); return
        }

        XCTAssertNotEqual(enc0, enc1)
    }

    func testChunkDecryptWrongIndexFails() {
        let key = SymmetricKey(size: .bits256)
        let baseNonce = BIShareEncryption.generateBaseNonce()
        let plaintext = Data("Secret chunk".utf8)

        guard let encrypted = BIShareEncryption.encryptChunk(data: plaintext, using: key, chunkIndex: 5, baseNonce: baseNonce) else {
            XCTFail("Chunk encryption failed"); return
        }

        let decrypted = BIShareEncryption.decryptChunk(data: encrypted, using: key, chunkIndex: 6, baseNonce: baseNonce)
        XCTAssertNil(decrypted)
    }

    func testGenerateBaseNonce() {
        let nonce1 = BIShareEncryption.generateBaseNonce()
        let nonce2 = BIShareEncryption.generateBaseNonce()
        XCTAssertEqual(nonce1.count, 12)
        XCTAssertEqual(nonce2.count, 12)
        XCTAssertNotEqual(nonce1, nonce2)
    }

    func testPeerFingerprint() {
        let enc = BIShareEncryption()
        let fp = BIShareEncryption.peerFingerprint(base64Key: enc.publicKeyBase64)
        XCTAssertEqual(fp, enc.keyFingerprint)

        let invalid = BIShareEncryption.peerFingerprint(base64Key: "not-valid-base64!!!")
        XCTAssertEqual(invalid, "—")
    }

    // MARK: - v2.3 Cross-Platform Test Vectors (generated from the Rust reference implementation)

    private static let vectorKeyHex = "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"
    private static let vectorBaseNonceHex = "000102030405060708090a0b"
    private static let vectorPlaintext = "BIShare cross-platform test vector"
    private static let vectorChunk1Hex = "000102030405060708090a0ae4919a286eaa2a8ab4336e2bb89bf638a0dbbe6526429e3a4a4f0bad6b9648c23ecf16cfba5fdc41ea16333b7dbc9d97f427"
    private static let vectorChunk0Hex = "000102030405060708090a0b054b8573a497a73bee33f8f8c2c40801e2a2e15b82167f085d1491a56b0c63c66e623f9e794f97a98205cb0b27157af11d24"
    private static let pubARawBase64 = "e06Qm75//kTEZaIgA31gjuNYl9Me+XLwf3SJLLD3PxM="
    private static let pubBRawBase64 = "D6poTtKIZ7l/Smot7l34zpdOdrcBjj8iocTPJnhXDyA="
    private static let pubAX509Base64 = "MCowBQYDK2VuAyEAe06Qm75//kTEZaIgA31gjuNYl9Me+XLwf3SJLLD3PxM="
    private static let sharedKeyHex = "9ffee322ad64e3bf95f3dc3e6c979113af57b356ed7b7fb9cb6bfe4a55eba48c"
    private static let fingerprintA = "D1 9B F3 F0 82 78 2C 87"

    private func hexData(_ hex: String) -> Data {
        var data = Data(capacity: hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            data.append(UInt8(hex[index..<next], radix: 16)!)
            index = next
        }
        return data
    }

    private func hexString(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    func testCrossPlatformChunkVectors() {
        let key = SymmetricKey(data: hexData(Self.vectorKeyHex))
        let baseNonce = hexData(Self.vectorBaseNonceHex)
        let plaintext = Data(Self.vectorPlaintext.utf8)

        guard let enc1 = BIShareEncryption.encryptChunk(data: plaintext, using: key, chunkIndex: 1, baseNonce: baseNonce),
              let enc0 = BIShareEncryption.encryptChunk(data: plaintext, using: key, chunkIndex: 0, baseNonce: baseNonce) else {
            XCTFail("Chunk encryption failed"); return
        }

        // Must byte-match the Rust reference output exactly (nonce || ciphertext || tag)
        XCTAssertEqual(hexString(enc1), Self.vectorChunk1Hex)
        XCTAssertEqual(hexString(enc0), Self.vectorChunk0Hex)

        // Decrypting the reference vectors must yield the plaintext
        XCTAssertEqual(BIShareEncryption.decryptChunk(data: hexData(Self.vectorChunk1Hex), using: key, chunkIndex: 1, baseNonce: baseNonce), plaintext)
        XCTAssertEqual(BIShareEncryption.decryptChunk(data: hexData(Self.vectorChunk0Hex), using: key, chunkIndex: 0, baseNonce: baseNonce), plaintext)
    }

    func testCrossPlatformFixedKeypair() {
        let privA = Data(repeating: 0x11, count: 32)
        let engine = BIShareEncryption(privateKeyData: privA)
        XCTAssertEqual(engine.publicKeyBase64, Self.pubARawBase64)

        guard let sharedKey = engine.deriveSharedKey(peerPublicKeyBase64: Self.pubBRawBase64) else {
            XCTFail("Key derivation failed"); return
        }
        let sharedKeyData = sharedKey.withUnsafeBytes { Data($0) }
        XCTAssertEqual(hexString(sharedKeyData), Self.sharedKeyHex)

        XCTAssertEqual(engine.keyFingerprint, Self.fingerprintA)
    }

    func testLegacyX509PeerKeyAccepted() {
        // Old Android clients sent X.509 SPKI keys (44 bytes) — must derive the SAME shared key as raw
        let privB = Data(repeating: 0x22, count: 32)
        let engine = BIShareEncryption(privateKeyData: privB)

        guard let sharedKey = engine.deriveSharedKey(peerPublicKeyBase64: Self.pubAX509Base64) else {
            XCTFail("Legacy X.509 key derivation failed"); return
        }
        let sharedKeyData = sharedKey.withUnsafeBytes { Data($0) }
        XCTAssertEqual(hexString(sharedKeyData), Self.sharedKeyHex)

        // Fingerprint is computed over the raw 32 bytes regardless of wire format
        XCTAssertEqual(BIShareEncryption.peerFingerprint(base64Key: Self.pubAX509Base64), Self.fingerprintA)
        XCTAssertEqual(BIShareEncryption.peerFingerprint(base64Key: Self.pubARawBase64), Self.fingerprintA)
    }

    func testMalformedPeerKeysRejected() {
        // Cross-platform negative vectors — Rust and Android reject these identically
        let engine = BIShareEncryption(privateKeyData: Data(repeating: 0x11, count: 32))

        // 44 bytes with a wrong DER prefix must NOT be treated as X.509
        let wrongPrefix = Data(repeating: 0, count: 44).base64EncodedString()
        XCTAssertNil(engine.deriveSharedKey(peerPublicKeyBase64: wrongPrefix))
        XCTAssertEqual(BIShareEncryption.peerFingerprint(base64Key: wrongPrefix), "—")

        // Wrong lengths (31 and 16 bytes) rejected
        XCTAssertNil(engine.deriveSharedKey(peerPublicKeyBase64: Data(repeating: 1, count: 31).base64EncodedString()))
        XCTAssertEqual(BIShareEncryption.peerFingerprint(base64Key: Data(repeating: 1, count: 16).base64EncodedString()), "—")
    }

    func testLowOrderPeerKeyRejected() {
        // All-zero X25519 point yields a non-contributory shared secret; CryptoKit fails
        // closed (as do Android JCA and Rust after the v2.3 fix)
        let engine = BIShareEncryption(privateKeyData: Data(repeating: 0x11, count: 32))
        let zeroKey = Data(repeating: 0, count: 32).base64EncodedString()
        XCTAssertNil(engine.deriveSharedKey(peerPublicKeyBase64: zeroKey))
    }
}
