package com.bishare.protocol

import com.bishare.protocol.constants.BIShareCrypto
import com.bishare.protocol.encryption.BIShareEncryption
import org.junit.Assert.*
import org.junit.Test

class EncryptionTest {

    @Test
    fun hkdfDeriveProduces32Bytes() {
        val result = BIShareEncryption.hkdfDerive(
            ikm = "test-key".toByteArray(),
            salt = BIShareCrypto.E2E_SALT.toByteArray(),
            info = BIShareCrypto.E2E_INFO.toByteArray(),
            length = BIShareCrypto.AES_KEY_SIZE
        )
        assertEquals(32, result.size)
    }

    @Test
    fun hkdfDeriveDeterministic() {
        val key1 = BIShareEncryption.hkdfDerive(
            ikm = "same-input".toByteArray(),
            salt = "salt".toByteArray(),
            info = "info".toByteArray(),
            length = 32
        )
        val key2 = BIShareEncryption.hkdfDerive(
            ikm = "same-input".toByteArray(),
            salt = "salt".toByteArray(),
            info = "info".toByteArray(),
            length = 32
        )
        assertArrayEquals(key1, key2)
    }

    @Test
    fun hkdfDeriveDifferentInputProducesDifferentKey() {
        val key1 = BIShareEncryption.hkdfDerive("input1".toByteArray(), "salt".toByteArray(), "info".toByteArray(), 32)
        val key2 = BIShareEncryption.hkdfDerive("input2".toByteArray(), "salt".toByteArray(), "info".toByteArray(), 32)
        assertFalse(key1.contentEquals(key2))
    }

    @Test
    fun encryptDecryptRoundTrip() {
        val key = BIShareEncryption.hkdfDerive("test".toByteArray(), "salt".toByteArray(), "info".toByteArray(), 32)
        val plaintext = "Hello, BIShare!".toByteArray()

        val encrypted = BIShareEncryption.encrypt(plaintext, key)
        assertNotNull(encrypted)
        assertTrue(encrypted!!.size > plaintext.size) // nonce + ciphertext + tag

        val decrypted = BIShareEncryption.decrypt(encrypted, key)
        assertNotNull(decrypted)
        assertArrayEquals(plaintext, decrypted)
    }

    @Test
    fun decryptWithWrongKeyFails() {
        val key1 = BIShareEncryption.hkdfDerive("key1".toByteArray(), "salt".toByteArray(), "info".toByteArray(), 32)
        val key2 = BIShareEncryption.hkdfDerive("key2".toByteArray(), "salt".toByteArray(), "info".toByteArray(), 32)
        val plaintext = "Secret data".toByteArray()

        val encrypted = BIShareEncryption.encrypt(plaintext, key1)
        assertNotNull(encrypted)

        val decrypted = BIShareEncryption.decrypt(encrypted!!, key2)
        assertNull(decrypted)
    }

    // v2.2 Streaming Chunk Encryption

    @Test
    fun chunkEncryptDecryptRoundTrip() {
        val key = BIShareEncryption.hkdfDerive("test".toByteArray(), "salt".toByteArray(), "info".toByteArray(), 32)
        val baseNonce = BIShareEncryption.generateBaseNonce()
        val plaintext = "Chunk data for BIShare v2.2".toByteArray()

        val encrypted = BIShareEncryption.encryptChunk(plaintext, key, 0, baseNonce)
        assertNotNull(encrypted)
        assertTrue(encrypted!!.size > plaintext.size)

        val decrypted = BIShareEncryption.decryptChunk(encrypted, key, 0, baseNonce)
        assertNotNull(decrypted)
        assertArrayEquals(plaintext, decrypted)
    }

