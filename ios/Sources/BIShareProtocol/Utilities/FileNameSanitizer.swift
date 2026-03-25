import Foundation

/// File name sanitization to prevent path traversal attacks.
public enum FileNameSanitizer {

    /// Sanitize a file name by stripping path components and replacing dangerous characters.
    /// - Parameter name: The raw file name from the sender.
    /// - Returns: A safe file name, or "unnamed" if the input is empty.
    public static func sanitize(_ name: String) -> String {
        // Use only the last path component
        var sanitized = (name as NSString).lastPathComponent

        // Replace dangerous characters
        sanitized = sanitized.replacingOccurrences(of: "..", with: "_")
        sanitized = sanitized.replacingOccurrences(of: "/", with: "_")
        sanitized = sanitized.replacingOccurrences(of: ":", with: "_")
        sanitized = sanitized.replacingOccurrences(of: "\\", with: "_")

        // Reject empty
        if sanitized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "unnamed"
        }

        return sanitized
    }
}
