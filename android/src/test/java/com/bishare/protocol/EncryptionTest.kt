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
}