    @Test
    fun differentChunkIndicesProduceDifferentCiphertext() {
        val key = BIShareEncryption.hkdfDerive("test".toByteArray(), "salt".toByteArray(), "info".toByteArray(), 32)
        val baseNonce = BIShareEncryption.generateBaseNonce()
        val plaintext = "Same plaintext".toByteArray()

        val enc0 = BIShareEncryption.encryptChunk(plaintext, key, 0, baseNonce)
        val enc1 = BIShareEncryption.encryptChunk(plaintext, key, 1, baseNonce)
        assertNotNull(enc0)
        assertNotNull(enc1)
        assertFalse(enc0!!.contentEquals(enc1!!))
    }

    @Test
    fun chunkDecryptWrongIndexFails() {
        val key = BIShareEncryption.hkdfDerive("test".toByteArray(), "salt".toByteArray(), "info".toByteArray(), 32)
        val baseNonce = BIShareEncryption.generateBaseNonce()
        val plaintext = "Secret chunk".toByteArray()

        val encrypted = BIShareEncryption.encryptChunk(plaintext, key, 5, baseNonce)
        assertNotNull(encrypted)

        val decrypted = BIShareEncryption.decryptChunk(encrypted!!, key, 6, baseNonce)
        assertNull(decrypted)
    }

    @Test
    fun generateBaseNonce() {
        val nonce1 = BIShareEncryption.generateBaseNonce()
        val nonce2 = BIShareEncryption.generateBaseNonce()
        assertEquals(12, nonce1.size)
        assertEquals(12, nonce2.size)
        assertFalse(nonce1.contentEquals(nonce2))
    }

    @Test
    fun encryptedFormatNoncePlusCiphertextPlusTag() {
        val key = BIShareEncryption.hkdfDerive("test".toByteArray(), "salt".toByteArray(), "info".toByteArray(), 32)
        val plaintext = "test".toByteArray()

        val encrypted = BIShareEncryption.encrypt(plaintext, key)
        assertNotNull(encrypted)
        // nonce(12) + ciphertext(same as plaintext length) + tag(16) = 12 + 4 + 16 = 32
        assertEquals(BIShareCrypto.GCM_NONCE_SIZE + plaintext.size + 16, encrypted!!.size)
    }

    // v2.3 Cross-Platform Test Vectors (generated from the Rust reference implementation)

    private fun fromHex(hex: String): ByteArray =
        ByteArray(hex.length / 2) { ((hex[it * 2].digitToInt(16) shl 4) or hex[it * 2 + 1].digitToInt(16)).toByte() }

    private fun toHex(bytes: ByteArray): String = bytes.joinToString("") { "%02x".format(it) }

    /** PKCS8 X25519 private-key prefix — prepend to a raw 32-byte private key for the JCA KeyFactory. */
    private fun pkcs8FromRaw(raw: ByteArray): ByteArray = fromHex("302e020100300506032b656e04220420") + raw

    private val vectorKeyHex = "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"
    private val vectorBaseNonceHex = "000102030405060708090a0b"
    private val vectorPlaintext = "BIShare cross-platform test vector"
    private val vectorChunk1Hex = "000102030405060708090a0ae4919a286eaa2a8ab4336e2bb89bf638a0dbbe6526429e3a4a4f0bad6b9648c23ecf16cfba5fdc41ea16333b7dbc9d97f427"
    private val vectorChunk0Hex = "000102030405060708090a0b054b8573a497a73bee33f8f8c2c40801e2a2e15b82167f085d1491a56b0c63c66e623f9e794f97a98205cb0b27157af11d24"
    private val pubABase64 = "e06Qm75//kTEZaIgA31gjuNYl9Me+XLwf3SJLLD3PxM="
    private val pubBBase64 = "D6poTtKIZ7l/Smot7l34zpdOdrcBjj8iocTPJnhXDyA="
    private val pubAX509Base64 = "MCowBQYDK2VuAyEAe06Qm75//kTEZaIgA31gjuNYl9Me+XLwf3SJLLD3PxM="
    private val sharedKeyHex = "9ffee322ad64e3bf95f3dc3e6c979113af57b356ed7b7fb9cb6bfe4a55eba48c"
    private val fingerprintA = "D1 9B F3 F0 82 78 2C 87"

