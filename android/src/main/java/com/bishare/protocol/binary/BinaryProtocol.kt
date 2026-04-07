package com.bishare.protocol.binary

import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Binary transfer protocol for BIShare — replaces HTTP overhead for file data.
 *
 * Frame format (9-byte header + payload):
 * ```
 * ┌──────────┬────────────┬───────────┬──────────────┐
 * │ Type 1B  │ Length 4B  │ FileID 4B │ Payload ...  │
 * └──────────┴────────────┴───────────┴──────────────┘
 * ```
 *
 * HTTP endpoints are kept for browser access, device probing, and backward compatibility.
 */

// MARK: - Message Types

enum class BIShareMessageType(val value: Byte) {
    PREPARE(0x01),
    PREPARE_ACK(0x02),
    FILE_START(0x03),
    FILE_DATA(0x04),
    FILE_END(0x05),
    SESSION_END(0x06),
    CANCEL(0x07),
    ERROR(0x08),
    ACK(0x09),
    PAUSE(0x0A),
    RESUME(0x0B);

    companion object {
        fun fromByte(b: Byte): BIShareMessageType? = entries.firstOrNull { it.value == b }
    }
}

// MARK: - Binary Frame

data class BIShareFrame(
    val type: BIShareMessageType,
    val fileId: UInt = 0u,
    val payload: ByteArray = ByteArray(0)
) {
    companion object {
        const val HEADER_SIZE = 9
    }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is BIShareFrame) return false
        return type == other.type && fileId == other.fileId && payload.contentEquals(other.payload)
    }

    override fun hashCode(): Int {
        var result = type.hashCode()
        result = 31 * result + fileId.hashCode()
        result = 31 * result + payload.contentHashCode()
        return result
    }
}

// MARK: - Encoder

object BIShareBinaryEncoder {

    /** Encode a frame to wire format: [type:1][length:4][fileId:4][payload:N] */
    fun encode(frame: BIShareFrame): ByteArray {
        val buffer = ByteBuffer.allocate(BIShareFrame.HEADER_SIZE + frame.payload.size)
        buffer.order(ByteOrder.BIG_ENDIAN)

        // Type (1 byte)
        buffer.put(frame.type.value)

        // Payload length (4 bytes, big-endian)
        buffer.putInt(frame.payload.size)

        // File ID (4 bytes, big-endian)
        buffer.putInt(frame.fileId.toInt())

        // Payload
        buffer.put(frame.payload)

        return buffer.array()
    }

    /** Convenience: encode a JSON string as payload */
    fun encodeJSON(type: BIShareMessageType, fileId: UInt = 0u, json: String): ByteArray {
        return encode(BIShareFrame(type, fileId, json.toByteArray(Charsets.UTF_8)))
    }

    /** Convenience: encode a file data chunk */
    fun encodeFileData(fileId: UInt, data: ByteArray): ByteArray {
        return encode(BIShareFrame(BIShareMessageType.FILE_DATA, fileId, data))
    }

    /** Convenience: encode session end */
    fun encodeSessionEnd(): ByteArray {
        return encode(BIShareFrame(BIShareMessageType.SESSION_END))
    }

    /** Convenience: encode cancel */
    fun encodeCancel(): ByteArray {
        return encode(BIShareFrame(BIShareMessageType.CANCEL))
    }
}

// MARK: - Decoder

object BIShareBinaryDecoder {

    sealed class DecodeResult {
        data class Success(val frame: BIShareFrame, val remaining: ByteArray) : DecodeResult()
        data object NeedMoreData : DecodeResult()
        data class Error(val message: String) : DecodeResult()
    }

    /** Decode one frame from the front of the buffer. */
    fun decode(buffer: ByteArray): DecodeResult {
        if (buffer.size < BIShareFrame.HEADER_SIZE) {
            return DecodeResult.NeedMoreData
        }

        val bb = ByteBuffer.wrap(buffer).order(ByteOrder.BIG_ENDIAN)

        // Parse header
        val typeByte = bb.get()
        val type = BIShareMessageType.fromByte(typeByte)
            ?: return DecodeResult.Error("Unknown message type: 0x${"%02X".format(typeByte)}")

        val length = bb.getInt().toLong() and 0xFFFFFFFFL // unsigned
        val fileId = bb.getInt().toUInt()

        // Guard against impossibly large payloads (>2GB per frame)
        if (length > Int.MAX_VALUE) {
            return DecodeResult.Error("Payload too large: $length bytes")
        }

        // Check if full payload is available
        val totalFrameSize = BIShareFrame.HEADER_SIZE + length.toInt()
        if (buffer.size < totalFrameSize) {
            return DecodeResult.NeedMoreData
        }

        val payload = buffer.copyOfRange(BIShareFrame.HEADER_SIZE, totalFrameSize)
        val remaining = buffer.copyOfRange(totalFrameSize, buffer.size)

        return DecodeResult.Success(BIShareFrame(type, fileId, payload), remaining)
    }

