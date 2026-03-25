import XCTest
@testable import BIShareProtocol

final class HTTPParserTests: XCTestCase {

    func testParseSimpleGET() {
        let raw = "GET /api/v1/info HTTP/1.1\r\nHost: 192.168.1.1\r\n\r\n"
        let result = HTTPParser.parse(Data(raw.utf8))

        if case .complete(let req) = result {
            XCTAssertEqual(req.method, "GET")
            XCTAssertEqual(req.path, "/api/v1/info")
            XCTAssertEqual(req.headers["host"], "192.168.1.1")
            XCTAssertTrue(req.body.isEmpty)
        } else {
            XCTFail("Expected complete parse")
        }
    }

    func testParseWithQueryString() {
        let raw = "GET /api/v1/download?index=3&format=zip HTTP/1.1\r\n\r\n"
        let result = HTTPParser.parse(Data(raw.utf8))

        if case .complete(let req) = result {
            XCTAssertEqual(req.path, "/api/v1/download")
            XCTAssertEqual(req.queryItems["index"], "3")
            XCTAssertEqual(req.queryItems["format"], "zip")
        } else {
            XCTFail("Expected complete parse")
        }
    }

    func testParsePOSTWithBody() {
        let body = "{\"test\":true}"
        let raw = "POST /api/v1/prepare HTTP/1.1\r\nContent-Length: \(body.count)\r\nContent-Type: application/json\r\n\r\n\(body)"
        let result = HTTPParser.parse(Data(raw.utf8))

        if case .complete(let req) = result {
            XCTAssertEqual(req.method, "POST")
            XCTAssertEqual(req.path, "/api/v1/prepare")
            XCTAssertEqual(req.contentLength, body.count)
            XCTAssertEqual(String(data: req.body, encoding: .utf8), body)
        } else {
            XCTFail("Expected complete parse")
        }
    }

    func testParseIncompleteReturnsNeedMoreData() {
        let partial = "GET /api/v1/info HTTP/1.1\r\nHost: test"
        let result = HTTPParser.parse(Data(partial.utf8))

        if case .needMoreData = result {
            // Expected
        } else {
            XCTFail("Expected needMoreData")
        }
    }

    func testParseIncompleteBodyReturnsNeedMoreData() {
        let raw = "POST /test HTTP/1.1\r\nContent-Length: 100\r\n\r\nshort"
        let result = HTTPParser.parse(Data(raw.utf8))

        if case .needMoreData = result {
            // Expected
        } else {
            XCTFail("Expected needMoreData for incomplete body")
        }
    }

    func testResponseSerialize() {
        let response = HTTPResponse.json(["status": "ok"])
        let serialized = response.serialize()
        let str = String(data: serialized, encoding: .utf8)!
        XCTAssertTrue(str.hasPrefix("HTTP/1.1 200 OK\r\n"))
        XCTAssertTrue(str.contains("Content-Type: application/json"))
        XCTAssertTrue(str.contains("Access-Control-Allow-Origin: *"))
    }

    func testResponseError() {
        let response = HTTPResponse.error("Not found", status: 404)
        XCTAssertEqual(response.statusCode, 404)
        XCTAssertEqual(response.statusMessage, "Not Found")
    }

    func testResponseHTML() {
        let response = HTTPResponse.html("<h1>Test</h1>")
        XCTAssertEqual(response.headers["Content-Type"], "text/html; charset=utf-8")
    }
}
