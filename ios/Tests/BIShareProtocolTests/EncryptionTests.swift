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
}
