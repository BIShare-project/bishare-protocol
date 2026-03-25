import Foundation

/// Smart file naming for received files.
public enum SmartNaming {

    private static let dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt
    }()

    /// Generate a smart file name in the format: `{date}_{sender}_{filename}`.
    /// - Parameters:
    ///   - originalName: The original file name.
    ///   - senderAlias: The sender's device alias.
    ///   - date: The date of receipt (defaults to now).
    /// - Returns: A formatted file name.
    public static func format(originalName: String, senderAlias: String, date: Date = Date()) -> String {
        let dateStr = dateFormatter.string(from: date)
        let safeSender = senderAlias
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        return "\(dateStr)_\(safeSender)_\(originalName)"
    }
}
