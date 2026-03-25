package com.bishare.protocol.util

import com.bishare.protocol.constants.BIShareConfig

/**
 * Generates random codes for rooms and remote transfers.
 */
object CodeGenerator {

    /** Generate a random room code (4 characters). */
    fun generateRoomCode(): String = generateCode(BIShareConfig.ROOM_CODE_LENGTH)

    /** Generate a random remote transfer code (6 characters). */
    fun generateRemoteCode(): String = generateCode(BIShareConfig.REMOTE_CODE_LENGTH)

    /** Generate a full remote share code (16 characters) used as encryption key material. */
    fun generateRemoteFullCode(): String = generateCode(BIShareConfig.REMOTE_FULL_LENGTH)

    /** Format a room code for display (e.g., "AB3X"). */
    fun formatRoomCode(code: String): String = code.uppercase()

    /** Format a remote code for display with dash (e.g., "A3X-9K2"). */
    fun formatRemoteCode(code: String): String {
        val upper = code.uppercase()
        return if (upper.length == 6) {
            "${upper.substring(0, 3)}-${upper.substring(3)}"
        } else {
            upper
        }
    }

    private fun generateCode(length: Int): String {
        val chars = BIShareConfig.CODE_CHARSET
        return (1..length)
            .map { chars.random() }
            .joinToString("")
    }
}
