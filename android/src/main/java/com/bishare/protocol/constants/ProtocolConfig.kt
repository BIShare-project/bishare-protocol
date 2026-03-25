package com.bishare.protocol.constants

/**
 * Protocol-level configuration constants.
 */
object BIShareConfig {
    const val VERSION = "2.0"
    const val PROTOCOL_SCHEME = "https"

    // Deep Links
    const val SCHEME = "bishare"
    const val REMOTE_SCHEME = "bishare-remote"

    // Code Generation
    /** Character set for room codes and remote codes (no I, O, 0, 1) */
    const val CODE_CHARSET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    const val ROOM_CODE_LENGTH = 4
    const val REMOTE_CODE_LENGTH = 6
    const val REMOTE_FULL_LENGTH = 16

    // Relay
    const val RELAY_BASE_URL = "https://bishare-relay.cakrabudiman.workers.dev"

    // Limits
    const val MAX_RECEIVED_FILES_IN_MEMORY = 100
    const val CLIPBOARD_HISTORY_MAX = 20
    /** Clipboard polling interval in milliseconds (Android) */
    const val CLIPBOARD_POLL_INTERVAL_MS = 2000L
    const val ACCEPT_REJECT_TIMEOUT_MS = 30_000L
    const val STALE_DEVICE_TIMEOUT_MS = 15_000L
    /** Maximum file size for remote transfer (500 MB) */
    const val REMOTE_FILE_MAX_SIZE = 500L * 1024 * 1024
    const val REMOTE_EXPIRY_HOURS = 24
}
