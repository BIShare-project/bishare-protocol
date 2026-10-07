<div align="center">

# BIShare Protocol

**The end-to-end encryption & wire protocol at the heart of [BIShare](https://bishare.app).**

A small, dependency-light **Rust** crate that implements the cryptography, binary
framing, and shared data models used to move files securely between devices —
iPhone, Android, Mac, Windows, and Linux.

![License](https://img.shields.io/badge/license-Apache%202.0-blue)
![Rust](https://img.shields.io/badge/Rust-2024_edition-000000?logo=rust&logoColor=white)
![Version](https://img.shields.io/badge/protocol-v2.4-2563eb)
![Tests](https://img.shields.io/badge/tests-75-16a34a)
[![Stars](https://img.shields.io/github/stars/BIShare-project/bishare-protocol?style=social)](https://github.com/BIShare-project/bishare-protocol/stargazers)

**[🌐 bishare.app](https://bishare.app)** &nbsp;·&nbsp; **[📱 The app](https://github.com/BIShare-project/bishare-flutter)** &nbsp;·&nbsp; **[💻 The web app](https://github.com/BIShare-project/bishare-web)**

</div>

---

## What is this?

BIShare sends files **directly device-to-device**, end-to-end encrypted, across
every platform. This crate is the **shared core** that makes that safe and
interoperable: the same Rust code runs inside the native apps (via
[`flutter_rust_bridge`](https://github.com/fzyzcjy/flutter_rust_bridge)), so a
byte encrypted on an iPhone decrypts correctly on a Windows PC.

It gives you three things:

- 🔒 **Cryptography** — X25519 key agreement, HKDF-SHA256 key derivation, and
  AES-256-GCM authenticated encryption, including per-chunk nonce derivation for
  streaming large files and content-key wrapping.
- 📦 **Binary wire framing** — a compact, versioned frame format (`Encoder` /
  `Decoder`) for the TCP/QUIC transfer streams.
- 🧩 **Shared models** — the `serde` types every BIShare client agrees on:
  devices, file metadata, rooms, clipboard payloads, signaling envelopes, …

> The crate lives in [`rust/`](rust/). Swift/Kotlin bindings were removed in
> favor of a single Rust core consumed through flutter_rust_bridge.

## Quick example

```rust
use bishare_protocol::crypto::Encryption;

// Two peers each generate an X25519 keypair.
let alice = Encryption::new();
let bob = Encryption::new();

// They exchange public keys (base64) over any channel, then INDEPENDENTLY
// derive the same 32-byte AES key (X25519 ECDH → HKDF-SHA256).
let key = alice.derive_shared_key(&bob.public_key_base64()).unwrap();

// AES-256-GCM seal / open. Blob layout: nonce(12) ‖ ciphertext ‖ tag(16).
let sealed = Encryption::encrypt(b"contents of secret.pdf", &key).unwrap();
let opened = Encryption::decrypt(&sealed, &key).unwrap();
assert_eq!(opened, b"contents of secret.pdf");
```

Build & test the crate:

```bash
cd rust
cargo build
cargo test        # 75 unit tests: crypto round-trips, framing, models
```

## Modules

| Module | Responsibility |
|---|---|
| **`crypto`** | X25519 ECDH · HKDF-SHA256 · AES-256-GCM · per-chunk nonce derivation · content-key wrapping · SHA-256 hashes · key fingerprints |
| **`binary`** | Versioned wire framing — `MessageType`, `Frame`, `Encoder`, `Decoder`, plus the v2 streaming frames |
| **`models`** | `serde` types shared across clients — `DeviceInfo`, `FileMetadata`, `RoomInfo`, `ClipboardPayload`, signaling envelopes, requests/responses |
| **`constants`** | Protocol version, default ports, chunk sizes, and per-feature version gates |
| **`utils`** | Shared helpers — room codes, filename sanitisation, and encoding utilities |

## Cryptography design

- **Key agreement:** X25519 ECDH between the two devices' ephemeral/identity keys.
- **Key derivation:** HKDF-SHA256 over the shared secret → a 32-byte AES-256 key.
- **Encryption:** AES-256-GCM (AEAD). Each sealed blob is `nonce(12) ‖ ciphertext ‖ tag(16)`.
- **Streaming:** large files are chunked; each chunk gets a deterministic nonce
  derived as `baseNonce[0..4] ‖ (baseNonce[4..12] XOR chunkIndex)`, so chunks are
  independently verifiable and never reuse a nonce.
- **Content-key wrapping:** a per-file content key can be wrapped under a
  key-encryption key (KEK = the derived shared key) into a 60-byte envelope.
- **Fingerprints:** `SHA-256(publicKey)[0..8]` rendered as hex — a short,
  human-comparable device identity for trust-on-first-use.
- **Compatibility:** public keys are accepted as raw 32 bytes or as legacy
  44-byte X.509 SPKI, normalised before use.

## Protocol facts

- **Version:** 2.4 · **Edition:** Rust 2024 · **License:** Apache 2.0
- **Default ports:** `58317` (TCP/HTTP transfer) · `58318` (UDP/QUIC endpoint)
- **Default chunk size:** 256 KiB (64 KiB–1 MiB range)

## Used by

| Repo | What it is |
|---|---|
| **[bishare-flutter](https://github.com/BIShare-project/bishare-flutter)** | The native app (iOS, Android, macOS, Windows, Linux) — links this crate via flutter_rust_bridge. |
| **[bishare-web](https://github.com/BIShare-project/bishare-web)** | The browser app + site — mirrors the AES-256-GCM scheme with WebCrypto. |

## Security

This crate builds on well-reviewed community crates — `x25519-dalek`, `aes-gcm`,
`hkdf`, and `sha2` — and is covered by 75 unit tests including encryption
round-trips. It has **not** had a formal external audit. If you find a
vulnerability, please email **security@billiongroup.net** rather than opening a
public issue.

## License

Licensed under the [Apache License 2.0](LICENSE): free to use, modify and distribute. Keep the [NOTICE](NOTICE) file with any copy; the BIShare name and logo are not covered by the license (see [TRADEMARKS.md](TRADEMARKS.md)). Releases before 7 October 2026 were MIT-licensed.

---

<div align="center">

**If this is useful to you, please ⭐ star the repo.**

**[Website](https://bishare.app)** · **[The app](https://github.com/BIShare-project/bishare-flutter)** · **[The web app](https://github.com/BIShare-project/bishare-web)**

</div>
