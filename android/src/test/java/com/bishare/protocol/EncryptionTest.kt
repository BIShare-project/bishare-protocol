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
