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
    #[serde(rename = "supportsKeepAlive", skip_serializing_if = "Option::is_none")]
    pub supports_keep_alive: Option<bool>,
    /// Self-reported LAN IPv4. Lets peers reach us at our real Wi-Fi address instead of a
    /// transport-resolved endpoint (over Apple AWDL, Bonjour resolves Apple↔Apple peers to an
    /// unreachable IPv6 link-local address).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub ip: Option<String>,
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
            supports_keep_alive: None,
            ip: None,
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
    #[serde(rename = "keepAlive", skip_serializing_if = "Option::is_none")]
    pub keep_alive: Option<bool>,
    #[serde(rename = "streamsPerFile", skip_serializing_if = "Option::is_none")]
    pub streams_per_file: Option<usize>,
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

#[cfg(test)]
mod tests {
    use super::*;
    use pretty_assertions::assert_eq;

    #[test]
    fn test_device_info_serializes_camel_case() {
        let info = DeviceInfo {
            alias: "MacBook".to_string(),
            device_model: Some("MacBookPro18,1".to_string()),
            device_type: Some("desktop".to_string()),
            fingerprint: "AA BB".to_string(),
            public_key: Some("cGs=".to_string()),
            supports_binary: Some(true),
            supports_compression: Some(true),
            supports_keep_alive: Some(true),
            ..Default::default()
        };
        let json = serde_json::to_string(&info).unwrap();
        assert!(json.contains("\"deviceModel\""));
        assert!(json.contains("\"publicKey\""));
        assert!(json.contains("\"supportsBinary\""));
        assert!(json.contains("\"supportsCompression\""));
        assert!(json.contains("\"supportsKeepAlive\""));
    }

    #[test]
    fn test_device_info_skips_none_fields() {
        let info = DeviceInfo {
            alias: "x".to_string(),
            fingerprint: "y".to_string(),
            supports_binary: None,
            ..Default::default()
        };
        let json = serde_json::to_string(&info).unwrap();
        assert!(!json.contains("deviceModel"));
        assert!(!json.contains("publicKey"));
        assert!(!json.contains("supportsBinary"));
        assert!(!json.contains("supportsCompression"));
        assert!(!json.contains("supportsKeepAlive"));
    }

    #[test]
    fn test_device_info_minimal_json_defaults() {
        let info: DeviceInfo = serde_json::from_str(r#"{"alias":"x","fingerprint":"y"}"#).unwrap();
        assert_eq!(info.alias, "x");
        assert_eq!(info.fingerprint, "y");
        assert_eq!(info.version, "2.3");
        assert_eq!(info.port, 58317);
        assert_eq!(info.protocol_, "https");
        assert!(!info.download);
        assert_eq!(info.public_key, None);
        assert_eq!(info.supports_binary, None);
        assert_eq!(info.supports_compression, None);
        assert_eq!(info.supports_keep_alive, None);
    }

    #[test]
    fn test_prepare_response_v23_fields() {
        let mut files = HashMap::new();
        files.insert("f1".to_string(), "token1".to_string());
        let resp = PrepareResponse {
            session_id: "s1".to_string(),
            files,
            public_key: None,
            max_concurrent: None,
            chunk_size: None,
            window_size: None,
            supports_compression: None,
            keep_alive: Some(true),
            streams_per_file: Some(4),
        };
        let json = serde_json::to_string(&resp).unwrap();
        assert!(json.contains("\"keepAlive\":true"));
        assert!(json.contains("\"streamsPerFile\":4"));
        let parsed: PrepareResponse = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed.keep_alive, Some(true));
        assert_eq!(parsed.streams_per_file, Some(4));
    }

