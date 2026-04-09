use aes_gcm::{
    aead::{Aead, KeyInit, OsRng},
    Aes256Gcm, Nonce,
};
use hkdf::Hkdf;
use sha2::{Digest, Sha256};
use x25519_dalek::{PublicKey, StaticSecret};

use crate::constants::Crypto as CryptoConst;

/// BIShare encryption service — X25519 ECDH + HKDF-SHA256 + AES-256-GCM
pub struct Encryption {
    private_key: StaticSecret,
    public_key: PublicKey,
}

impl Encryption {
    /// Create with new random keypair
    pub fn new() -> Self {
        let private_key = StaticSecret::random_from_rng(OsRng);
        let public_key = PublicKey::from(&private_key);
        Self { private_key, public_key }
    }

    /// Create from existing private key bytes (32 bytes)
    pub fn from_private_key(bytes: &[u8; 32]) -> Self {
        let private_key = StaticSecret::from(*bytes);
        let public_key = PublicKey::from(&private_key);
        Self { private_key, public_key }
    }

    /// Get public key as base64
    pub fn public_key_base64(&self) -> String {
        base64::Engine::encode(&base64::engine::general_purpose::STANDARD, self.public_key.as_bytes())
    }

    /// Get private key bytes for persistence
    pub fn private_key_bytes(&self) -> [u8; 32] {
        self.private_key.to_bytes()
    }

    /// Compute key fingerprint: SHA256(publicKey)[0:8] as hex "AA BB CC DD..."
    pub fn fingerprint(&self) -> String {
        Self::compute_fingerprint(self.public_key.as_bytes())
    }

    /// Compute fingerprint from base64 public key
    pub fn peer_fingerprint(base64_key: &str) -> Option<String> {
        let bytes = base64::Engine::decode(&base64::engine::general_purpose::STANDARD, base64_key).ok()?;
        Some(Self::compute_fingerprint(&bytes))
    }

    fn compute_fingerprint(key_bytes: &[u8]) -> String {
        let hash = Sha256::digest(key_bytes);
        hash.iter()
            .take(CryptoConst::FINGERPRINT_BYTES)
            .map(|b| format!("{:02X}", b))
            .collect::<Vec<_>>()
            .join(" ")
    }

    /// Derive shared encryption key from peer's base64 public key
    /// Returns 32-byte AES-256 key via HKDF-SHA256
    pub fn derive_shared_key(&self, peer_public_key_base64: &str) -> Option<[u8; 32]> {
        let peer_bytes = base64::Engine::decode(&base64::engine::general_purpose::STANDARD, peer_public_key_base64).ok()?;
        if peer_bytes.len() != 32 {
            return None;
        }

        let mut peer_key_bytes = [0u8; 32];
        peer_key_bytes.copy_from_slice(&peer_bytes);
        let peer_public = PublicKey::from(peer_key_bytes);

        let shared_secret = self.private_key.diffie_hellman(&peer_public);

        // HKDF-SHA256
        let hkdf = Hkdf::<Sha256>::new(Some(CryptoConst::E2E_SALT), shared_secret.as_bytes());
        let mut key = [0u8; CryptoConst::AES_KEY_SIZE];
        hkdf.expand(CryptoConst::E2E_INFO, &mut key).ok()?;
        Some(key)
    }

    // ── AES-256-GCM (whole data) ──

    /// Encrypt data with AES-256-GCM. Returns: nonce(12) + ciphertext + tag(16)
    pub fn encrypt(data: &[u8], key: &[u8; 32]) -> Option<Vec<u8>> {
        let cipher = Aes256Gcm::new_from_slice(key).ok()?;
        let nonce_bytes = generate_random_bytes::<{ CryptoConst::GCM_NONCE_SIZE }>();
        let nonce = Nonce::from_slice(&nonce_bytes);
        let ciphertext = cipher.encrypt(nonce, data).ok()?;

        let mut result = Vec::with_capacity(CryptoConst::GCM_NONCE_SIZE + ciphertext.len());
        result.extend_from_slice(&nonce_bytes);
        result.extend_from_slice(&ciphertext);
        Some(result)
    }

