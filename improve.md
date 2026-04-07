# BIShare Protocol v2.2 — Speed 4x Improvement Plan

## Context

Transfer speed BIShare perlu dipercepat ~4x. Dari analisis kode v2.0, ada 6 bottleneck utama:

1. **Tidak ada chunk size constant** — app layer inkonsisten
2. **Enkripsi tidak streaming** — seluruh data di-memory sebelum encrypt
3. **Binary decoder meng-copy buffer 2x per frame** — boros alokasi
4. **maxConcurrent = 4** — terlalu konservatif untuk WiFi modern
5. **Tidak ada compression** — text/dokumen dikirim raw
6. **Tidak ada flow control** — sender bisa overwhelm receiver

---

## Strategi 6 Optimasi

| Optimasi | Estimasi Speedup | Mekanisme |
|---|---|---|
| Zero-copy decoder | 1.3-1.5x | Eliminasi 2 alokasi per frame |
| Streaming encryption | 1.2-1.4x | Encrypt per chunk, bukan per file |
| Chunk size tuning | 1.3-1.5x | Chunk 256KB + negosiasi |
| Concurrency 4→8 | 1.5-2.0x | Lebih banyak parallel transfers |
| Compression (zlib) | 1.5-3.0x (compressible) | Native di kedua platform |
| Flow control (ACK) | 1.1-1.2x | Cegah buffer bloat |

**Kombinasi: ~3.5-4.5x pada mixed workload.**

---

## File yang Dimodifikasi

### iOS (6 file)
| # | File | Perubahan |
|---|---|---|
| 1 | `ios/.../Constants/ProtocolConfig.swift` | Version bump 2.2, transfer tuning constants, compressible helper |
| 2 | `ios/.../Constants/CryptoConstants.swift` | `gcmOverheadPerChunk` |
| 3 | `ios/.../Binary/BinaryProtocol.swift` | Message types baru, zero-copy decoder, compression enum, flow control structs |
| 4 | `ios/.../Encryption/BIShareEncryption.swift` | Streaming encrypt/decrypt per chunk |
| 5 | `ios/.../Models/DeviceInfo.swift` | `supportsCompression` flag |
| 6 | `ios/.../Models/TransferTypes.swift` | `chunkSize`, `windowSize`, `supportsCompression` di PrepareResponse |

### Android (6 file)
| # | File | Perubahan |
|---|---|---|
| 1 | `android/.../constants/ProtocolConfig.kt` | Mirror iOS #1 |
| 2 | `android/.../constants/CryptoConstants.kt` | Mirror iOS #2 |
| 3 | `android/.../binary/BinaryProtocol.kt` | Mirror iOS #3 |
| 4 | `android/.../encryption/BIShareEncryption.kt` | Mirror iOS #4 |
| 5 | `android/.../models/DeviceInfo.kt` | Mirror iOS #5 |
| 6 | `android/.../models/TransferTypes.kt` | Mirror iOS #6 |

### Tests (6 file)
| # | File | Tests Baru |
|---|---|---|
| 1 | `ios/.../ConstantsTests.swift` | Transfer tuning, version, compressible MIME |
| 2 | `ios/.../EncryptionTests.swift` | Chunk encrypt/decrypt, nonce generation |
| 3 | `ios/.../ModelsTests.swift` | New fields, backward compat, decoder v2, message types |
| 4 | `android/.../ConstantsTest.kt` | Mirror iOS test #1 |
| 5 | `android/.../EncryptionTest.kt` | Mirror iOS test #2 |
| 6 | `android/.../ModelsTest.kt` | Mirror iOS test #3 |

**Total: 12 source + 6 test = 18 file. 0 file baru.**

---

## Phase 1: Foundation — Constants & Models

### 1A. ProtocolConfig — Version bump + Transfer Tuning

Version bump `"2.0"` → `"2.2"`.

```
speedProtocolMinVersion = "2.2"
defaultChunkSize        = 256 * 1024    // 256 KB
minChunkSize            = 64 * 1024     // 64 KB
maxChunkSize            = 1024 * 1024   // 1 MB
defaultMaxConcurrentV2  = 8
defaultWindowSize       = 16            // chunks in-flight
compressionMinSize      = 1024          // 1 KB minimum
```

Helper `isCompressible(mimeType:)` dengan set:
`text/*`, `application/json`, `application/xml`, `application/javascript`, `application/x-yaml`, `application/svg+xml`

### 1B. CryptoConstants

```
gcmOverheadPerChunk = 28    // nonce(12) + tag(16)
```

### 1C. DeviceInfo

```swift
public var supportsCompression: Bool?   // nil = false untuk old clients
```

