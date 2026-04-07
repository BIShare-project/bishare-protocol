package com.bishare.protocol

import com.bishare.protocol.binary.*
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
        assertEquals("2.2", info.version)
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

    // v2.2 New Fields

    @Test
    fun deviceInfoSupportsCompression() {
        val info = DeviceInfo(alias = "Test", fingerprint = "fp", supportsCompression = true)
        val json = gson.toJson(info)
        val decoded = gson.fromJson(json, DeviceInfo::class.java)
        assertEquals(true, decoded.supportsCompression)
    }

    @Test
    fun deviceInfoOldJsonBackwardCompat() {
        val json = """{"alias":"Test","version":"2.0","fingerprint":"fp","port":58317,"protocol":"https","download":false}"""
        val decoded = gson.fromJson(json, DeviceInfo::class.java)
        assertEquals("Test", decoded.alias)
        assertNull(decoded.supportsCompression)
        assertNull(decoded.supportsBinary)
    }

    @Test
    fun prepareResponseNewFields() {
        val resp = PrepareResponse(
            sessionId = "s1", files = mapOf("f1" to "t1"),
            chunkSize = 262_144, windowSize = 16, supportsCompression = true
        )
        val json = gson.toJson(resp)
        val decoded = gson.fromJson(json, PrepareResponse::class.java)
        assertEquals(262_144, decoded.chunkSize)
        assertEquals(16, decoded.windowSize)
        assertEquals(true, decoded.supportsCompression)
    }

    @Test
    fun prepareResponseOldJsonBackwardCompat() {
        val json = """{"sessionId":"s1","files":{"f1":"t1"}}"""
        val decoded = gson.fromJson(json, PrepareResponse::class.java)
        assertEquals("s1", decoded.sessionId)
        assertNull(decoded.chunkSize)
        assertNull(decoded.windowSize)
        assertNull(decoded.supportsCompression)
        assertNull(decoded.maxConcurrent)
    }

    @Test
    fun binaryFileStartNewFields() {
        val start = BinaryFileStart(
            fileName = "test.txt", size = 1024, fileType = "text/plain",
            compression = 0x01, baseNonce = "AQIDBA==", chunkSize = 262_144
        )
        val json = gson.toJson(start)
        val decoded = gson.fromJson(json, BinaryFileStart::class.java)
        assertEquals(0x01.toByte(), decoded.compression)
        assertEquals("AQIDBA==", decoded.baseNonce)
        assertEquals(262_144, decoded.chunkSize)
    }

    @Test
    fun binaryAckCoding() {
        val ack = BinaryAck(chunksReceived = 42, windowSize = 16)
        val json = gson.toJson(ack)
        val decoded = gson.fromJson(json, BinaryAck::class.java)
        assertEquals(42L, decoded.chunksReceived)
        assertEquals(16, decoded.windowSize)
    }

    @Test
    fun newMessageTypes() {
        assertEquals(BIShareMessageType.ACK, BIShareMessageType.fromByte(0x09))
        assertEquals(BIShareMessageType.PAUSE, BIShareMessageType.fromByte(0x0A))
        assertEquals(BIShareMessageType.RESUME, BIShareMessageType.fromByte(0x0B))
    }

    @Test
    fun decoderV2ZeroCopy() {
        val frame1 = BIShareBinaryEncoder.encodeSessionEnd()
        val frame2 = BIShareBinaryEncoder.encodeCancel()
        val buffer = frame1 + frame2

        val (views, consumed) = BIShareBinaryDecoderV2.decodeAll(buffer)
        assertEquals(2, views.size)
        assertEquals(buffer.size, consumed)
        assertEquals(BIShareMessageType.SESSION_END, views[0].type)
        assertEquals(0, views[0].payloadLength)
        assertEquals(BIShareMessageType.CANCEL, views[1].type)
    }

    @Test
    fun decoderV2WithPayload() {
        val payload = "test-payload".toByteArray()
        val frame = BIShareBinaryEncoder.encode(BIShareFrame(BIShareMessageType.FILE_DATA, 42u, payload))
        val result = BIShareBinaryDecoderV2.decode(frame)
        assertTrue(result is BIShareBinaryDecoderV2.DecodeResultV2.Success)
        val success = result as BIShareBinaryDecoderV2.DecodeResultV2.Success
        assertEquals(BIShareMessageType.FILE_DATA, success.frame.type)
        assertEquals(42u, success.frame.fileId)
        assertArrayEquals(payload, success.frame.payload())
        assertEquals(frame.size, success.consumedBytes)
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
