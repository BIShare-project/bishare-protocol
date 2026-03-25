import Foundation

/// Generates random codes for rooms and remote transfers.
public enum CodeGenerator {

    /// Generate a random room code (4 characters).
    public static func generateRoomCode() -> String {
        generateCode(length: BIShareConfig.roomCodeLength)
    }

    /// Generate a random remote transfer code (6 characters).
    public static func generateRemoteCode() -> String {
        generateCode(length: BIShareConfig.remoteCodeLength)
    }

    /// Generate a full remote share code (16 characters) used as encryption key material.
    public static func generateRemoteFullCode() -> String {
        generateCode(length: BIShareConfig.remoteFullLength)
    }

    /// Format a room code for display (e.g., "AB3X").
    public static func formatRoomCode(_ code: String) -> String {
        code.uppercased()
    }

    /// Format a remote code for display with dash (e.g., "A3X-9K2").
    public static func formatRemoteCode(_ code: String) -> String {
        let upper = code.uppercased()
        if upper.count == 6 {
            let mid = upper.index(upper.startIndex, offsetBy: 3)
            return "\(upper[upper.startIndex..<mid])-\(upper[mid...])"
        }
        return upper
    }

    private static func generateCode(length: Int) -> String {
        let chars = Array(BIShareConfig.codeCharset)
        return String((0..<length).map { _ in chars.randomElement()! })
    }
}
