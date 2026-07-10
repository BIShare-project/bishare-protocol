# BIShare Protocol

**Rust crate untuk BIShare file transfer protocol** — enkripsi, framing, dan utilities yang digunakan oleh Flutter client via FFI.

---

## Version

- **Current**: v2.3.0
- **Edition**: Rust 2024

---

## Purpose

Protocol library ini menyediakan:

1. **Crypto**: X25519 key exchange, AES-256-GCM encryption, HKDF key derivation
2. **Binary Framing**: Protocol wire format untuk transfer file
3. **Utils**: Sanitize filename, generate device ID, constants
4. **FFI Bridge**: `flutter_rust_bridge` bindings untuk Flutter

---

## Project Structure

```
bishare-protocol/
└── rust/
    ├── src/
    │   ├── lib.rs           # Library entry point
    │   ├── crypto.rs        # X25519, AES-GCM, HKDF
    │   ├── binary.rs        # Wire framing & chunking
    │   ├── models.rs        # Data structures (Device, FileMeta, etc)
    │   ├── constants.rs     # Magic bytes, limits, config
    │   └── utils.rs         # Sanitize filename, device ID
    ├── examples/
    │   └── golden.rs        # Test vectors untuk Flutter verification
    └── Cargo.toml
```

---

## Key Dependencies

| Crate | Purpose |
|-------|---------|
| `x25519-dalek` | Elliptic curve Diffie-Hellman |
| `aes-gcm` | AES-256-GCM authenticated encryption |
| `hkdf` | Key derivation from ECDH secret |
| `sha2` | SHA-256 hashing |
| `serde` + `serde_json` | Serialization |

---

## Development

```bash
cd rust

# Run tests
cargo test

# Build library
cargo build --release

# Run example (generates golden test vectors)
cargo run --example golden
```

---

## Integration with Flutter

Flutter menggunakan protocol ini via `flutter_rust_bridge`:

1. **FFI Location**: `bishare-flutter/rust_builder/` → generates `lib/src/rust/`
2. **Bridge Version**: flutter_rust_bridge 2.12.0
3. **Usage**: `RustLib.init()` di Flutter bootstrap

**Critical**: 183 test vectors di `examples/golden.rs` digate oleh CI untuk memastikan Dart↔Rust byte-exact compatibility.

---

## Protocol Specification

### Encryption Flow

```
1. Sender generates X25519 keypair
2. Receiver has public key (from /api/v1/info)
3. ECDH → shared secret
4. HKDF(shared) → encryption key (256-bit)
5. Chunk encryption: AES-256-GCM per 256KB chunk
```

### Framing (Encrypted Transfer)

```
Header: X-Encrypted: chunked

Body (repeated per chunk):
  [4 bytes: uint32 BE length]
  [12 bytes: nonce]
  [N bytes: ciphertext]
  [16 bytes: auth tag]
```

Chunk index 0 mengembed base nonce di packet itu — chunk berikutnya increment nonce.

---

## Constants & Limits

| Constant | Value | Purpose |
|----------|-------|---------|
| `MAX_CHUNK_SIZE` | 256 KB | Plaintream chunk size |
| `HASH_SIZE_LIMIT` | 64 MB | Skip SHA jika > limit |
| `PROTOCOL_VERSION` | 2.3.0 | Wire protocol version |
| `MAGIC_BIShare` | `[0xB1, 0x5H, 0x4R, 0xE0]` | Protocol identifier |

---

## Test Vectors

**Location**: `rust/examples/golden.rs`

Generate golden vectors untuk Flutter verification:

```bash
cargo run --example golden > golden.json
```

Flutter CI membaca `golden.json` dan verifies setiap encrypt/decrypt operation menghasilkan bytes yang sama persis.

---

## Notes

- **HW-AES**: Android ARMv8 perlu `--cfg aes_armv8` di rustflags (lihat bishare-flutter issue)
- **Nonce Management**: Chunk 0 embed base nonce, chunk N+1 = base + index
- **SHA-256**: Optional untuk large files (>64MB) — AES-GCM already authenticated
