import XCTest
@testable import BIShareProtocol

final class ModelsTests: XCTestCase {

    func testDeviceInfoCodingRoundTrip() throws {
        let info = DeviceInfo(
            alias: "iPhone 15",
            deviceModel: "iphone",
            deviceType: "mobile",
            fingerprint: "test-uuid",
            publicKey: "base64key"
        )
        let data = try JSONEncoder().encode(info)
        let decoded = try JSONDecoder().decode(DeviceInfo.self, from: data)
        XCTAssertEqual(decoded.alias, "iPhone 15")
        XCTAssertEqual(decoded.port, Int(BISharePort.main))
        XCTAssertEqual(decoded.protocol_, "https")
        XCTAssertEqual(decoded.fingerprint, "test-uuid")
    }

    func testDeviceInfoProtocolCodingKey() throws {
        let info = DeviceInfo(alias: "Test", fingerprint: "fp")
        let data = try JSONEncoder().encode(info)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        // "protocol" in JSON, not "protocol_"
        XCTAssertNotNil(json["protocol"])
        XCTAssertNil(json["protocol_"])
    }

    func testFileMetadataCodingRoundTrip() throws {
        let meta = FileMetadata(id: "f1", fileName: "photo.jpg", size: 1024, fileType: "image/jpeg", sha256: "abc123")
        let data = try JSONEncoder().encode(meta)
        let decoded = try JSONDecoder().decode(FileMetadata.self, from: data)
        XCTAssertEqual(decoded.fileName, "photo.jpg")
        XCTAssertEqual(decoded.size, 1024)
        XCTAssertNil(decoded.expiresInSeconds)
    }

    func testPrepareRequestCodingRoundTrip() throws {
        let info = DeviceInfo(alias: "Sender", fingerprint: "fp1")
        let file = FileMetadata(id: "f1", fileName: "doc.pdf", size: 2048, fileType: "application/pdf")
        let req = PrepareRequest(info: info, files: ["f1": file])
        let data = try JSONEncoder().encode(req)
        let decoded = try JSONDecoder().decode(PrepareRequest.self, from: data)
        XCTAssertEqual(decoded.files.count, 1)
        XCTAssertEqual(decoded.files["f1"]?.fileName, "doc.pdf")
    }

    func testPrepareResponseCodingRoundTrip() throws {
        let resp = PrepareResponse(sessionId: "sess1", files: ["f1": "token1"], publicKey: "pk")
        let data = try JSONEncoder().encode(resp)
        let decoded = try JSONDecoder().decode(PrepareResponse.self, from: data)
        XCTAssertEqual(decoded.sessionId, "sess1")
        XCTAssertEqual(decoded.files["f1"], "token1")
    }

    func testClipboardPayload() throws {
        let payload = ClipboardPayload(text: "hello", senderFingerprint: "fp", alias: "iPhone")
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(ClipboardPayload.self, from: data)
        XCTAssertEqual(decoded.type, "clipboard")
        XCTAssertEqual(decoded.text, "hello")
    }

    func testReceivedFileExpiry() {
        let expired = ReceivedFile(
            id: "1", fileName: "test.txt", size: 100, fileType: "text/plain",
            savedURL: URL(fileURLWithPath: "/tmp/test.txt"), senderAlias: "Test",
            verified: true, expiresAt: Date().addingTimeInterval(-10)
        )
        XCTAssertTrue(expired.isExpired)
        XCTAssertEqual(expired.timeRemaining, "Expired")

        let active = ReceivedFile(
            id: "2", fileName: "test2.txt", size: 100, fileType: "text/plain",
            savedURL: URL(fileURLWithPath: "/tmp/test2.txt"), senderAlias: "Test",
            verified: true, expiresAt: Date().addingTimeInterval(120)
        )
        XCTAssertFalse(active.isExpired)
        XCTAssertNotNil(active.timeRemaining)

        let noExpiry = ReceivedFile(
            id: "3", fileName: "test3.txt", size: 100, fileType: "text/plain",
            savedURL: URL(fileURLWithPath: "/tmp/test3.txt"), senderAlias: "Test",
            verified: true
        )
        XCTAssertFalse(noExpiry.isExpired)
        XCTAssertNil(noExpiry.timeRemaining)
    }
}
