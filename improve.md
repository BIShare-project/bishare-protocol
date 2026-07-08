# BIShare Protocol v2.3 — Correctness + Real-World Speed Plan

> Menggantikan plan v2.2 (speed 4x — sudah selesai diimplementasi, lihat git history).
> Dasar: audit kode + benchmark Apple M4 + riset terverifikasi (2026-07-05).

## Context

### Temuan audit (2026-07-05)

1. **🔴 BUG — Android key encoding**: `BIShareEncryption.kt` memakai X.509 SPKI (44 byte: 12 byte DER prefix + 32 raw) untuk wire format public key, sementara iOS (`rawRepresentation`) dan Rust memakai raw 32 byte. `deriveSharedKey` gagal dua arah antara Android ↔ iOS/Rust → **transfer lintas platform diam-diam jalan TANPA E2E encryption** (fallback). Sesama platform tidak terpengaruh, jadi tidak terlihat.
2. **🟠 PERF BUG — Rust software AES**: `cargo build --release` biasa = software AES ~224 MB/s karena crate `aes` 0.8.x menyembunyikan intrinsik ARMv8 di balik `--cfg aes_armv8`. Dengan flag: ~2.566 MB/s (**11x**). Berdampak ke desktop Tauri.
3. **🟡 Gap test Rust**: hanya utils (14 test) vs iOS 59 / Android 50. Tidak ada shared test vectors lintas platform — bug #1 tidak pernah tertangkap karena tiap platform hanya roundtrip dengan dirinya sendiri.
4. **Transport**: semua transfer lewat router (infrastructure mode — airtime terbagi 2); koneksi TCP baru + `Connection: close` per file (iOS); E2E iOS membangun seluruh file terenkripsi di RAM saat kirim dan membaca-ulang seluruh file saat terima; QUIC iOS praktis tak pernah terpilih (`latencyMs == 0` → TCP); QUIC Android dormant.

### Riset terverifikasi (benchmark M4 + web research + adversarial fact-check)

| Fakta | Angka |
|---|---|
| AirDrop = HTTPS/TCP di atas AWDL (P2P WiFi, tanpa router) | riil 12–49 MB/s, puncak ~65, kapasitas radio ~95 |
| SHAREit = HTTP polos di atas hotspot soft-AP | tipikal ~20 MB/s, sering 2–8 |
| WiFi LAN infra (jalur BIShare) | WiFi 5/6: 25–90+; 6E ~140; WiFi 7: 300–500 MB/s |
| Crypto AES-GCM hardware (semua platform) | 2,5–9 GB/s — **bukan bottleneck** (headroom 40–150x) |
| Kernel TCP vs userspace QUIC utk bulk di LAN | TCP menang (Syncthing: 550 vs 300 Mbit/s di WiFi sama) |
| Wi-Fi Aware iOS 26 (iPhone 12+, entitlement) | P2P tanpa router kelas AirDrop; **iPhone↔Android interop masih broken** (Aware 4.0 pairing: DCEA missing, PASN status 15; hanya Galaxy S25 yang support) |

**Kesimpulan strategi: kecepatan datang dari (a) perbaikan data flow di app dan (b) link layer langsung tanpa router — bukan dari ganti wire protocol atau bahasa.**

---

## Fase 0 — Correctness: Key Encoding + Hardware AES + Test Parity ✅ DIIMPLEMENTASI

### 0A. Wire format public key = raw 32 byte (standar), terima keduanya saat parse

| Platform | Perubahan |
|---|---|
| Android `encryption/BIShareEncryption.kt` | `publicKeyBase64` → base64(raw 32B); `deriveSharedKey`/`peerFingerprint` terima raw 32 ATAU legacy X.509 44 (strip prefix `302a300506032b656e032100`); fingerprint selalu atas raw; `android.util.Base64` → `java.util.Base64` (testable di JVM) |
| iOS `Encryption/BIShareEncryption.swift` | `deriveSharedKey`/`peerFingerprint` terima legacy 44-byte X.509 (normalize → raw) |
| Rust `src/crypto.rs` | `derive_shared_key`/`peer_fingerprint` idem (`normalize_raw_key`) |

