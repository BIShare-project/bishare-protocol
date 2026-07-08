use serde::{Deserialize, Serialize};

/// Binary frame header size: [Type:1][Length:4][FileId:4] = 9 bytes
pub const HEADER_SIZE: usize = 9;

/// Message types in the BIShare binary protocol
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(u8)]
pub enum MessageType {
    Prepare = 0x01,
    PrepareAck = 0x02,
    FileStart = 0x03,
    FileData = 0x04,
    FileEnd = 0x05,
    SessionEnd = 0x06,
    Cancel = 0x07,
    Error = 0x08,
    Ack = 0x09,
    Pause = 0x0A,
    Resume = 0x0B,
}

impl MessageType {
    pub fn from_byte(b: u8) -> Option<Self> {
        match b {
            0x01 => Some(Self::Prepare),
            0x02 => Some(Self::PrepareAck),
            0x03 => Some(Self::FileStart),
            0x04 => Some(Self::FileData),
            0x05 => Some(Self::FileEnd),
            0x06 => Some(Self::SessionEnd),
            0x07 => Some(Self::Cancel),
            0x08 => Some(Self::Error),
            0x09 => Some(Self::Ack),
            0x0A => Some(Self::Pause),
            0x0B => Some(Self::Resume),
            _ => None,
        }
    }
}

/// A decoded binary frame
#[derive(Debug, Clone)]
pub struct Frame {
    pub msg_type: MessageType,
    pub file_id: u32,
    pub payload: Vec<u8>,
}

impl Frame {
    pub fn new(msg_type: MessageType, file_id: u32, payload: Vec<u8>) -> Self {
        Self { msg_type, file_id, payload }
    }
}

/// Zero-copy frame view (reference into buffer)
#[derive(Debug)]
pub struct FrameView<'a> {
    pub msg_type: MessageType,
    pub file_id: u32,
    pub payload: &'a [u8],
}

// ── Encoder ──

pub struct Encoder;

impl Encoder {
    /// Encode a frame: [type:1][length:4 BE][fileId:4 BE][payload]
    pub fn encode(msg_type: MessageType, file_id: u32, payload: &[u8]) -> Vec<u8> {
        let mut buf = Vec::with_capacity(HEADER_SIZE + payload.len());
        buf.push(msg_type as u8);
        buf.extend_from_slice(&(payload.len() as u32).to_be_bytes());
        buf.extend_from_slice(&file_id.to_be_bytes());
        buf.extend_from_slice(payload);
        buf
    }

    /// Encode a JSON-serializable value as a frame
    pub fn encode_json<T: Serialize>(msg_type: MessageType, file_id: u32, value: &T) -> Option<Vec<u8>> {
        let json = serde_json::to_vec(value).ok()?;
        Some(Self::encode(msg_type, file_id, &json))
    }

    /// Encode file data frame
    pub fn encode_file_data(file_id: u32, data: &[u8]) -> Vec<u8> {
        Self::encode(MessageType::FileData, file_id, data)
    }

    /// Encode session end frame
    pub fn encode_session_end() -> Vec<u8> {
        Self::encode(MessageType::SessionEnd, 0, &[])
    }

    /// Encode cancel frame
    pub fn encode_cancel() -> Vec<u8> {
        Self::encode(MessageType::Cancel, 0, &[])
    }
}

// ── Decoder ──

pub enum DecodeResult {
    Success { frame: Frame, consumed: usize },
    NeedMoreData,
    Error(String),
}

pub struct Decoder;

