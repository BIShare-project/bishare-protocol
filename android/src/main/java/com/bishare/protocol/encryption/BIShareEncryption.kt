package com.bishare.protocol.encryption

import android.util.Base64
import com.bishare.protocol.constants.BIShareConfig
import com.bishare.protocol.constants.BIShareCrypto
import java.security.*
import java.security.spec.PKCS8EncodedKeySpec
import java.security.spec.X509EncodedKeySpec
import javax.crypto.Cipher
import javax.crypto.KeyAgreement
import javax.crypto.Mac
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

/**
 * Core encryption engine for BIShare E2E file transfers.
 *
 * Handles X25519 key agreement, HKDF key derivation, and AES-256-GCM encryption/decryption.
 * This class does NOT manage key persistence — the app is responsible for storing/loading key bytes.
 */
class BIShareEncryption(privateKeyBytes: ByteArray? = null, publicKeyBytes: ByteArray? = null) {

    val keyPair: KeyPair = if (privateKeyBytes != null && publicKeyBytes != null) {
        loadKeyPair(privateKeyBytes, publicKeyBytes)
    } else {
        generateKeyPair()
    }

    /** Base64-encoded public key for sharing with peers. */
    val publicKeyBase64: String
        get() = Base64.encodeToString(keyPair.public.encoded, Base64.NO_WRAP)

    /** Raw private key bytes for persistence by the app. */
    val privateKeyData: ByteArray
        get() = keyPair.private.encoded

    /** Raw public key bytes for persistence by the app. */
    val publicKeyData: ByteArray
        get() = keyPair.public.encoded

    // MARK: - E2E Key Derivation (X25519 ECDH)

    /**
     * Derive a shared symmetric key from a peer's public key using ECDH + HKDF.
     * @param peerPublicKeyBase64 The peer's base64-encoded X25519 public key.
     * @return 32-byte AES key, or null if key agreement fails.
     */
    fun deriveSharedKey(peerPublicKeyBase64: String): ByteArray? {
        return try {
            val peerKeyBytes = Base64.decode(peerPublicKeyBase64, Base64.NO_WRAP)
            val kf = KeyFactory.getInstance("X25519")
            val peerPublicKey = kf.generatePublic(X509EncodedKeySpec(peerKeyBytes))

            val agreement = KeyAgreement.getInstance("X25519")
            agreement.init(keyPair.private)
            agreement.doPhase(peerPublicKey, true)
            val sharedSecret = agreement.generateSecret()

            hkdfDerive(
                sharedSecret,
                BIShareCrypto.E2E_SALT.toByteArray(),
                BIShareCrypto.E2E_INFO.toByteArray(),
                BIShareCrypto.AES_KEY_SIZE
            )
        } catch (e: Exception) {
            null
        }
    }

    /** Visual fingerprint of this device's public key (e.g., "A1 B2 C3 D4 E5 F6 G7 H8"). */
    val keyFingerprint: String
        get() = fingerprint(keyPair.public.encoded)

