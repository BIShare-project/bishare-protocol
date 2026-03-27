package com.bishare.protocol.util

import com.bishare.protocol.constants.BIShareConfig

/**
 * Generates random codes for rooms.
 */
object CodeGenerator {

    /** Generate a random room code (4 characters). */
    fun generateRoomCode(): String = generateCode(BIShareConfig.ROOM_CODE_LENGTH)

    /** Format a room code for display (e.g., "AB3X"). */
    fun formatRoomCode(code: String): String = code.uppercase()

    private fun generateCode(length: Int): String {
        val chars = BIShareConfig.CODE_CHARSET
        return (1..length)
            .map { chars.random() }
            .joinToString("")
    }
}
