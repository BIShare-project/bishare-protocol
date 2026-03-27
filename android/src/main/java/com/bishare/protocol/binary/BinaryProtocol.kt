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
    ERROR(0x08);

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
    val encrypted: Boolean = false
)

// MARK: - File End Metadata (JSON in FILE_END payload)

data class BinaryFileEnd(
    val verified: Boolean,
    val encrypted: Boolean = false
)
