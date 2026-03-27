import Foundation

/// Binary transfer protocol for BIShare — replaces HTTP overhead for file data.
///
/// Frame format (9-byte header + payload):
/// ```
/// ┌──────────┬────────────┬───────────┬──────────────┐
/// │ Type 1B  │ Length 4B  │ FileID 4B │ Payload ...  │
/// └──────────┴────────────┴───────────┴──────────────┘
/// ```
///
/// - Type: message type (1 byte)
/// - Length: payload length in bytes (4 bytes, big-endian UInt32)
/// - FileID: file identifier (4 bytes, big-endian UInt32, 0 for session-level messages)
/// - Payload: variable-length data
///
/// HTTP endpoints are kept for browser access, device probing, and backward compatibility.
/// Binary protocol is used only for the file data transfer path (prepare → upload → done).

// MARK: - Message Types

public enum BIShareMessageType: UInt8, Sendable {
    /// Session setup — JSON payload: PrepareRequest
    case prepare     = 0x01
    /// Session setup response — JSON payload: PrepareResponse
    case prepareAck  = 0x02
    /// File header — JSON payload: {fileName, size, fileType, sha256}
    case fileStart   = 0x03
    /// File data chunk — raw bytes payload
    case fileData    = 0x04
    /// File transfer complete — empty or JSON {verified: Bool}
    case fileEnd     = 0x05
    /// All files sent — session complete
    case sessionEnd  = 0x06
    /// Cancel transfer
    case cancel      = 0x07
    /// Error — JSON payload: {message: String}
    case error       = 0x08
}

// MARK: - Binary Frame

public struct BIShareFrame: Sendable {
    public let type: BIShareMessageType
    public let fileId: UInt32
    public let payload: Data

    public init(type: BIShareMessageType, fileId: UInt32 = 0, payload: Data = Data()) {
        self.type = type
        self.fileId = fileId
        self.payload = payload
    }

    /// Header size in bytes (type + length + fileId)
    public static let headerSize = 9
}

// MARK: - Encoder

public enum BIShareBinaryEncoder {

    /// Encode a frame to wire format: [type:1][length:4][fileId:4][payload:N]
    public static func encode(_ frame: BIShareFrame) -> Data {
        var data = Data(capacity: BIShareFrame.headerSize + frame.payload.count)

        // Type (1 byte)
        data.append(frame.type.rawValue)

        // Payload length (4 bytes, big-endian)
        var length = UInt32(frame.payload.count).bigEndian
        data.append(Data(bytes: &length, count: 4))

        // File ID (4 bytes, big-endian)
        var fileId = frame.fileId.bigEndian
        data.append(Data(bytes: &fileId, count: 4))

        // Payload
        data.append(frame.payload)

        return data
    }

    /// Convenience: encode a Codable value as JSON payload
    public static func encodeJSON<T: Encodable>(_ type: BIShareMessageType, fileId: UInt32 = 0, value: T) -> Data? {
        guard let json = try? JSONEncoder().encode(value) else { return nil }
        return encode(BIShareFrame(type: type, fileId: fileId, payload: json))
    }

    /// Convenience: encode a file data chunk
    public static func encodeFileData(fileId: UInt32, data: Data) -> Data {
        encode(BIShareFrame(type: .fileData, fileId: fileId, payload: data))
    }

    /// Convenience: encode session-level message (no file ID)
    public static func encodeSessionEnd() -> Data {
        encode(BIShareFrame(type: .sessionEnd))
    }

    /// Convenience: encode cancel
    public static func encodeCancel() -> Data {
        encode(BIShareFrame(type: .cancel))
    }
}

// MARK: - Decoder

public enum BIShareBinaryDecoder {

    public enum DecodeResult: Sendable {
        /// Successfully decoded a frame, with remaining unconsumed bytes
        case success(BIShareFrame, remaining: Data)
        /// Need more data to decode (incomplete frame)
        case needMoreData
        /// Decode error
        case error(String)
    }

    /// Decode one frame from the front of the buffer.
    /// Returns the frame + remaining bytes, or `.needMoreData` if buffer is incomplete.
    public static func decode(_ buffer: Data) -> DecodeResult {
        guard buffer.count >= BIShareFrame.headerSize else {
            return .needMoreData
        }

        // Parse header — copy to contiguous array for safe alignment
        let header = [UInt8](buffer[buffer.startIndex..<buffer.startIndex + BIShareFrame.headerSize])

        let typeByte = header[0]
        guard let type = BIShareMessageType(rawValue: typeByte) else {
            return .error("Unknown message type: 0x\(String(format: "%02X", typeByte))")
        }

        let length = UInt32(header[1]) << 24 | UInt32(header[2]) << 16 | UInt32(header[3]) << 8 | UInt32(header[4])
        let fileId = UInt32(header[5]) << 24 | UInt32(header[6]) << 16 | UInt32(header[7]) << 8 | UInt32(header[8])

        // Guard against impossibly large payloads (>2GB per frame)
        guard length <= UInt32(Int32.max) else {
            return .error("Payload too large: \(length) bytes")
        }

        // Check if full payload is available
        let totalFrameSize = BIShareFrame.headerSize + Int(length)
        guard buffer.count >= totalFrameSize else {
            return .needMoreData
        }

        let payloadStart = buffer.startIndex + BIShareFrame.headerSize
        let payloadEnd = payloadStart + Int(length)
        let payload = Data(buffer[payloadStart..<payloadEnd])
        let remaining = Data(buffer[payloadEnd...])

        let frame = BIShareFrame(type: type, fileId: fileId, payload: payload)
        return .success(frame, remaining: remaining)
    }

    /// Decode all complete frames from a buffer. Returns frames + leftover bytes.
    public static func decodeAll(_ buffer: Data) -> ([BIShareFrame], Data) {
        var frames: [BIShareFrame] = []
        var remaining = buffer

        while !remaining.isEmpty {
            switch decode(remaining) {
            case .success(let frame, let rest):
                frames.append(frame)
                remaining = rest
            case .needMoreData:
                return (frames, remaining)
            case .error(let msg):
                print("[BinaryProtocol] Decode error: \(msg)")
                return (frames, remaining)
            }
        }

        return (frames, Data())
    }

    /// Convenience: decode JSON payload from a frame
    public static func decodeJSON<T: Decodable>(_ frame: BIShareFrame, as type: T.Type) -> T? {
        try? JSONDecoder().decode(type, from: frame.payload)
    }
}

// MARK: - File Start Metadata (sent in FILE_START frame payload)

public struct BinaryFileStart: Codable, Sendable {
    public let fileName: String
    public let size: Int64
    public let fileType: String
    public let sha256: String?
    public let encrypted: Bool

    public init(fileName: String, size: Int64, fileType: String, sha256: String?, encrypted: Bool = false) {
        self.fileName = fileName
        self.size = size
        self.fileType = fileType
        self.sha256 = sha256
        self.encrypted = encrypted
    }
}

// MARK: - File End Metadata (sent in FILE_END frame payload)

public struct BinaryFileEnd: Codable, Sendable {
    public let verified: Bool
    public let encrypted: Bool

    public init(verified: Bool, encrypted: Bool = false) {
        self.verified = verified
        self.encrypted = encrypted
    }
}