impl Decoder {
    /// Decode a single frame from buffer
    pub fn decode(buffer: &[u8]) -> DecodeResult {
        if buffer.len() < HEADER_SIZE {
            return DecodeResult::NeedMoreData;
        }

        let type_byte = buffer[0];
        let msg_type = match MessageType::from_byte(type_byte) {
            Some(t) => t,
            None => return DecodeResult::Error(format!("Unknown message type: 0x{:02X}", type_byte)),
        };

        let payload_len = u32::from_be_bytes([buffer[1], buffer[2], buffer[3], buffer[4]]) as usize;
        let file_id = u32::from_be_bytes([buffer[5], buffer[6], buffer[7], buffer[8]]);
        let total_len = HEADER_SIZE + payload_len;

        if buffer.len() < total_len {
            return DecodeResult::NeedMoreData;
        }

        let payload = buffer[HEADER_SIZE..total_len].to_vec();
        DecodeResult::Success {
            frame: Frame::new(msg_type, file_id, payload),
            consumed: total_len,
        }
    }

    /// Decode all complete frames from buffer, return frames + total consumed bytes
    pub fn decode_all(buffer: &[u8]) -> (Vec<Frame>, usize) {
        let mut frames = Vec::new();
        let mut offset = 0;

        loop {
            match Self::decode(&buffer[offset..]) {
                DecodeResult::Success { frame, consumed } => {
                    frames.push(frame);
                    offset += consumed;
                }
                DecodeResult::NeedMoreData | DecodeResult::Error(_) => break,
            }
        }

        (frames, offset)
    }

    /// Decode frame payload as JSON
    pub fn decode_json<T: for<'de> Deserialize<'de>>(frame: &Frame) -> Option<T> {
        serde_json::from_slice(&frame.payload).ok()
    }

    // ── Zero-copy decoder V2 ──

    /// Decode a frame view (zero-copy reference into buffer)
    pub fn decode_v2(buffer: &[u8], offset: usize) -> DecodeResultV2 {
        let buf = &buffer[offset..];
        if buf.len() < HEADER_SIZE {
            return DecodeResultV2::NeedMoreData;
        }

        let type_byte = buf[0];
        let msg_type = match MessageType::from_byte(type_byte) {
            Some(t) => t,
            None => return DecodeResultV2::Error(format!("Unknown message type: 0x{:02X}", type_byte)),
        };

        let payload_len = u32::from_be_bytes([buf[1], buf[2], buf[3], buf[4]]) as usize;
        let file_id = u32::from_be_bytes([buf[5], buf[6], buf[7], buf[8]]);
        let total_len = HEADER_SIZE + payload_len;

        if buf.len() < total_len {
            return DecodeResultV2::NeedMoreData;
        }

        DecodeResultV2::Success {
            msg_type,
            file_id,
            payload_offset: offset + HEADER_SIZE,
            payload_length: payload_len,
            consumed: total_len,
        }
    }
}

pub enum DecodeResultV2 {
    Success {
        msg_type: MessageType,
        file_id: u32,
        payload_offset: usize,
        payload_length: usize,
        consumed: usize,
    },
    NeedMoreData,
    Error(String),
}

// ── File transfer metadata structs ──

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BinaryFileStart {
    #[serde(rename = "fileName")]
    pub file_name: String,
    pub size: i64,
    #[serde(rename = "fileType")]
    pub file_type: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub sha256: Option<String>,
    #[serde(default)]
    pub encrypted: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub compression: Option<u8>,
    #[serde(rename = "baseNonce", skip_serializing_if = "Option::is_none")]
    pub base_nonce: Option<String>,
    #[serde(rename = "chunkSize", skip_serializing_if = "Option::is_none")]
    pub chunk_size: Option<usize>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BinaryFileEnd {
    pub verified: bool,
    #[serde(default)]
    pub encrypted: bool,
}

/// Compression type
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(u8)]
pub enum Compression {
    None = 0x00,
    Zlib = 0x01,
}

/// Flow control: ACK
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BinaryAck {
    #[serde(rename = "chunksReceived")]
    pub chunks_received: u64,
    #[serde(rename = "windowSize")]
    pub window_size: usize,
}

/// Flow control: Pause
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BinaryPause {
    #[serde(rename = "fileId")]
    pub file_id: u32,
}

/// Flow control: Resume
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BinaryResume {
    #[serde(rename = "windowSize")]
    pub window_size: usize,
}

