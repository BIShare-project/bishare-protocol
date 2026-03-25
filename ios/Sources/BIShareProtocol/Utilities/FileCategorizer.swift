import Foundation

/// Maps MIME types to storage folder categories.
public enum FileCategorizer {

    /// Get the storage subfolder name for a given MIME type.
    /// - Parameter mimeType: The file's MIME type (e.g., "image/jpeg").
    /// - Returns: The folder name (e.g., "Images").
    public static func category(for mimeType: String) -> String {
        BIShareFileCategory.from(mimeType: mimeType).rawValue
    }

    /// Get the full storage path under the BIShare documents directory.
    /// - Parameters:
    ///   - mimeType: The file's MIME type.
    ///   - baseDir: The base BIShare documents directory URL.
    /// - Returns: The categorized directory URL (e.g., `.../BIShare/Images/`).
    public static func categoryDirectory(for mimeType: String, baseDir: URL) -> URL {
        baseDir.appendingPathComponent(category(for: mimeType))
    }
}