    companion object {

        // MARK: - AES-256-GCM

        /**
         * Encrypt data with AES-256-GCM.
         * @return Combined data: nonce(12) + ciphertext + tag(16), or null on failure.
         */
        fun encrypt(data: ByteArray, key: ByteArray): ByteArray? {
            return try {
                val nonce = ByteArray(BIShareCrypto.GCM_NONCE_SIZE)
                SecureRandom().nextBytes(nonce)

                val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                val keySpec = SecretKeySpec(key, "AES")
                val gcmSpec = GCMParameterSpec(BIShareCrypto.GCM_TAG_BITS, nonce)
                cipher.init(Cipher.ENCRYPT_MODE, keySpec, gcmSpec)

                val ciphertext = cipher.doFinal(data)
                nonce + ciphertext // nonce(12) + ciphertext + tag(16)
            } catch (e: Exception) {
                null
            }
        }

        /**
         * Decrypt AES-256-GCM combined data.
         * @param data Combined format: nonce(12) + ciphertext + tag(16).
         * @return Decrypted plaintext, or null on failure.
         */
        fun decrypt(data: ByteArray, key: ByteArray): ByteArray? {
            return try {
                if (data.size < BIShareCrypto.GCM_NONCE_SIZE + 16) return null

                val nonce = data.copyOfRange(0, BIShareCrypto.GCM_NONCE_SIZE)
                val ciphertext = data.copyOfRange(BIShareCrypto.GCM_NONCE_SIZE, data.size)

                val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                val keySpec = SecretKeySpec(key, "AES")
                val gcmSpec = GCMParameterSpec(BIShareCrypto.GCM_TAG_BITS, nonce)
                cipher.init(Cipher.DECRYPT_MODE, keySpec, gcmSpec)

                cipher.doFinal(ciphertext)
            } catch (e: Exception) {
                null
            }
        }

        /** Generate a visual fingerprint for a peer's base64-encoded public key. */
        fun peerFingerprint(base64Key: String): String {
            return try {
                val data = Base64.decode(base64Key, Base64.NO_WRAP)
                fingerprint(data)
            } catch (e: Exception) {
                "—"
            }
        }

        private fun fingerprint(keyData: ByteArray): String {
            val hash = MessageDigest.getInstance("SHA-256").digest(keyData)
            return hash.take(BIShareCrypto.FINGERPRINT_BYTES)
                .joinToString(" ") { "%02X".format(it) }
        }

        /**
         * HKDF key derivation (RFC 5869) using HMAC-SHA256.
         */
        fun hkdfDerive(ikm: ByteArray, salt: ByteArray, info: ByteArray, length: Int): ByteArray {
            // Extract
            val mac = Mac.getInstance("HmacSHA256")
            mac.init(SecretKeySpec(salt, "HmacSHA256"))
            val prk = mac.doFinal(ikm)

            // Expand
            val result = ByteArray(length)
            var t = ByteArray(0)
            var offset = 0
            var i = 1

            while (offset < length) {
                mac.init(SecretKeySpec(prk, "HmacSHA256"))
                mac.update(t)
                mac.update(info)
                mac.update(byteArrayOf(i.toByte()))
                t = mac.doFinal()

                val toCopy = minOf(t.size, length - offset)
                System.arraycopy(t, 0, result, offset, toCopy)
                offset += toCopy
                i++
            }

            return result
        }

        private fun generateKeyPair(): KeyPair {
            val kpg = KeyPairGenerator.getInstance("X25519")
            return kpg.generateKeyPair()
        }

        private fun loadKeyPair(privateKeyBytes: ByteArray, publicKeyBytes: ByteArray): KeyPair {
            return try {
                val kf = KeyFactory.getInstance("X25519")
                val privateKey = kf.generatePrivate(PKCS8EncodedKeySpec(privateKeyBytes))
                val publicKey = kf.generatePublic(X509EncodedKeySpec(publicKeyBytes))
                KeyPair(publicKey, privateKey)
            } catch (e: Exception) {
                generateKeyPair()
            }
        }

        // MARK: - Streaming Chunk Encryption (v2.2)

        /** Generate a random 12-byte base nonce for a file transfer session. */
        fun generateBaseNonce(): ByteArray {
            val nonce = ByteArray(BIShareCrypto.GCM_NONCE_SIZE)
            SecureRandom().nextBytes(nonce)
            return nonce
        }

        /** Derive a unique nonce for a specific chunk by XORing baseNonce with chunkIndex. */
        private fun deriveChunkNonce(baseNonce: ByteArray, chunkIndex: Long): ByteArray {
            val nonce = baseNonce.copyOf()
            // XOR chunkIndex (8 bytes big-endian) into the last 8 bytes of nonce
            for (i in 0 until 8) {
                nonce[4 + i] = (nonce[4 + i].toInt() xor ((chunkIndex shr (56 - i * 8)) and 0xFF).toInt()).toByte()
            }
            return nonce
        }

        /**
         * Encrypt a single chunk with a deterministic nonce derived from chunkIndex.
         * @return Combined data: nonce(12) + ciphertext + tag(16), or null on failure.
         */
        fun encryptChunk(data: ByteArray, key: ByteArray, chunkIndex: Long, baseNonce: ByteArray): ByteArray? {
            return try {
                val nonce = deriveChunkNonce(baseNonce, chunkIndex)
                val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                val keySpec = SecretKeySpec(key, "AES")
                val gcmSpec = GCMParameterSpec(BIShareCrypto.GCM_TAG_BITS, nonce)
                cipher.init(Cipher.ENCRYPT_MODE, keySpec, gcmSpec)
                val ciphertext = cipher.doFinal(data)
                nonce + ciphertext // nonce(12) + ciphertext + tag(16)
            } catch (e: Exception) {
                null
            }
        }

        /**
         * Decrypt a single chunk using the same deterministic nonce scheme.
         * @param data Combined format: nonce(12) + ciphertext + tag(16).
         * @return Decrypted plaintext, or null on failure.
         */
        fun decryptChunk(data: ByteArray, key: ByteArray, chunkIndex: Long, baseNonce: ByteArray): ByteArray? {
            return try {
                if (data.size < BIShareCrypto.GCM_NONCE_SIZE + 16) return null
                val embeddedNonce = data.copyOfRange(0, BIShareCrypto.GCM_NONCE_SIZE)
                val expectedNonce = deriveChunkNonce(baseNonce, chunkIndex)
                // Verify nonce matches expected derived nonce
                if (!embeddedNonce.contentEquals(expectedNonce)) return null
                val ciphertext = data.copyOfRange(BIShareCrypto.GCM_NONCE_SIZE, data.size)
                val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                val keySpec = SecretKeySpec(key, "AES")
                val gcmSpec = GCMParameterSpec(BIShareCrypto.GCM_TAG_BITS, embeddedNonce)
                cipher.init(Cipher.DECRYPT_MODE, keySpec, gcmSpec)
                cipher.doFinal(ciphertext)
            } catch (e: Exception) {
                null
            }
        }
    }
}