Persistence key di Android (PKCS8/X.509 via JCA) **tidak berubah** — hanya wire format.

### 0B. Hardware AES untuk Rust (desktop)

- `rust/.cargo/config.toml` + `bishare-desktop/src-tauri/.cargo/config.toml`:
  ```toml
  [target.'cfg(target_arch = "aarch64")']
  rustflags = ["--cfg", "aes_armv8", "--cfg", "polyval_armv8"]
  ```
- Jangka panjang: upgrade `aes-gcm` ke 0.11+ (autodetect) saat stabil.

### 0C. Shared test vectors lintas platform (di-generate dari implementasi Rust, di-embed ke 3 test suite)

```
key       = 000102…1f (32B ascending)     baseNonce = 000102…0b (12B ascending)
plaintext = "BIShare cross-platform test vector"
encryptChunk(idx=1) = 000102030405060708090a0a e4919a28…97f427  (nonce‖ct‖tag, deterministic)
privA = 0x11×32 → pubA e06Qm75//kTEZaIgA31gjuNYl9Me+XLwf3SJLLD3PxM=
privB = 0x22×32 → pubB D6poTtKIZ7l/Smot7l34zpdOdrcBjj8iocTPJnhXDyA=
sharedKey(A,B) = 9ffee322ad64e3bf95f3dc3e6c979113af57b356ed7b7fb9cb6bfe4a55eba48c
fingerprintA   = "D1 9B F3 F0 82 78 2C 87"
pubA(X.509)    = MCowBQYDK2VuAyEAe06Qm75//kTEZaIgA31gjuNYl9Me+XLwf3SJLLD3PxM=
```

Test wajib per platform: chunk vector exact-match, shared key exact-match dua arah, X.509 acceptance, fingerprint vector, **vector negatif** (44B prefix salah, panjang salah, all-zero/low-order key → tolak). Rust juga dapat test parity penuh (crypto/binary/models/constants — mirror suite iOS/Android).

### 0D. Low-order X25519 point rejection (temuan review adversarial)

iOS CryptoKit dan Android JCA fail-closed pada low-order/all-zero point; Rust (x25519-dalek) tidak — shared secret all-zero menghasilkan key yang bisa dihitung siapa pun. Fix: gate `shared_secret.was_contributory()` di `derive_shared_key` + vector negatif di 3 suite.

### 0E. Desktop pickup checklist (crate dikonsumsi via git dependency)

1. Commit + push repo `bishare-protocol` (termasuk `rust/.cargo/config.toml`).
2. Di `bishare-desktop/src-tauri`: sudah ada `[patch]` ke path lokal (build lokal langsung pakai v2.3); setelah push, jalankan `cargo update -p bishare-protocol` — `[patch]` boleh dihapus atau dipertahankan untuk dev lokal.
3. Catatan: `.cargo/config.toml` di dalam dependency TIDAK berlaku untuk consumer — karena itu ada copy di `bishare-desktop/src-tauri/.cargo/config.toml`.
4. Struct literal `DeviceInfo`/`PrepareResponse` di desktop sudah diperbarui dengan field v2.3 (state.rs, transfer_server.rs).

### Kompatibilitas Fase 0

| Pasangan | Sebelum | Sesudah |
|---|---|---|
| Android(baru) ↔ iOS/Rust | ❌ unencrypted fallback | ✅ E2E jalan |
| Android(baru) ↔ Android(lama) | ✅ E2E (X.509) | ⚠️ kirim-ke-lama: fallback unencrypted (lama tak paham raw); terima-dari-lama: ✅ (accept both) — sementara, hilang setelah kedua sisi update |
| Fingerprint device Android | hash(X.509 44B) | hash(raw 32B) → **berubah sekali** — peer lama akan lihat Android sebagai device "baru" (re-trust sekali) |

---

