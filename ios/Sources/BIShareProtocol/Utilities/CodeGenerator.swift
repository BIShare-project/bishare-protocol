import Foundation

/// Generates random codes for rooms.
public enum CodeGenerator {

    /// Generate a random room code (4 characters).
    public static func generateRoomCode() -> String {
        generateCode(length: BIShareConfig.roomCodeLength)
    }

    /// Format a room code for display (e.g., "AB3X").
    public static func formatRoomCode(_ code: String) -> String {
        code.uppercased()
    }

    private static func generateCode(length: Int) -> String {
        let chars = Array(BIShareConfig.codeCharset)
        return String((0..<length).map { _ in chars.randomElement()! })
    }
}