    @Test
    fun encryptChunkMatchesCrossPlatformVector() {
        val key = fromHex(vectorKeyHex)
        val baseNonce = fromHex(vectorBaseNonceHex)
        val plaintext = vectorPlaintext.toByteArray()

        val enc1 = BIShareEncryption.encryptChunk(plaintext, key, 1, baseNonce)
        assertNotNull(enc1)
        assertEquals(vectorChunk1Hex, toHex(enc1!!))

        val enc0 = BIShareEncryption.encryptChunk(plaintext, key, 0, baseNonce)
        assertNotNull(enc0)
        assertEquals(vectorChunk0Hex, toHex(enc0!!))
    }

    @Test
    fun decryptChunkMatchesCrossPlatformVector() {
        val key = fromHex(vectorKeyHex)
        val baseNonce = fromHex(vectorBaseNonceHex)

        val dec1 = BIShareEncryption.decryptChunk(fromHex(vectorChunk1Hex), key, 1, baseNonce)
        assertNotNull(dec1)
        assertEquals(vectorPlaintext, String(dec1!!))

        val dec0 = BIShareEncryption.decryptChunk(fromHex(vectorChunk0Hex), key, 0, baseNonce)
        assertNotNull(dec0)
        assertEquals(vectorPlaintext, String(dec0!!))
    }

    @Test
    fun keyDerivationMatchesCrossPlatformVector() {
        val privA = ByteArray(32) { 0x11 }
        val rawA = java.util.Base64.getDecoder().decode(pubABase64)
        val engineA = BIShareEncryption(pkcs8FromRaw(privA), BIShareEncryption.x509FromRaw(rawA)!!)

        assertEquals(pubABase64, engineA.publicKeyBase64)

        val shared = engineA.deriveSharedKey(pubBBase64)
        assertNotNull(shared)
        assertEquals(sharedKeyHex, toHex(shared!!))

        assertEquals(fingerprintA, engineA.keyFingerprint)
    }

    @Test
    fun deriveSharedKeyAcceptsLegacyX509Format() {
        val privB = ByteArray(32) { 0x22 }
        val rawB = java.util.Base64.getDecoder().decode(pubBBase64)
        val engineB = BIShareEncryption(pkcs8FromRaw(privB), BIShareEncryption.x509FromRaw(rawB)!!)

        assertEquals(pubBBase64, engineB.publicKeyBase64)

        // Legacy peers (old Android) send the 44-byte X.509 encoding — must still derive the same key
        val shared = engineB.deriveSharedKey(pubAX509Base64)
        assertNotNull(shared)
        assertEquals(sharedKeyHex, toHex(shared!!))
    }

    @Test
    fun normalizeToRawAcceptsBothFormats() {
        val raw = ByteArray(32) { it.toByte() }
        assertArrayEquals(raw, BIShareEncryption.normalizeToRaw(raw))

        val x509 = BIShareEncryption.x509FromRaw(raw)
        assertNotNull(x509)
        assertEquals(44, x509!!.size)
        assertArrayEquals(raw, BIShareEncryption.normalizeToRaw(x509))

        assertNull(BIShareEncryption.normalizeToRaw(ByteArray(44))) // 44 bytes without valid prefix
        assertNull(BIShareEncryption.normalizeToRaw(ByteArray(16))) // wrong size
    }

    @Test
    fun lowOrderPeerKeyRejected() {
        // All-zero X25519 point yields a non-contributory shared secret; JCA fails
        // closed (as do iOS CryptoKit and Rust after the v2.3 fix)
        val privA = ByteArray(32) { 0x11 }
        val rawA = java.util.Base64.getDecoder().decode(pubABase64)
        val engine = BIShareEncryption(pkcs8FromRaw(privA), BIShareEncryption.x509FromRaw(rawA)!!)

        val zeroKey = java.util.Base64.getEncoder().encodeToString(ByteArray(32))
        assertNull(engine.deriveSharedKey(zeroKey))
    }
}