## Fase 1 — Foundation v2.3 ✅ DIIMPLEMENTASI

Version bump `"2.2"` → `"2.3"` (semua platform). Konstanta & field baru (semua optional — old client skip):

```
P2P_PROTOCOL_MIN_VERSION = "2.3"     // gate fitur v2.3
DEFAULT_STREAMS_PER_FILE = 4          // parallel TCP streams per file besar
ServiceType.AWARE     = "_bishare-aware._tcp"   // Wi-Fi Aware (iOS 26 WiFiAwareServices)
ServiceType.AWARE_NAN = "bishare-aware"          // Android WifiAwareManager service name
DeviceInfo.supportsKeepAlive: Bool?              // capability flag
PrepareResponse.keepAlive: Bool?                 // receiver konfirmasi connection reuse
PrepareResponse.streamsPerFile: Int?             // negosiasi streams per file
```

---

## Fase 2 — Client Speed Quick Wins (app-level) → target: line rate WiFi (40–110+ MB/s di WiFi 6)

**Ini fase dengan dampak terbesar.** Semua perubahan di app client, protokol sudah siap dari Fase 1.

### 2A. Connection reuse (iOS prioritas)
- `bishare-ios TransferClient.swift:602-621` — hapus `Connection: close` + koneksi-baru-per-file; pool `NWConnection` per peer (reuse antar file dalam satu sesi).
- Gate: `peer.version >= "2.3"` atau `PrepareResponse.keepAlive == true`.
- Server side (`TransferServer.swift`): dukung multiple request per koneksi (parser HTTP sudah per-request).

### 2B. Streaming E2E send — iOS
- `TransferClient.swift:337-359` — encrypt per chunk lalu **langsung tulis ke socket** (length-prefix + chunk), hapus akumulasi `encryptedChunks` full-file di RAM. File 2GB: RAM turun dari ~2GB → ~512KB.

### 2C. Streaming E2E receive — iOS
- `TransferServer.swift:784-822` — decrypt on-the-fly di `streamBodyToDisk` (baca length-prefix → decryptChunk → tulis plaintext), hapus pass kedua baca-ulang seluruh file dari disk.

### 2D. Parallel streams per file besar (butuh dukungan server kecil)
- File ≥ 32 MB dibagi `streamsPerFile` segmen; tiap segmen di-upload paralel dengan header `x-bishare-segment: <index>/<total>` + `x-bishare-offset: <byte>`; server pre-allocate file, tulis pada offset (`FileHandle.seek` / `RandomAccessFile` / `pwrite`).
- Gate: `PrepareResponse.streamsPerFile != nil`. Chunk index enkripsi tetap global per file (offset/chunkSize) — nonce derivation tidak berubah.

### 2E. Android paritas
- `TransferClient.kt:177` — hapus whole-file `doFinal` untuk file <50MB (selalu chunked streaming, konsisten dgn path >50MB).
- Connection reuse: OkHttp sudah pooling — pastikan tidak ada `Connection: close` di server NanoHTTPD response.

### 2F. Desktop paritas
- `transfer_client.rs:369` — ganti `encrypt_file_chunked` full-Vec dengan stream wrapper (encrypt per chunk dalam `ReaderStream` map).
- reqwest sudah keep-alive default.

### 2G. Perapian kecil
- iOS: hapus `Task` per chunk untuk progress (`TransferClient.swift:712`) — batch per 1–4 MB.
- iOS: isi `latencyMs` di TXT-record fast path atau perbaiki gate QUIC (saat ini QUIC mati de facto — tidak masalah, TCP memang lebih cepat untuk bulk di LAN; jadikan QUIC eksplisit opt-in saja).

**Checkpoint Fase 2:** benchmark transfer 1GB iOS↔Android di WiFi 6 — target ≥ 40 MB/s terenkripsi (≥ AirDrop tipikal, >> SHAREit).

### ✅ Status Fase 2 (diimplementasi 2026-07-05)