    #[test]
    fn test_prepare_response_without_v23_fields() {
        let json = r#"{"sessionId":"s1","files":{"f1":"token1"}}"#;
        let parsed: PrepareResponse = serde_json::from_str(json).unwrap();
        assert_eq!(parsed.session_id, "s1");
        assert_eq!(parsed.keep_alive, None);
        assert_eq!(parsed.streams_per_file, None);
        // None fields skipped on re-serialization
        let json = serde_json::to_string(&parsed).unwrap();
        assert!(!json.contains("keepAlive"));
        assert!(!json.contains("streamsPerFile"));
    }

    #[test]
    fn test_file_metadata_roundtrip() {
        let meta = FileMetadata {
            id: "f1".to_string(),
            file_name: "photo.jpg".to_string(),
            size: 2048,
            file_type: "image/jpeg".to_string(),
            sha256: Some("hash".to_string()),
            preview: None,
            expires_in_seconds: Some(60),
        };
        let json = serde_json::to_string(&meta).unwrap();
        assert!(json.contains("\"fileName\""));
        assert!(json.contains("\"fileType\""));
        assert!(json.contains("\"expiresInSeconds\""));
        let parsed: FileMetadata = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed.file_name, "photo.jpg");
        assert_eq!(parsed.expires_in_seconds, Some(60));
    }

    #[test]
    fn test_received_file_roundtrip() {
        let file = ReceivedFile {
            id: "f1".to_string(),
            file_name: "doc.pdf".to_string(),
            size: 1000,
            file_type: "application/pdf".to_string(),
            saved_path: "/tmp/doc.pdf".to_string(),
            sender_alias: "iPhone".to_string(),
            received_at: 1720000000000,
            verified: true,
            encrypted: false,
        };
        let json = serde_json::to_string(&file).unwrap();
        assert!(json.contains("\"savedPath\""));
        assert!(json.contains("\"senderAlias\""));
        assert!(json.contains("\"receivedAt\""));
        let parsed: ReceivedFile = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed.saved_path, "/tmp/doc.pdf");
        assert!(parsed.verified);
    }

    #[test]
    fn test_room_info_roundtrip() {
        let info = RoomInfo {
            code: "ABCD".to_string(),
            host_alias: "Host".to_string(),
            host_fingerprint: "FP".to_string(),
            member_count: 2,
            file_count: 5,
        };
        let json = serde_json::to_string(&info).unwrap();
        assert!(json.contains("\"hostAlias\""));
        assert!(json.contains("\"hostFingerprint\""));
        assert!(json.contains("\"memberCount\""));
        assert!(json.contains("\"fileCount\""));
        let parsed: RoomInfo = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed.member_count, 2);
        assert_eq!(parsed.file_count, 5);
    }

    #[test]
    fn test_clipboard_payload() {
        let payload = ClipboardPayload::new("hello".to_string(), "FP".to_string(), "Mac".to_string());
        assert_eq!(payload.type_, "clipboard");
        let json = serde_json::to_string(&payload).unwrap();
        assert!(json.contains("\"type\":\"clipboard\""));
        let parsed: ClipboardPayload = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed.text, "hello");
        assert_eq!(parsed.sender, "FP");
    }

    #[test]
    fn test_file_request_message_roundtrip() {
        let msg = FileRequestMessage {
            request_id: "r1".to_string(),
            requester_alias: "Mac".to_string(),
            requester_fingerprint: "FP".to_string(),
            requester_host: "192.168.1.2".to_string(),
            requester_port: 58317,
            message: Some("please".to_string()),
            requested_types: Some(vec!["image/*".to_string()]),
        };
        let json = serde_json::to_string(&msg).unwrap();
        assert!(json.contains("\"requestId\""));
        assert!(json.contains("\"requesterAlias\""));
        assert!(json.contains("\"requesterFingerprint\""));
        assert!(json.contains("\"requesterHost\""));
        assert!(json.contains("\"requesterPort\""));
        assert!(json.contains("\"requestedTypes\""));
        let parsed: FileRequestMessage = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed.request_id, "r1");
        assert_eq!(parsed.requester_port, 58317);
    }
}
