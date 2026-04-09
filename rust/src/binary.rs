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