    /** Decode all complete frames from a buffer. Returns frames + leftover bytes. */
    fun decodeAll(buffer: ByteArray): Pair<List<BIShareFrame>, ByteArray> {
        val frames = mutableListOf<BIShareFrame>()
        var remaining = buffer

        while (remaining.isNotEmpty()) {
            when (val result = decode(remaining)) {
                is DecodeResult.Success -> {
                    frames.add(result.frame)
                    remaining = result.remaining
                }
                is DecodeResult.NeedMoreData -> return Pair(frames, remaining)
                is DecodeResult.Error -> {
                    System.err.println("[BinaryProtocol] Decode error: ${result.message}")
                    return Pair(frames, remaining)
                }
            }
        }

        return Pair(frames, ByteArray(0))
    }
}

// MARK: - File Start Metadata (JSON in FILE_START payload)

data class BinaryFileStart(
    val fileName: String,
    val size: Long,
    val fileType: String,
    val sha256: String? = null,
    val encrypted: Boolean = false,
    val compression: Byte? = null,
    val baseNonce: String? = null,
    val chunkSize: Int? = null
)

// MARK: - File End Metadata (JSON in FILE_END payload)

data class BinaryFileEnd(
    val verified: Boolean,
    val encrypted: Boolean = false
)

// MARK: - Compression (v2.2)

enum class BIShareCompression(val value: Byte) {
    NONE(0x00),
    ZLIB(0x01);

    companion object {
        fun fromByte(b: Byte): BIShareCompression? = entries.firstOrNull { it.value == b }
    }
}

// MARK: - Flow Control Structs (v2.2)

data class BinaryAck(
    val chunksReceived: Long,
    val windowSize: Int
)

data class BinaryPause(
    val fileId: Long = 0
)

data class BinaryResume(
    val windowSize: Int
)

// MARK: - Zero-Copy Decoder (v2.2)

/** A view into a shared buffer — avoids copying payload bytes on decode. */
data class BIShareFrameView(
    val type: BIShareMessageType,
    val fileId: UInt,
    val buffer: ByteArray,
    val payloadOffset: Int,
    val payloadLength: Int
) {
    /** Access payload bytes (creates a copy only when called). */
    fun payload(): ByteArray = buffer.copyOfRange(payloadOffset, payloadOffset + payloadLength)

    /** Write payload directly to an OutputStream without copying. */
    fun writePayloadTo(out: java.io.OutputStream) {
        out.write(buffer, payloadOffset, payloadLength)
    }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is BIShareFrameView) return false
        return type == other.type && fileId == other.fileId &&
            payloadOffset == other.payloadOffset && payloadLength == other.payloadLength
    }

    override fun hashCode(): Int {
        var result = type.hashCode()
        result = 31 * result + fileId.hashCode()
        result = 31 * result + payloadOffset
        result = 31 * result + payloadLength
        return result
    }
}

object BIShareBinaryDecoderV2 {

    sealed class DecodeResultV2 {
        data class Success(val frame: BIShareFrameView, val consumedBytes: Int) : DecodeResultV2()
        data object NeedMoreData : DecodeResultV2()
        data class Error(val message: String) : DecodeResultV2()
    }

    /** Zero-copy decode: returns a frame view + consumed byte count. */
    fun decode(buffer: ByteArray, offset: Int = 0): DecodeResultV2 {
        val available = buffer.size - offset
        if (available < BIShareFrame.HEADER_SIZE) {
            return DecodeResultV2.NeedMoreData
        }

        val bb = ByteBuffer.wrap(buffer, offset, BIShareFrame.HEADER_SIZE).order(ByteOrder.BIG_ENDIAN)

        val typeByte = bb.get()
        val type = BIShareMessageType.fromByte(typeByte)
            ?: return DecodeResultV2.Error("Unknown message type: 0x${"%02X".format(typeByte)}")

        val length = bb.getInt().toLong() and 0xFFFFFFFFL
        val fileId = bb.getInt().toUInt()

        if (length > Int.MAX_VALUE) {
            return DecodeResultV2.Error("Payload too large: $length bytes")
        }

        val totalFrameSize = BIShareFrame.HEADER_SIZE + length.toInt()
        if (available < totalFrameSize) {
            return DecodeResultV2.NeedMoreData
        }

        val payloadOffset = offset + BIShareFrame.HEADER_SIZE
        val view = BIShareFrameView(type, fileId, buffer, payloadOffset, length.toInt())
        return DecodeResultV2.Success(view, totalFrameSize)
    }

    /** Decode all complete frames from a buffer using zero-copy. Returns frame views + total bytes consumed. */
    fun decodeAll(buffer: ByteArray): Pair<List<BIShareFrameView>, Int> {
        val frames = mutableListOf<BIShareFrameView>()
        var offset = 0

        while (offset < buffer.size) {
            when (val result = decode(buffer, offset)) {
                is DecodeResultV2.Success -> {
                    frames.add(result.frame)
                    offset += result.consumedBytes
                }
                is DecodeResultV2.NeedMoreData -> return Pair(frames, offset)
                is DecodeResultV2.Error -> {
                    System.err.println("[BinaryProtocol] Decode error: ${result.message}")
                    return Pair(frames, offset)
                }
            }
        }

        return Pair(frames, offset)
    }
}