/// Error message
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BinaryError {
    pub message: String,
}

#[cfg(test)]
mod tests {
    use super::*;
    use pretty_assertions::assert_eq;

    #[test]
    fn test_encode_decode_roundtrip() {
        let payload = b"hello binary".to_vec();
        let encoded = Encoder::encode(MessageType::FileData, 42, &payload);
        // Header layout: [type:1][length:4 BE][fileId:4 BE]
        assert_eq!(encoded[0], MessageType::FileData as u8);
        assert_eq!(u32::from_be_bytes([encoded[1], encoded[2], encoded[3], encoded[4]]), payload.len() as u32);
        assert_eq!(u32::from_be_bytes([encoded[5], encoded[6], encoded[7], encoded[8]]), 42);

        match Decoder::decode(&encoded) {
            DecodeResult::Success { frame, consumed } => {
                assert_eq!(frame.msg_type, MessageType::FileData);
                assert_eq!(frame.file_id, 42);
                assert_eq!(frame.payload, payload);
                assert_eq!(consumed, HEADER_SIZE + payload.len());
            }
            _ => panic!("expected successful decode"),
        }
    }

    #[test]
    fn test_decode_all_two_frames_and_partial() {
        let mut buffer = Encoder::encode(MessageType::FileStart, 1, b"start");
        buffer.extend_from_slice(&Encoder::encode(MessageType::FileEnd, 1, b"end"));
        let expected_consumed = buffer.len();
        // Trailing partial frame (header incomplete)
        buffer.extend_from_slice(&[0x04, 0x00, 0x00, 0x01, 0x00]);

        let (frames, consumed) = Decoder::decode_all(&buffer);
        assert_eq!(frames.len(), 2);
        assert_eq!(frames[0].msg_type, MessageType::FileStart);
        assert_eq!(frames[0].payload, b"start".to_vec());
        assert_eq!(frames[1].msg_type, MessageType::FileEnd);
        assert_eq!(frames[1].payload, b"end".to_vec());
        assert_eq!(consumed, expected_consumed);
    }

    #[test]
    fn test_decode_need_more_data() {
        assert!(matches!(Decoder::decode(&[0x01, 0x00]), DecodeResult::NeedMoreData));
    }

    #[test]
    fn test_decode_unknown_type() {
        let mut buffer = vec![0xFF];
        buffer.extend_from_slice(&0u32.to_be_bytes());
        buffer.extend_from_slice(&0u32.to_be_bytes());
        assert!(matches!(Decoder::decode(&buffer), DecodeResult::Error(_)));
    }

    #[test]
    fn test_decode_v2_offsets() {
        // Prefix simulates already-consumed bytes (nonzero base offset)
        let prefix = Encoder::encode(MessageType::Ack, 7, b"ack");
        let offset = prefix.len();
        let mut buffer = prefix;
        buffer.extend_from_slice(&Encoder::encode(MessageType::FileData, 9, b"payload"));

        match Decoder::decode_v2(&buffer, offset) {
            DecodeResultV2::Success { msg_type, file_id, payload_offset, payload_length, consumed } => {
                assert_eq!(msg_type, MessageType::FileData);
                assert_eq!(file_id, 9);
                assert_eq!(payload_offset, offset + HEADER_SIZE);
                assert_eq!(payload_length, 7);
                assert_eq!(consumed, HEADER_SIZE + 7);
                assert_eq!(&buffer[payload_offset..payload_offset + payload_length], b"payload");
            }
            _ => panic!("expected successful decode"),
        }
    }

    #[test]
    fn test_message_type_from_byte() {
        let types = [
            (0x01, MessageType::Prepare),
            (0x02, MessageType::PrepareAck),
            (0x03, MessageType::FileStart),
            (0x04, MessageType::FileData),
            (0x05, MessageType::FileEnd),
            (0x06, MessageType::SessionEnd),
            (0x07, MessageType::Cancel),
            (0x08, MessageType::Error),
            (0x09, MessageType::Ack),
            (0x0A, MessageType::Pause),
            (0x0B, MessageType::Resume),
        ];
        for (byte, expected) in types {
            assert_eq!(MessageType::from_byte(byte), Some(expected));
        }
        assert_eq!(MessageType::from_byte(0x00), None);
        assert_eq!(MessageType::from_byte(0xFF), None);
    }

