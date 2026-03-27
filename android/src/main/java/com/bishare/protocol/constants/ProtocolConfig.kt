package com.bishare.protocol.constants

/**
 * Protocol-level configuration constants.
 */
object BIShareConfig {
    const val VERSION = "2.0"
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
}
