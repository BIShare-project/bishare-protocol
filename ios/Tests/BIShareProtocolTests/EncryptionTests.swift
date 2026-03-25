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

    func testRemoteKeyDerivation() {
        let code = "A3X9K2P4HN7RVWQB" // 16-char code
        guard let key1 = BIShareEncryption.deriveRemoteKey(from: code),
              let key2 = BIShareEncryption.deriveRemoteKey(from: code) else {
            XCTFail("Remote key derivation failed"); return
        }

        // Same code should produce same key
        let plaintext = Data("Remote file".utf8)
        guard let encrypted = BIShareEncryption.encrypt(data: plaintext, using: key1),
              let decrypted = BIShareEncryption.decrypt(data: encrypted, using: key2) else {
            XCTFail("Remote encrypt/decrypt failed"); return
        }
        XCTAssertEqual(decrypted, plaintext)
    }

    func testRemoteKeyTooShortFails() {
        let shortCode = "AB"
        let key = BIShareEncryption.deriveRemoteKey(from: shortCode)
        XCTAssertNil(key)
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

    func testPeerFingerprint() {
        let enc = BIShareEncryption()
        let fp = BIShareEncryption.peerFingerprint(base64Key: enc.publicKeyBase64)
        XCTAssertEqual(fp, enc.keyFingerprint)

        let invalid = BIShareEncryption.peerFingerprint(base64Key: "not-valid-base64!!!")
        XCTAssertEqual(invalid, "—")
    }
}
