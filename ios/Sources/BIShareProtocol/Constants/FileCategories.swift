import Foundation

/// File category for organizing received files into folders.
public enum BIShareFileCategory: String, CaseIterable, Sendable {
    case images    = "Images"
    case videos    = "Videos"
    case audio     = "Audio"
    case documents = "Documents"
    case archives  = "Archives"
    case other     = "Other"

    /// Determine the category from a MIME type string.
    public static func from(mimeType: String) -> BIShareFileCategory {
        let type = mimeType.lowercased()
        if type.hasPrefix("image/") { return .images }
        if type.hasPrefix("video/") { return .videos }
        if type.hasPrefix("audio/") { return .audio }
        if type.hasPrefix("text/") || type == "application/pdf" { return .documents }
        if type.contains("zip") || type.contains("tar") || type.contains("compress") || type.contains("archive") {
            return .archives
        }
        return .other
    }
}
