package com.bishare.protocol

import com.bishare.protocol.constants.BISharePort
import com.bishare.protocol.models.*
import com.google.gson.Gson
import org.junit.Assert.*
import org.junit.Test

class ModelsTest {

    private val gson = Gson()

    @Test
    fun deviceInfoDefaultValues() {
        val info = DeviceInfo(alias = "Test", fingerprint = "fp")
        assertEquals("2.0", info.version)
        assertEquals(BISharePort.MAIN, info.port)
        assertEquals("https", info.protocol_)
        assertFalse(info.download)
    }

    @Test
    fun deviceInfoJsonRoundTrip() {
        val info = DeviceInfo(
            alias = "iPhone 15",
            deviceModel = "iphone",
            deviceType = "mobile",
            fingerprint = "test-uuid",
            publicKey = "base64key"
        )
        val json = gson.toJson(info)
        val decoded = gson.fromJson(json, DeviceInfo::class.java)
        assertEquals("iPhone 15", decoded.alias)
        assertEquals(BISharePort.MAIN, decoded.port)
        assertEquals("test-uuid", decoded.fingerprint)
    }

    @Test
    fun deviceInfoProtocolFieldName() {
        val info = DeviceInfo(alias = "Test", fingerprint = "fp")
        val json = gson.toJson(info)
        // Should serialize as "protocol", not "protocol_"
        assertTrue(json.contains("\"protocol\""))
        assertFalse(json.contains("\"protocol_\""))
    }

    @Test
    fun fileMetadataJsonRoundTrip() {
        val meta = FileMetadata(id = "f1", fileName = "photo.jpg", size = 1024, fileType = "image/jpeg", sha256 = "abc123")
        val json = gson.toJson(meta)
        val decoded = gson.fromJson(json, FileMetadata::class.java)
        assertEquals("photo.jpg", decoded.fileName)
        assertEquals(1024L, decoded.size)
        assertNull(decoded.expiresInSeconds)
    }

    @Test
    fun prepareRequestJsonRoundTrip() {
        val info = DeviceInfo(alias = "Sender", fingerprint = "fp1")
        val file = FileMetadata(id = "f1", fileName = "doc.pdf", size = 2048, fileType = "application/pdf")
        val req = PrepareRequest(info = info, files = mapOf("f1" to file))
        val json = gson.toJson(req)
        val decoded = gson.fromJson(json, PrepareRequest::class.java)
        assertEquals(1, decoded.files.size)
        assertEquals("doc.pdf", decoded.files["f1"]?.fileName)
    }

    @Test
    fun clipboardPayloadType() {
        val payload = ClipboardPayload(text = "hello", sender = "fp", alias = "iPhone")
        assertEquals("clipboard", payload.type)
    }

    @Test
    fun discoveredDeviceQUICSupport() {
        val withQuic = DiscoveredDevice(
            id = "1", alias = "Test", deviceModel = "iphone", deviceType = "mobile",
            fingerprint = "fp", version = "2.0", host = "192.168.1.1", port = 58317, quicPort = 58318
        )
        assertTrue(withQuic.supportsQUIC)

        val withoutQuic = DiscoveredDevice(
            id = "2", alias = "Test", deviceModel = "iphone", deviceType = "mobile",
            fingerprint = "fp", version = "2.0", host = "192.168.1.1", port = 58317
        )
        assertFalse(withoutQuic.supportsQUIC)
    }
}
