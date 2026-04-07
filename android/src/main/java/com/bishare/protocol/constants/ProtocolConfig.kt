package com.bishare.protocol.constants

/**
 * Protocol-level configuration constants.
 */
object BIShareConfig {
    const val VERSION = "2.2"
    const val PROTOCOL_SCHEME = "https"

    // Deep Links
    const val SCHEME = "bishare"

    // Code Generation
    /** Character set for room codes (no I, O, 0, 1) */
    const val CODE_CHARSET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    const val ROOM_CODE_LENGTH = 4

    // Limits
    const val MAX_RECEIVED_FILES_IN_MEMORY = 100
    const val CLIPBOARD_HISTORY_MAX = 20
    /** Clipboard polling interval in milliseconds (Android) */
    const val CLIPBOARD_POLL_INTERVAL_MS = 2000L
    const val ACCEPT_REJECT_TIMEOUT_MS = 30_000L
    const val STALE_DEVICE_TIMEOUT_MS = 15_000L

    // Parallel Transfer
    /** Default max concurrent file uploads allowed by server */
    const val DEFAULT_MAX_CONCURRENT = 4

    // Binary Protocol
    /** Protocol version that supports binary transfer */
    const val BINARY_PROTOCOL_MIN_VERSION = "2.1"
    /** Port offset for binary protocol (main port + 2) */
    const val BINARY_PORT_OFFSET = 2

    // Speed Protocol (v2.2)

    /** Protocol version that supports v2.2 speed optimizations */
    const val SPEED_PROTOCOL_MIN_VERSION = "2.2"

    /** Default chunk size for binary file data frames (256 KB) */
    const val DEFAULT_CHUNK_SIZE = 256 * 1024

    /** Minimum chunk size allowed in negotiation (64 KB) */
    const val MIN_CHUNK_SIZE = 64 * 1024

    /** Maximum chunk size allowed in negotiation (1 MB) */
    const val MAX_CHUNK_SIZE = 1024 * 1024

    /** Default max concurrent file uploads for v2.2+ peers */
    const val DEFAULT_MAX_CONCURRENT_V2 = 8

    /** Flow control: number of chunks sender can have in-flight before waiting for ACK */
    const val DEFAULT_WINDOW_SIZE = 16

    /** Compression minimum size threshold — don't compress below this */
    const val COMPRESSION_MIN_SIZE = 1024L

    /** MIME type prefixes considered compressible */
    val COMPRESSIBLE_MIME_TYPES = setOf(
        "text/",
        "application/json",
        "application/xml",
        "application/javascript",
        "application/x-yaml",
        "application/svg+xml",
        "application/xhtml+xml",
    )

    /** Check if a MIME type is likely compressible. */
    fun isCompressible(mimeType: String): Boolean {
        return COMPRESSIBLE_MIME_TYPES.any { mimeType.startsWith(it) || mimeType == it }
    }
}
