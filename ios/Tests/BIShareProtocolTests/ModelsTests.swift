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

    // MARK: - v2.2 New Fields

    func testDeviceInfoSupportsCompression() throws {
        let info = DeviceInfo(alias: "Test", fingerprint: "fp", supportsCompression: true)
        let data = try JSONEncoder().encode(info)
        let decoded = try JSONDecoder().decode(DeviceInfo.self, from: data)
        XCTAssertEqual(decoded.supportsCompression, true)
    }

    func testDeviceInfoOldJsonBackwardCompat() throws {
        // Old JSON without supportsCompression should decode to nil
        let json = """
        {"alias":"Test","version":"2.0","fingerprint":"fp","port":58317,"protocol":"https","download":false}
        """
        let decoded = try JSONDecoder().decode(DeviceInfo.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.alias, "Test")
        XCTAssertNil(decoded.supportsCompression)
        XCTAssertNil(decoded.supportsBinary)
    }

    func testPrepareResponseNewFields() throws {
        let resp = PrepareResponse(
            sessionId: "s1", files: ["f1": "t1"],
            chunkSize: 262_144, windowSize: 16, supportsCompression: true
        )
        let data = try JSONEncoder().encode(resp)
        let decoded = try JSONDecoder().decode(PrepareResponse.self, from: data)
        XCTAssertEqual(decoded.chunkSize, 262_144)
        XCTAssertEqual(decoded.windowSize, 16)
        XCTAssertEqual(decoded.supportsCompression, true)
    }

    func testPrepareResponseOldJsonBackwardCompat() throws {
        let json = """
        {"sessionId":"s1","files":{"f1":"t1"}}
        """
        let decoded = try JSONDecoder().decode(PrepareResponse.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.sessionId, "s1")
        XCTAssertNil(decoded.chunkSize)
        XCTAssertNil(decoded.windowSize)
        XCTAssertNil(decoded.supportsCompression)
        XCTAssertNil(decoded.maxConcurrent)
    }

    func testBinaryFileStartNewFields() throws {
        let start = BinaryFileStart(
            fileName: "test.txt", size: 1024, fileType: "text/plain", sha256: nil,
            compression: BIShareCompression.zlib.rawValue, baseNonce: "AQIDBA==", chunkSize: 262_144
        )
        let data = try JSONEncoder().encode(start)
        let decoded = try JSONDecoder().decode(BinaryFileStart.self, from: data)
        XCTAssertEqual(decoded.compression, 0x01)
        XCTAssertEqual(decoded.baseNonce, "AQIDBA==")
        XCTAssertEqual(decoded.chunkSize, 262_144)
    }

    func testBinaryAckCoding() throws {
        let ack = BinaryAck(chunksReceived: 42, windowSize: 16)
        let data = try JSONEncoder().encode(ack)
        let decoded = try JSONDecoder().decode(BinaryAck.self, from: data)
        XCTAssertEqual(decoded.chunksReceived, 42)
        XCTAssertEqual(decoded.windowSize, 16)
    }

    func testNewMessageTypes() {
        XCTAssertEqual(BIShareMessageType(rawValue: 0x09), .ack)
        XCTAssertEqual(BIShareMessageType(rawValue: 0x0A), .pause)
        XCTAssertEqual(BIShareMessageType(rawValue: 0x0B), .resume)
    }

    func testDecoderV2ZeroCopy() {
        // Create 2 frames: a sessionEnd and a cancel
        let frame1 = BIShareBinaryEncoder.encodeSessionEnd()
        let frame2 = BIShareBinaryEncoder.encodeCancel()
        var buffer = Data()
        buffer.append(frame1)
        buffer.append(frame2)

        let (views, consumed) = BIShareBinaryDecoder.decodeAllV2(buffer)
        XCTAssertEqual(views.count, 2)
        XCTAssertEqual(consumed, buffer.count)
        XCTAssertEqual(views[0].type, .sessionEnd)
        XCTAssertEqual(views[0].payloadLength, 0)
        XCTAssertEqual(views[1].type, .cancel)
    }

    func testDecoderV2WithPayload() {
        let payload = Data("test-payload".utf8)
        let frame = BIShareBinaryEncoder.encode(BIShareFrame(type: .fileData, fileId: 42, payload: payload))
        let result = BIShareBinaryDecoder.decodeV2(frame)
        if case .success(let view, let consumed) = result {
            XCTAssertEqual(view.type, .fileData)
            XCTAssertEqual(view.fileId, 42)
            XCTAssertEqual(view.payload, payload)
            XCTAssertEqual(consumed, frame.count)
        } else {
            XCTFail("Expected success")
        }
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
