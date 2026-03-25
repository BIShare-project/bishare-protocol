import Foundation

/// HTTP/1.1 request parser for raw TCP data.
public enum HTTPParser {

    public enum ParseResult: Sendable {
        case complete(HTTPRequest)
        case needMoreData
        case error(String)
    }

    /// Parse raw bytes into an HTTPRequest.
    /// Returns `.needMoreData` if the full request hasn't arrived yet.
    public static func parse(_ data: Data) -> ParseResult {
        guard let headerEnd = findHeaderEnd(in: data) else {
            return .needMoreData
        }

        let headerData = data[data.startIndex..<headerEnd]
        guard let headerString = String(data: headerData, encoding: .utf8) else {
            return .error("Invalid header encoding")
        }

        let lines = headerString.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            return .error("Missing request line")
        }

        let parts = requestLine.split(separator: " ", maxSplits: 2)
        guard parts.count >= 2 else {
            return .error("Invalid request line")
        }

        let method = String(parts[0])
        let fullPath = String(parts[1])

        let (path, queryItems) = parsePathAndQuery(fullPath)

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            if line.isEmpty { break }
            if let colonIndex = line.firstIndex(of: ":") {
                let key = line[line.startIndex..<colonIndex].trimmingCharacters(in: .whitespaces).lowercased()
                let value = line[line.index(after: colonIndex)...].trimmingCharacters(in: .whitespaces)
                headers[key] = value
            }
        }

        let bodyStart = headerEnd + 4 // skip \r\n\r\n
        let contentLength = headers["content-length"].flatMap(Int.init) ?? 0

        if contentLength > 0 {
            let availableBody = data.count - bodyStart
            if availableBody < contentLength {
                return .needMoreData
            }
            let body = data[bodyStart..<(bodyStart + contentLength)]
            return .complete(HTTPRequest(method: method, path: path, queryItems: queryItems, headers: headers, body: Data(body)))
        }

        return .complete(HTTPRequest(method: method, path: path, queryItems: queryItems, headers: headers, body: Data()))
    }

    private static func findHeaderEnd(in data: Data) -> Int? {
        let separator: [UInt8] = [0x0D, 0x0A, 0x0D, 0x0A] // \r\n\r\n
        guard data.count >= 4 else { return nil }
        for i in 0...(data.count - 4) {
            if data[data.startIndex + i] == separator[0] &&
               data[data.startIndex + i + 1] == separator[1] &&
               data[data.startIndex + i + 2] == separator[2] &&
               data[data.startIndex + i + 3] == separator[3] {
                return data.startIndex + i
            }
        }
        return nil
    }

    private static func parsePathAndQuery(_ fullPath: String) -> (String, [String: String]) {
        guard let questionMark = fullPath.firstIndex(of: "?") else {
            return (fullPath, [:])
        }
        let path = String(fullPath[fullPath.startIndex..<questionMark])
        let queryString = String(fullPath[fullPath.index(after: questionMark)...])
        var queryItems: [String: String] = [:]
        for pair in queryString.split(separator: "&") {
            let kv = pair.split(separator: "=", maxSplits: 1)
            if kv.count == 2 {
                let key = String(kv[0]).removingPercentEncoding ?? String(kv[0])
                let value = String(kv[1]).removingPercentEncoding ?? String(kv[1])
                queryItems[key] = value
            } else if kv.count == 1 {
                queryItems[String(kv[0])] = ""
            }
        }
        return (path, queryItems)
    }
}