    /// Decrypt data. Input: nonce(12) + ciphertext + tag(16)
    pub fn decrypt(data: &[u8], key: &[u8; 32]) -> Option<Vec<u8>> {
        if data.len() < CryptoConst::GCM_NONCE_SIZE + CryptoConst::GCM_TAG_BITS / 8 {
            return None;
        }

        let cipher = Aes256Gcm::new_from_slice(key).ok()?;
        let nonce = Nonce::from_slice(&data[..CryptoConst::GCM_NONCE_SIZE]);
        let ciphertext = &data[CryptoConst::GCM_NONCE_SIZE..];
        cipher.decrypt(nonce, ciphertext).ok()
    }

    // ── Streaming chunk encryption (v2.2) ──

    /// Generate 12 random bytes for base nonce
    pub fn generate_base_nonce() -> [u8; 12] {
        generate_random_bytes::<12>()
    }

    /// Encrypt a chunk with deterministic nonce derivation
    /// Nonce = baseNonce[0..4] + (baseNonce[4..12] XOR chunkIndex.to_be_bytes())
    pub fn encrypt_chunk(data: &[u8], key: &[u8; 32], chunk_index: u64, base_nonce: &[u8; 12]) -> Option<Vec<u8>> {
        let nonce_bytes = derive_chunk_nonce(base_nonce, chunk_index);
        let cipher = Aes256Gcm::new_from_slice(key).ok()?;
        let nonce = Nonce::from_slice(&nonce_bytes);
        let ciphertext = cipher.encrypt(nonce, data).ok()?;

        let mut result = Vec::with_capacity(CryptoConst::GCM_NONCE_SIZE + ciphertext.len());
        result.extend_from_slice(&nonce_bytes);
        result.extend_from_slice(&ciphertext);
        Some(result)
    }

    /// Decrypt a chunk with nonce verification
    pub fn decrypt_chunk(data: &[u8], key: &[u8; 32], chunk_index: u64, base_nonce: &[u8; 12]) -> Option<Vec<u8>> {
        if data.len() < CryptoConst::GCM_OVERHEAD_PER_CHUNK {
            return None;
        }

        let expected_nonce = derive_chunk_nonce(base_nonce, chunk_index);
        let actual_nonce = &data[..CryptoConst::GCM_NONCE_SIZE];

        // Verify nonce matches expected
        if actual_nonce != expected_nonce {
            return None;
        }

        let cipher = Aes256Gcm::new_from_slice(key).ok()?;
        let nonce = Nonce::from_slice(actual_nonce);
        let ciphertext = &data[CryptoConst::GCM_NONCE_SIZE..];
        cipher.decrypt(nonce, ciphertext).ok()
    }

    // ── SHA-256 ──

    /// Compute SHA-256 hash of data, return hex string
    pub fn sha256_hex(data: &[u8]) -> String {
        let hash = Sha256::digest(data);
        hex::encode(hash)
    }
}

impl Default for Encryption {
    fn default() -> Self {
        Self::new()
    }
}

/// Derive per-chunk nonce: baseNonce XOR pad(chunkIndex, 12)
/// XOR chunkIndex (8 bytes big-endian) into bytes [4..12] of base nonce
fn derive_chunk_nonce(base_nonce: &[u8; 12], chunk_index: u64) -> [u8; 12] {
    let mut nonce = *base_nonce;
    let index_bytes = chunk_index.to_be_bytes();
    for i in 0..8 {
        nonce[4 + i] ^= index_bytes[i];
    }
    nonce
}

fn generate_random_bytes<const N: usize>() -> [u8; N] {
    let mut bytes = [0u8; N];
    rand::RngCore::fill_bytes(&mut rand::rngs::OsRng, &mut bytes);
    bytes
}

// Need hex encoding for sha256
mod hex {
    pub fn encode(data: impl AsRef<[u8]>) -> String {
        data.as_ref().iter().map(|b| format!("{:02x}", b)).collect()
    }
}