### 1D. PrepareResponse (TransferTypes)

```swift
public let chunkSize: Int?              // negotiated chunk size
public let windowSize: Int?             // flow control window
public let supportsCompression: Bool?   // receiver confirms compression
```

### 1E. BinaryFileStart

```swift
public let compression: UInt8?          // 0x00 = none, 0x01 = zlib
public let baseNonce: String?           // base64 encoded 12-byte nonce
public let chunkSize: Int?              // actual chunk size untuk file ini
```

**Checkpoint:** Jalankan existing tests — harus pass 100%.

---

## Phase 2: Zero-Copy Binary Decoder

### Masalah

```swift
// iOS — 2 copy per frame decode:
let payload = Data(buffer[payloadStart..<payloadEnd])   // COPY 1
let remaining = Data(buffer[payloadEnd...])              // COPY 2
```

### Solusi: Offset-based `BIShareFrameView`

```swift
public struct BIShareFrameView: Sendable {
    public let type: BIShareMessageType
    public let fileId: UInt32
    public let buffer: Data
    public let payloadOffset: Int
    public let payloadLength: Int

    public var payload: Data {
        buffer[payloadOffset..<payloadOffset + payloadLength]  // slice, bukan copy
    }
}
```

`decodeV2` return `consumedBytes` bukan `remaining` buffer. Caller advance offset sendiri.

### Message Types Baru

```
0x09  ACK     — receiver acknowledges chunks
0x0A  PAUSE   — receiver overwhelmed (backpressure)
0x0B  RESUME  — receiver ready again
```

### Structs Baru

```swift
enum BIShareCompression: UInt8 { case none = 0x00; case zlib = 0x01 }

struct BinaryAck    { chunksReceived: UInt64, windowSize: Int }
struct BinaryPause  { fileId: UInt32 }   // 0 = pause all
struct BinaryResume { windowSize: Int }
```

---

## Phase 3: Streaming Encryption

### Masalah

`encrypt(data:using:)` menerima seluruh `Data` — file 500MB = 500MB di memory.

### Solusi: Per-chunk encrypt dengan deterministic nonce

**Nonce derivation:**
1. Generate random `baseNonce` (12 bytes) per file
2. Per chunk: `derivedNonce = baseNonce XOR pad(chunkIndex, 12)`
3. Menjamin nonce unik per chunk + per file

```swift
// iOS
static func encryptChunk(data:, using key:, chunkIndex:, baseNonce:) -> Data?
static func decryptChunk(data:, using key:, chunkIndex:, baseNonce:) -> Data?
static func generateBaseNonce() -> Data  // 12 random bytes
```

```kotlin
// Android
fun encryptChunk(data, key, chunkIndex, baseNonce): ByteArray?
fun decryptChunk(data, key, chunkIndex, baseNonce): ByteArray?
fun generateBaseNonce(): ByteArray
```

Existing `encrypt()`/`decrypt()` tetap ada untuk non-streaming use case.

---

## Phase 4: Tests

### Constants Tests
- Transfer tuning values
- Version = "2.2"
- `isCompressible()` helper

### Encryption Tests
- Chunk encrypt/decrypt roundtrip
- Different indices → different ciphertext
- Wrong index → decrypt fails (GCM auth mismatch)
- `generateBaseNonce()` length & uniqueness

### Model Tests
- DeviceInfo `supportsCompression` roundtrip
- PrepareResponse new fields roundtrip
- BinaryFileStart new fields roundtrip
- BinaryAck coding roundtrip
- New message types (0x09, 0x0A, 0x0B)
- DecoderV2 zero-copy correctness
- Old JSON backward compatibility (missing fields → nil)

---

## Phase 5: Verification

```bash
cd ios && swift test        # semua test pass
cd android && ./gradlew test # semua test pass
```

---

## Backward Compatibility

| Aspek | Jaminan |
|---|---|
| JSON fields baru | Semua optional — old client skip unknown keys |
| Message types 0x09-0x0B | Old decoder return `.error()`, tidak crash |
| API surface | Tidak ada method/struct yang dihapus atau berubah signature |
| Version negotiation | App cek `peer.version >= "2.2"` sebelum pakai fitur baru |
| Existing `decode()`/`encrypt()` | Tetap ada, tidak berubah |

---

## Urutan Implementasi

```
Phase 1  →  run existing tests  →  harus pass
Phase 2  →  tambah decoder tests  →  run
Phase 3  →  tambah encryption tests  →  run
Phase 4  →  tambah model/constant tests  →  run semua
Phase 5  →  full test suite kedua platform  →  100% pass
```
