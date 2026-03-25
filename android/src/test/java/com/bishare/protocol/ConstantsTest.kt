package com.bishare.protocol

import com.bishare.protocol.constants.*
import org.junit.Assert.*
import org.junit.Test

class ConstantsTest {

    @Test
    fun portsAreInDynamicRange() {
        assertTrue(BISharePort.MAIN in 49152..65535)
        assertTrue(BISharePort.QUIC in 49152..65535)
        assertTrue(BISharePort.ROOM in 49152..65535)
        assertTrue(BISharePort.WEBDAV in 49152..65535)
    }

    @Test
    fun portsAreSequential() {
        assertEquals(BISharePort.QUIC, BISharePort.MAIN + 1)
        assertEquals(BISharePort.ROOM, BISharePort.MAIN + 2)
        assertEquals(BISharePort.WEBDAV, BISharePort.MAIN + 3)
    }

    @Test
    fun portsNotLocalSend() {
        assertNotEquals(53317, BISharePort.MAIN)
        assertNotEquals(53318, BISharePort.QUIC)
        assertNotEquals(53319, BISharePort.ROOM)
        assertNotEquals(53320, BISharePort.WEBDAV)
    }

    @Test
    fun serviceTypes() {
        assertEquals("_bishare._tcp.", BIShareService.DISCOVERY)
        assertEquals("_bishare._tcp", BIShareService.DISCOVERY_RAW)
        assertEquals("_bishare-room._tcp.", BIShareService.ROOM)
        assertEquals("_bishare-room._tcp", BIShareService.ROOM_RAW)
    }

    @Test
    fun apiPaths() {
        assertTrue(BIShareAPI.INFO.startsWith("/api/v1/"))
        assertTrue(BIShareAPI.PREPARE.startsWith("/api/v1/"))
        assertTrue(BIShareAPI.ROOM_INFO.startsWith("/api/v1/room/"))
    }

    @Test
    fun cryptoConstants() {
        assertEquals(32, BIShareCrypto.AES_KEY_SIZE)
        assertEquals(12, BIShareCrypto.GCM_NONCE_SIZE)
        assertEquals(128, BIShareCrypto.GCM_TAG_BITS)
        assertEquals(8, BIShareCrypto.FINGERPRINT_BYTES)
    }

    @Test
    fun codeCharsetNoAmbiguousChars() {
        val charset = BIShareConfig.CODE_CHARSET
        assertFalse(charset.contains('I'))
        assertFalse(charset.contains('O'))
        assertFalse(charset.contains('0'))
        assertFalse(charset.contains('1'))
    }

    @Test
    fun fileCategories() {
        assertEquals(BIShareFileCategory.IMAGES, BIShareFileCategory.from("image/jpeg"))
        assertEquals(BIShareFileCategory.VIDEOS, BIShareFileCategory.from("video/mp4"))
        assertEquals(BIShareFileCategory.AUDIO, BIShareFileCategory.from("audio/mpeg"))
        assertEquals(BIShareFileCategory.DOCUMENTS, BIShareFileCategory.from("application/pdf"))
        assertEquals(BIShareFileCategory.DOCUMENTS, BIShareFileCategory.from("text/plain"))
        assertEquals(BIShareFileCategory.ARCHIVES, BIShareFileCategory.from("application/zip"))
        assertEquals(BIShareFileCategory.OTHER, BIShareFileCategory.from("application/octet-stream"))
    }
}