2A (connection reuse + keep-alive), 2B (streaming E2E send), 2C (inline streaming decrypt receive), 2E (Android chunked <50MB + inline decrypt), 2F (desktop streaming encrypt+decrypt), 2G (iOS progress batching) — **DONE**. Semua build/test hijau (iOS Mac Catalyst BUILD SUCCEEDED, Android BUILD SUCCESSFUL, desktop cargo check+test exit 0). Wire format v2.2 dipertahankan (frame `[4-byte BE len][nonce12+ct+tag16]`, chunk 256KB, X-Encrypted: chunked) → backward compatible.

**2D (parallel streams per file) — BELUM**, di-defer (butuh dukungan server offset-write; dampak setelah 2A-2C sudah besar).

### Perbaikan pasca-review adversarial (17-agent, 14 temuan terkonfirmasi → di-fix)

- **🔴 CRITICAL (iOS):** keep-alive dikirim di jalur error `handleUpload` SEBELUM body dikuras → body upload (bisa GB) diparse sebagai "request berikutnya", buffer RAM tak terbatas. Fix: semua jalur error awal + mid-body kembali menutup koneksi; keep-alive HANYA di respons sukses `finishUpload` (body sudah terkuras).
- **iOS RAM DoS (#4):** `streamEncryptedBodyToDisk` percaya length-prefix 4-byte tanpa batas → frame korup/jahat bikin `pending` membengkak. Fix: tolak `chunkLen > maxChunkSize + gcmOverhead`. Idem desktop (`transfer_server.rs`).
- **iOS pool stale (#2):** retry mengambil ulang koneksi pool yang bisa dead-but-`.ready` → 3 attempt habis. Fix: `allowPool: attempt == 0` — retry selalu koneksi fresh.
- **iOS idle timeout (#3):** koneksi keep-alive tanpa timeout → slot habis bila client hilang tanpa FIN. Fix: generation-counter idle timeout 20s (aktif hanya saat idle antar-request, tidak membunuh upload aktif).
- **Android readBody (#6):** `read()` tunggal tanpa loop → body prepare besar (40+ file) terpotong + desync keep-alive. Fix: fill loop.
- **Desktop progress (#10):** menghitung wire bytes vs total plaintext → overshoot >100%. Fix: laporkan byte plaintext (`frame - 32`).

### Known limitations (dari review, di-defer dengan sengaja)

- **Android E2E receive DORMANT** (#5/#12): `TransferServer` Android tidak pernah mengembalikan `publicKey` di PrepareResponse dan tidak pernah mengeset `TransferSession.encryptionKey` → jalur decrypt receive (lama & baru) mati. **Konsekuensi nyata: transfer iOS/desktop → Android tidak pernah terenkripsi** (sender tidak dapat key). Kode inline-decrypt sudah benar, aktif otomatis begitu key exchange di-wire. **TODO Fase 2.5:** wire publicKey + encryptionKey di server Android (mirror iOS `handlePrepare` line ~504/547).
- **#7 (Android cancel/500 tinggalkan body):** minor NanoHTTPD keep-alive desync saat cancel mid-body; di-defer (Android E2E dormant, dampak rendah).
- **#11 (desktop progress resurrect):** race minor — task `add_bytes` detached bisa mengisi ulang progress setelah `finish()`; kosmetik, di-defer.
- **#8 (desktop [patch]):** repo `bishare-protocol` belum di-push (v2.3 masih uncommitted). `[patch]` lokal aktif → build sekarang OK. Setelah push: `cargo update -p bishare-protocol`, `[patch]` boleh dilepas.

---

## Fase 3 — Wi-Fi Aware Fast Path (tanpa router, kelas AirDrop)

### 3A. iOS ↔ iOS (iOS 26+, iPhone 12+)
- Entitlement `com.apple.developer.wifi-aware`; Info.plist `WiFiAwareServices` = `_bishare-aware._tcp`.
- Pairing sekali via `DeviceDiscoveryUI`; koneksi via Network.framework (`NetworkListener`/`NetworkBrowser`), **bulk performance mode**.
- Slot masuk di seam yang sudah ada: `TransferClient.selectTransport()`/`createConnection()` — tambah path provider Aware; fallback otomatis ke LAN bila gagal/tidak paired.
- Ganti bertahap tab "Nearby" dari MultipeerConnectivity (deprecated de facto per Apple DTS) ke Wi-Fi Aware.

### 3B. Android ↔ Android (Android 8+, hardware-dependent)
- `WifiAwareManager` publish/subscribe service `bishare-aware` (cek `FEATURE_WIFI_AWARE` + `isAvailable()`); NDP → network socket; permission `NEARBY_WIFI_DEVICES` (API 33+).
- Android belum punya abstraksi transport — buat `TransportProvider` interface dulu di sekitar URL-building `TransferClient.kt`.

### 3C. iPhone ↔ Android
- Pakai nama service SAMA di kedua platform → interop **menyala otomatis** saat Aware 4.0 pairing lintas vendor matang (per riset Jul 2026: masih gagal — DCEA attribute missing, PASN PIN status 15; hanya Galaxy S25 yg `isAwarePairingSupported`). Pantau tiap rilis iOS 26.x/Android.

---

## Fase 4 — Hotspot Fallback (iPhone ↔ Android tanpa router, use case SHAREit)

- Android: `LocalOnlyHotspot` (API 26+) → SSID/pass auto-generated.
- Kredensial dikirim via QR code (+ BLE advertisement opsional).
- iOS join programatik: `NEHotspotConfiguration` (entitlement Hotspot Configuration; prompt consent user).
- Setelah tersambung: discovery & transfer memakai stack LAN yang sudah ada (mDNS + HTTP) — **tidak perlu protokol baru**.
- Ekspektasi riil 10–40 MB/s; keunggulan vs SHAREit: tetap E2E encrypted.

---

## Fase 5 — Verification

1. Test suite 3 platform: `cargo test`, `swift test`, `./gradlew :bishare-protocol-android:testDebugUnitTest` — 100% pass.
2. **Matrix E2E lintas platform (manual, satu kali per rilis)**: iOS↔Android, iOS↔Desktop, Android↔Desktop — verifikasi transfer *benar-benar terenkripsi* (log "E2E: Derived shared key", BUKAN fallback). Ini yang selama ini tidak pernah dites dan menyembunyikan bug #1.
3. Benchmark before/after per fase (file 1 GB, WiFi 6):

| Milestone | Target |
|---|---|
| Baseline hari ini (lewat router, E2E) | ukur dulu |
| Setelah Fase 2 | ≥ 40 MB/s (line-rate-bound) |
| Setelah Fase 3 (Aware, tanpa router) | ≥ 25–85 MB/s (kelas AirDrop) |
| SHAREit sebagai pembanding | ~20 MB/s → terlewati ✓ |

---

## Urutan Implementasi

```
Fase 0 + 1 (protocol lib, 3 platform)   ✅ selesai — semua test pass
Fase 2A-2C (iOS reuse + streaming E2E)  ← berikutnya, dampak terbesar
Fase 2E-2F (Android/desktop paritas)
Fase 2D (parallel streams per file)
Fase 5.2 (matrix E2E manual)            ← gate rilis v2.3
Fase 3A/3B (Wi-Fi Aware same-platform)
Fase 4 (hotspot fallback)
Fase 3C (Aware lintas platform)         ← menunggu ekosistem
```

## Jaminan Backward Compatibility

| Aspek | Jaminan |
|---|---|
| Field JSON baru | Semua optional — old client skip unknown keys |
| Wire format key raw | iOS/Rust/Android-baru parse keduanya; hanya Android-lama yg tak paham raw (fallback unencrypted sementara — status quo hari ini) |
| API surface | Tidak ada method/struct dihapus atau ganti signature |
| Version negotiation | Fitur v2.3 di-gate `peer.version >= "2.3"` / capability flags |
| `encrypt()`/`decrypt()`/`decode()` lama | Tetap ada, tidak berubah |
