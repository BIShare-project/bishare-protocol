import Foundation

/// HTTP/1.1 response builder with serialization.
public struct HTTPResponse: Sendable {
    public let statusCode: Int
    public let headers: [String: String]
    public let body: Data

    public init(statusCode: Int, headers: [String: String] = [:], body: Data = Data()) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
    }

    public var statusMessage: String {
        switch statusCode {
        case 200: return "OK"
        case 201: return "Created"
        case 204: return "No Content"
        case 207: return "Multi-Status"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 403: return "Forbidden"
        case 404: return "Not Found"
        case 405: return "Method Not Allowed"
        case 409: return "Conflict"
        case 412: return "Precondition Failed"
        case 415: return "Unsupported Media Type"
        case 500: return "Internal Server Error"
        default: return "Unknown"
        }
    }

    /// Serialize to raw HTTP/1.1 response bytes.
    public func serialize() -> Data {
        var result = "HTTP/1.1 \(statusCode) \(statusMessage)\r\n"
        var allHeaders = headers
        allHeaders["Content-Length"] = "\(body.count)"
        if allHeaders["Content-Type"] == nil {
            allHeaders["Content-Type"] = "application/json"
        }
        if allHeaders["Connection"] == nil {
            allHeaders["Connection"] = "close"
        }
        allHeaders["Access-Control-Allow-Origin"] = "*"
        for (key, value) in allHeaders {
            result += "\(key): \(value)\r\n"
        }
        result += "\r\n"
        var data = Data(result.utf8)
        data.append(body)
        return data
    }

    // MARK: - Convenience Initializers

    /// JSON response with automatic encoding.
    public static func json<T: Encodable>(_ value: T, status: Int = 200) -> HTTPResponse {
        let encoder = JSONEncoder()
        let body = (try? encoder.encode(value)) ?? Data()
        return HTTPResponse(statusCode: status, headers: ["Content-Type": "application/json"], body: body)
    }

    /// Error response with JSON body.
    public static func error(_ message: String, status: Int) -> HTTPResponse {
        return json(ErrorResponse(message: message), status: status)
    }

    /// Simple 200 OK response.
    public static func ok() -> HTTPResponse {
        return json(["message": "ok"])
    }

    /// XML response (e.g., for WebDAV PROPFIND).
    public static func xml(_ content: String, status: Int = 207) -> HTTPResponse {
        return HTTPResponse(statusCode: status, headers: ["Content-Type": "application/xml; charset=utf-8"], body: Data(content.utf8))
    }

    /// Empty response with optional headers.
    public static func empty(status: Int = 204, headers: [String: String] = [:]) -> HTTPResponse {
        return HTTPResponse(statusCode: status, headers: headers, body: Data())
    }

    /// HTML response.
    public static func html(_ content: String, status: Int = 200) -> HTTPResponse {
        return HTTPResponse(statusCode: status, headers: ["Content-Type": "text/html; charset=utf-8"], body: Data(content.utf8))
    }
}
