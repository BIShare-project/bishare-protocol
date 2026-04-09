use serde::{Deserialize, Serialize};
use std::collections::HashMap;

use crate::constants::{Config, Port};

// ── Device Info ──

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DeviceInfo {
    pub alias: String,
    #[serde(default = "default_version")]
    pub version: String,
    #[serde(rename = "deviceModel", skip_serializing_if = "Option::is_none")]
    pub device_model: Option<String>,
    #[serde(rename = "deviceType", skip_serializing_if = "Option::is_none")]
    pub device_type: Option<String>,
    pub fingerprint: String,
    #[serde(default = "default_port")]
    pub port: u16,
    #[serde(rename = "protocol", default = "default_protocol")]
    pub protocol_: String,
    #[serde(default)]
    pub download: bool,
    #[serde(rename = "publicKey", skip_serializing_if = "Option::is_none")]
    pub public_key: Option<String>,
    #[serde(rename = "supportsBinary", skip_serializing_if = "Option::is_none")]
    pub supports_binary: Option<bool>,
    #[serde(rename = "supportsCompression", skip_serializing_if = "Option::is_none")]
    pub supports_compression: Option<bool>,
}

fn default_version() -> String { Config::VERSION.to_string() }
fn default_port() -> u16 { Port::MAIN }
fn default_protocol() -> String { Config::PROTOCOL_SCHEME.to_string() }

impl Default for DeviceInfo {
    fn default() -> Self {
        Self {
            alias: String::new(),
            version: Config::VERSION.to_string(),
            device_model: None,
            device_type: None,
            fingerprint: String::new(),
            port: Port::MAIN,
            protocol_: Config::PROTOCOL_SCHEME.to_string(),
            download: false,
            public_key: None,
            supports_binary: Some(true),
            supports_compression: None,
        }
    }
}

// ── File Metadata ──

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FileMetadata {
    pub id: String,
    #[serde(rename = "fileName")]
    pub file_name: String,
    pub size: i64,
    #[serde(rename = "fileType")]
    pub file_type: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub sha256: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub preview: Option<String>,
    #[serde(rename = "expiresInSeconds", skip_serializing_if = "Option::is_none")]
    pub expires_in_seconds: Option<i32>,
}

// ── Transfer Types ──

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PrepareRequest {
    pub info: DeviceInfo,
    pub files: HashMap<String, FileMetadata>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PrepareResponse {
    #[serde(rename = "sessionId")]
    pub session_id: String,
    pub files: HashMap<String, String>, // fileId → token
    #[serde(rename = "publicKey", skip_serializing_if = "Option::is_none")]
    pub public_key: Option<String>,
    #[serde(rename = "maxConcurrent", skip_serializing_if = "Option::is_none")]
    pub max_concurrent: Option<usize>,
    #[serde(rename = "chunkSize", skip_serializing_if = "Option::is_none")]
    pub chunk_size: Option<usize>,
    #[serde(rename = "windowSize", skip_serializing_if = "Option::is_none")]
    pub window_size: Option<usize>,
    #[serde(rename = "supportsCompression", skip_serializing_if = "Option::is_none")]
    pub supports_compression: Option<bool>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UploadResponse {
    pub success: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub verified: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub encrypted: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub message: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ErrorResponse {
    pub message: String,
}

// ── Session Types ──

#[derive(Debug, Clone)]
pub struct TransferSession {
    pub session_id: String,
    pub sender_info: DeviceInfo,
    pub files: HashMap<String, FileMetadata>,
    pub tokens: HashMap<String, String>,
    pub uploaded_files: std::collections::HashSet<String>,
    pub created_at: chrono::DateTime<chrono::Utc>,
    pub encryption_key: Option<Vec<u8>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ReceivedFile {
    pub id: String,
    #[serde(rename = "fileName")]
    pub file_name: String,
    pub size: i64,
    #[serde(rename = "fileType")]
    pub file_type: String,
    #[serde(rename = "savedPath")]
    pub saved_path: String,
    #[serde(rename = "senderAlias")]
    pub sender_alias: String,
    #[serde(rename = "receivedAt")]
    pub received_at: i64, // unix timestamp ms
    pub verified: bool,
    #[serde(default)]
    pub encrypted: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SharedFileInfo {
    pub index: usize,
    #[serde(rename = "fileName")]
    pub file_name: String,
    #[serde(rename = "fileType")]
    pub file_type: String,
    pub size: i64,
}

// ── Room Types ──

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RoomMember {
    pub fingerprint: String,
    pub alias: String,
    #[serde(rename = "deviceType")]
    pub device_type: String,
    pub host: String,
    pub port: u16,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RoomFileItem {
    pub id: String,
    #[serde(rename = "fileName")]
    pub file_name: String,
    #[serde(rename = "fileType")]
    pub file_type: String,
    pub size: i64,
    #[serde(rename = "ownerAlias")]
    pub owner_alias: String,
    #[serde(rename = "ownerFingerprint")]
    pub owner_fingerprint: String,
    #[serde(rename = "addedAt", skip_serializing_if = "Option::is_none")]
    pub added_at: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RoomInfo {
    pub code: String,
    #[serde(rename = "hostAlias")]
    pub host_alias: String,
    #[serde(rename = "hostFingerprint")]
    pub host_fingerprint: String,
    #[serde(rename = "memberCount")]
    pub member_count: usize,
    #[serde(rename = "fileCount")]
    pub file_count: usize,
}

// ── Clipboard ──

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ClipboardPayload {
    #[serde(rename = "type", default = "clipboard_type")]
    pub type_: String,
    pub text: String,
    pub sender: String,
    pub alias: String,
}

fn clipboard_type() -> String { "clipboard".to_string() }

impl ClipboardPayload {
    pub fn new(text: String, sender_fingerprint: String, alias: String) -> Self {
        Self {
            type_: "clipboard".to_string(),
            text,
            sender: sender_fingerprint,
            alias,
        }
    }
}

// ── File Request Types ──

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FileRequestMessage {
    #[serde(rename = "requestId")]
    pub request_id: String,
    #[serde(rename = "requesterAlias")]
    pub requester_alias: String,
    #[serde(rename = "requesterFingerprint")]
    pub requester_fingerprint: String,
    #[serde(rename = "requesterHost")]
    pub requester_host: String,
    #[serde(rename = "requesterPort", default = "default_port")]
    pub requester_port: u16,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub message: Option<String>,
    #[serde(rename = "requestedTypes", skip_serializing_if = "Option::is_none")]
    pub requested_types: Option<Vec<String>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FileRequestResponse {
    #[serde(rename = "requestId")]
    pub request_id: String,
    pub accepted: bool,
}

// ── Goodbye ──

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GoodbyeRequest {
    pub fingerprint: String,
}
