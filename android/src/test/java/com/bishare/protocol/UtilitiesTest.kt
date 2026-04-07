package com.bishare.protocol

import com.bishare.protocol.constants.BIShareConfig
import com.bishare.protocol.util.*
import org.junit.Assert.*
import org.junit.Test

class UtilitiesTest {

    // FileNameSanitizer

    @Test
    fun sanitizeNormalFileName() {
        assertEquals("photo.jpg", FileNameSanitizer.sanitize("photo.jpg"))
    }

    @Test
    fun sanitizePathTraversal() {
        val result = FileNameSanitizer.sanitize("../../etc/passwd")
        assertFalse(result.contains(".."))
    }

    @Test
    fun sanitizeSlashes() {
        val result = FileNameSanitizer.sanitize("path/to/file.txt")
        assertEquals("file.txt", result)
    }

    @Test
    fun sanitizeEmptyName() {
        assertEquals("unnamed", FileNameSanitizer.sanitize(""))
        assertEquals("unnamed", FileNameSanitizer.sanitize("   "))
    }

    @Test
    fun sanitizeColons() {
        val result = FileNameSanitizer.sanitize("file:name.txt")
        assertFalse(result.contains(":"))
    }

    // FileCategorizer

    @Test
    fun categorizerImages() {
        assertEquals("Images", FileCategorizer.category("image/jpeg"))
        assertEquals("Images", FileCategorizer.category("image/png"))
    }

    @Test
    fun categorizerDocuments() {
        assertEquals("Documents", FileCategorizer.category("application/pdf"))
        assertEquals("Documents", FileCategorizer.category("text/plain"))
    }

    @Test
    fun categorizerArchives() {
        assertEquals("Archives", FileCategorizer.category("application/zip"))
    }

    @Test
    fun categorizerOther() {
        assertEquals("Other", FileCategorizer.category("application/octet-stream"))
    }

    // CodeGenerator

    @Test
    fun roomCodeLength() {
        val code = CodeGenerator.generateRoomCode()
        assertEquals(BIShareConfig.ROOM_CODE_LENGTH, code.length)
    }

    @Test
    fun codeCharsetOnly() {
        val code = CodeGenerator.generateRoomCode()
        val charset = BIShareConfig.CODE_CHARSET
        for (char in code) {
            assertTrue("Code contains invalid character: $char", charset.contains(char))
        }
    }

    // SmartNaming

    @Test
    fun smartNaming() {
        val cal = java.util.Calendar.getInstance()
        cal.set(2026, 2, 24) // March 24, 2026
        val name = SmartNaming.format("photo.jpg", "iPhone 15", cal.time)
        assertEquals("2026-03-24_iPhone-15_photo.jpg", name)
    }
}
