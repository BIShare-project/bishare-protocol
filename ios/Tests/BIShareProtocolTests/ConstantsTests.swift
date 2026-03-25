import XCTest
@testable import BIShareProtocol

final class ConstantsTests: XCTestCase {

    func testPortsAreInDynamicRange() {
        // Dynamic/private port range: 49152–65535
        XCTAssertGreaterThanOrEqual(BISharePort.main, 49152)
        XCTAssertGreaterThanOrEqual(BISharePort.quic, 49152)
        XCTAssertGreaterThanOrEqual(BISharePort.room, 49152)
        XCTAssertGreaterThanOrEqual(BISharePort.webdav, 49152)
        XCTAssertLessThanOrEqual(BISharePort.main, 65535)
    }

    func testPortsAreSequential() {
        XCTAssertEqual(BISharePort.quic, BISharePort.main + 1)
        XCTAssertEqual(BISharePort.room, BISharePort.main + 2)
        XCTAssertEqual(BISharePort.webdav, BISharePort.main + 3)
    }

    func testPortsNotLocalSend() {
        // Must NOT be the same as LocalSend ports
        XCTAssertNotEqual(BISharePort.main, 53317)
        XCTAssertNotEqual(BISharePort.quic, 53318)
        XCTAssertNotEqual(BISharePort.room, 53319)
        XCTAssertNotEqual(BISharePort.webdav, 53320)
    }

    func testServiceTypes() {
        XCTAssertEqual(BIShareService.discovery, "_bishare._tcp")
        XCTAssertEqual(BIShareService.room, "_bishare-room._tcp")
        XCTAssertEqual(BIShareService.nearby, "bishare-nearby")
        XCTAssertEqual(BIShareService.quicALPN, ["bishare-quic"])
    }

    func testAPIPaths() {
        XCTAssertTrue(BIShareAPI.info.hasPrefix("/api/v1/"))
        XCTAssertTrue(BIShareAPI.prepare.hasPrefix("/api/v1/"))
        XCTAssertTrue(BIShareAPI.roomInfo.hasPrefix("/api/v1/room/"))
    }

    func testCryptoConstants() {
        XCTAssertEqual(BIShareCrypto.aesKeySize, 32)
        XCTAssertEqual(BIShareCrypto.gcmNonceSize, 12)
        XCTAssertEqual(BIShareCrypto.gcmTagBits, 128)
        XCTAssertEqual(BIShareCrypto.fingerprintBytes, 8)
    }

    func testCodeCharset() {
        let charset = BIShareConfig.codeCharset
        // Must not contain ambiguous characters
        XCTAssertFalse(charset.contains("I"))
        XCTAssertFalse(charset.contains("O"))
        XCTAssertFalse(charset.contains("0"))
        XCTAssertFalse(charset.contains("1"))
    }

    func testFileCategories() {
        XCTAssertEqual(BIShareFileCategory.from(mimeType: "image/jpeg"), .images)
        XCTAssertEqual(BIShareFileCategory.from(mimeType: "video/mp4"), .videos)
        XCTAssertEqual(BIShareFileCategory.from(mimeType: "audio/mpeg"), .audio)
        XCTAssertEqual(BIShareFileCategory.from(mimeType: "application/pdf"), .documents)
        XCTAssertEqual(BIShareFileCategory.from(mimeType: "text/plain"), .documents)
        XCTAssertEqual(BIShareFileCategory.from(mimeType: "application/zip"), .archives)
        XCTAssertEqual(BIShareFileCategory.from(mimeType: "application/octet-stream"), .other)
    }
}