    #[test]
    fn test_binary_file_start_json_full() {
        let start = BinaryFileStart {
            file_name: "photo.jpg".to_string(),
            size: 1024,
            file_type: "image/jpeg".to_string(),
            sha256: Some("abc".to_string()),
            encrypted: true,
            compression: Some(Compression::Zlib as u8),
            base_nonce: Some("bm9uY2U=".to_string()),
            chunk_size: Some(262144),
        };
        let json = serde_json::to_string(&start).unwrap();
        assert!(json.contains("\"fileName\""));
        assert!(json.contains("\"baseNonce\""));
        assert!(json.contains("\"chunkSize\""));
        let parsed: BinaryFileStart = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed.file_name, "photo.jpg");
        assert_eq!(parsed.compression, Some(0x01));
        assert_eq!(parsed.base_nonce, Some("bm9uY2U=".to_string()));
        assert_eq!(parsed.chunk_size, Some(262144));
    }

    #[test]
    fn test_binary_file_start_json_minimal() {
        // v2.2 optional fields absent → None
        let json = r#"{"fileName":"a.txt","size":1,"fileType":"text/plain"}"#;
        let parsed: BinaryFileStart = serde_json::from_str(json).unwrap();
        assert_eq!(parsed.sha256, None);
        assert!(!parsed.encrypted);
        assert_eq!(parsed.compression, None);
        assert_eq!(parsed.base_nonce, None);
        assert_eq!(parsed.chunk_size, None);
    }

    #[test]
    fn test_binary_file_end_json() {
        let end = BinaryFileEnd { verified: true, encrypted: false };
        let json = serde_json::to_string(&end).unwrap();
        let parsed: BinaryFileEnd = serde_json::from_str(&json).unwrap();
        assert!(parsed.verified);
        assert!(!parsed.encrypted);
    }

    #[test]
    fn test_binary_ack_json() {
        let ack = BinaryAck { chunks_received: 128, window_size: 16 };
        let json = serde_json::to_string(&ack).unwrap();
        assert!(json.contains("\"chunksReceived\":128"));
        assert!(json.contains("\"windowSize\":16"));
        let parsed: BinaryAck = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed.chunks_received, 128);
        assert_eq!(parsed.window_size, 16);
    }

    #[test]
    fn test_binary_pause_resume_error_json() {
        let pause = BinaryPause { file_id: 3 };
        let json = serde_json::to_string(&pause).unwrap();
        assert!(json.contains("\"fileId\":3"));
        let parsed: BinaryPause = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed.file_id, 3);

        let resume = BinaryResume { window_size: 32 };
        let json = serde_json::to_string(&resume).unwrap();
        assert!(json.contains("\"windowSize\":32"));
        let parsed: BinaryResume = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed.window_size, 32);

        let error = BinaryError { message: "boom".to_string() };
        let json = serde_json::to_string(&error).unwrap();
        let parsed: BinaryError = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed.message, "boom");
    }

    #[test]
    fn test_encode_json_decode_json_roundtrip() {
        let ack = BinaryAck { chunks_received: 5, window_size: 8 };
        let encoded = Encoder::encode_json(MessageType::Ack, 2, &ack).unwrap();
        match Decoder::decode(&encoded) {
            DecodeResult::Success { frame, .. } => {
                assert_eq!(frame.msg_type, MessageType::Ack);
                assert_eq!(frame.file_id, 2);
                let parsed: BinaryAck = Decoder::decode_json(&frame).unwrap();
                assert_eq!(parsed.chunks_received, 5);
                assert_eq!(parsed.window_size, 8);
            }
            _ => panic!("expected successful decode"),
        }
    }
}
