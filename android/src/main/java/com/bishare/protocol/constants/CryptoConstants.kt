package com.bishare.protocol.constants

/**
 * Cryptographic constants for BIShare E2E encryption.
 */
object BIShareCrypto {
    // E2E File Transfer (X25519 ECDH)
    const val E2E_SALT = "BIShare-E2E"
    const val E2E_INFO = "file-transfer"

    // AES-256-GCM Parameters
    /** AES key size in bytes (256 bits) */
    const val AES_KEY_SIZE = 32
    /** GCM nonce size in bytes */
    const val GCM_NONCE_SIZE = 12
    /** GCM authentication tag size in bits */
    const val GCM_TAG_BITS = 128

    // Key Fingerprint
    /** Number of SHA-256 hash bytes used for visual fingerprint */
    const val FINGERPRINT_BYTES = 8

    // Streaming Encryption (v2.2)

    /** GCM overhead per encrypted chunk: nonce(12) + tag(16) */
    const val GCM_OVERHEAD_PER_CHUNK = GCM_NONCE_SIZE + (GCM_TAG_BITS / 8)
}
