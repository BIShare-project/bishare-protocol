import XCTest
@testable import BIShareProtocol

final class UtilitiesTests: XCTestCase {

    // MARK: - FileNameSanitizer

    func testSanitizeNormalFileName() {
        XCTAssertEqual(FileNameSanitizer.sanitize("photo.jpg"), "photo.jpg")
    }

    func testSanitizePathTraversal() {
        XCTAssertFalse(FileNameSanitizer.sanitize("../../etc/passwd").contains(".."))
        XCTAssertFalse(FileNameSanitizer.sanitize("../secret.txt").contains(".."))
    }

    func testSanitizeSlashes() {
        let result = FileNameSanitizer.sanitize("path/to/file.txt")
        XCTAssertEqual(result, "file.txt") // lastPathComponent
    }

    func testSanitizeEmptyName() {
        XCTAssertEqual(FileNameSanitizer.sanitize(""), "unnamed")
        XCTAssertEqual(FileNameSanitizer.sanitize("   "), "unnamed")
    }

    func testSanitizeColons() {
        let result = FileNameSanitizer.sanitize("file:name.txt")
        XCTAssertFalse(result.contains(":"))
    }

    // MARK: - FileCategorizer

    func testCategorizerImages() {
        XCTAssertEqual(FileCategorizer.category(for: "image/jpeg"), "Images")
        XCTAssertEqual(FileCategorizer.category(for: "image/png"), "Images")
    }

    func testCategorizerDocuments() {
        XCTAssertEqual(FileCategorizer.category(for: "application/pdf"), "Documents")
        XCTAssertEqual(FileCategorizer.category(for: "text/plain"), "Documents")
    }

    func testCategorizerArchives() {
        XCTAssertEqual(FileCategorizer.category(for: "application/zip"), "Archives")
    }

    func testCategorizerOther() {
        XCTAssertEqual(FileCategorizer.category(for: "application/octet-stream"), "Other")
    }

    // MARK: - CodeGenerator

    func testRoomCodeLength() {
        let code = CodeGenerator.generateRoomCode()
        XCTAssertEqual(code.count, BIShareConfig.roomCodeLength)
    }

    func testRemoteCodeLength() {
        let code = CodeGenerator.generateRemoteCode()
        XCTAssertEqual(code.count, BIShareConfig.remoteCodeLength)
    }

    func testRemoteFullCodeLength() {
        let code = CodeGenerator.generateRemoteFullCode()
        XCTAssertEqual(code.count, BIShareConfig.remoteFullLength)
    }

    func testCodeCharsetOnly() {
        let code = CodeGenerator.generateRemoteFullCode()
        let charset = BIShareConfig.codeCharset
        for char in code {
            XCTAssertTrue(charset.contains(char), "Code contains invalid character: \(char)")
        }
    }

    func testFormatRemoteCode() {
        XCTAssertEqual(CodeGenerator.formatRemoteCode("A3X9K2"), "A3X-9K2")
    }

    // MARK: - SmartNaming

    func testSmartNaming() {
        let date = DateComponents(calendar: .current, year: 2026, month: 3, day: 24).date!
        let name = SmartNaming.format(originalName: "photo.jpg", senderAlias: "iPhone 15", date: date)
        XCTAssertEqual(name, "2026-03-24_iPhone-15_photo.jpg")
    }
}
