import Foundation
import Security
import CryptoKit
import Darwin

struct Pairing: Codable {
    let version: Int
    let url: String
    let token: String
    let certificateSHA256: String
    func validate() throws {
        guard version == 1, let u = URLComponents(string: url), u.scheme == "https", let host = u.host, Self.isLocalHost(host),
              u.user == nil, u.password == nil, u.query == nil, u.fragment == nil,
              u.path.isEmpty || u.path == "/", !token.isEmpty,
              certificateSHA256.count == 64,
              certificateSHA256.allSatisfy({ "0123456789abcdef".contains($0) }) else { throw NotebookError.invalidPairing }
    }
    static func isLocalHost(_ rawHost: String) -> Bool {
        let host = rawHost.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        if host == "localhost" || host.hasSuffix(".local") { return true }
        var v4 = in_addr()
        if inet_pton(AF_INET, host, &v4) == 1 {
            let bytes = host.split(separator: ".").compactMap { Int($0) }
            return bytes.count == 4 && (bytes[0] == 10 || bytes[0] == 127 || (bytes[0] == 172 && (16...31).contains(bytes[1])) || (bytes[0] == 192 && bytes[1] == 168) || (bytes[0] == 169 && bytes[1] == 254))
        }
        var v6 = in6_addr()
        let unscoped = String(host.split(separator: "%").first ?? "")
        if inet_pton(AF_INET6, unscoped, &v6) == 1 {
            return withUnsafeBytes(of: v6) { bytes in
                bytes.allSatisfy { $0 == 0 } == false && ((bytes[0] & 0xfe) == 0xfc || (bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80) || unscoped == "::1")
            }
        }
        return false
    }
}
enum PairingVault {
    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "Pinboard.direct-sync", kSecAttrAccount as String: "paired-mac"]
    }
    static func read() throws -> Pairing? {
        var q = query
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw NotebookError.keychain(status) }
        let pairing = try JSONDecoder().decode(Pairing.self, from: data)
        try pairing.validate()
        return pairing
    }
    static func save(_ pairing: Pairing) throws {
        try pairing.validate()
        let data = try JSONEncoder().encode(pairing)
        let attrs: [String: Any] = [kSecValueData as String: data, kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        var status = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query.merging(attrs) { _, new in new } as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw NotebookError.keychain(status) }
    }
}

struct SyncEnvelope: Codable {
    let revision: String
    let workspace: Notebook
}
struct SyncWrite: Encodable { let baseRevision: String; let workspace: Notebook }
struct SyncConflict: Error { let envelope: SyncEnvelope }

// The secret is only sent to the paired origin. Trust is the exact DER leaf hash,
// including for a self-signed local certificate. Never fall back to arbitrary trust.
final class PinnedDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate, @unchecked Sendable {
    let host: String
    let fingerprint: String
    init(pairing: Pairing) {
        host = URL(string: pairing.url)!.host!
        fingerprint = pairing.certificateSHA256
    }
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              challenge.protectionSpace.host.caseInsensitiveCompare(host) == .orderedSame,
              let trust = challenge.protectionSpace.serverTrust,
              let certificates = SecTrustCopyCertificateChain(trust) as? [SecCertificate],
              let leaf = certificates.first else {
            completionHandler(.cancelAuthenticationChallenge, nil); return
        }
        let hash = SHA256.hash(data: SecCertificateCopyData(leaf) as Data).map { String(format: "%02x", $0) }.joined()
        guard hash == fingerprint else { completionHandler(.cancelAuthenticationChallenge, nil); return }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

struct SyncClient {
    let pairing: Pairing
    func exchange(path: String = "/v1/notebook", body: SyncWrite? = nil) async throws -> SyncEnvelope {
        try pairing.validate()
        let delegate = PinnedDelegate(pairing: pairing)
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        config.urlCache = nil
        config.httpCookieStorage = nil
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        var components = URLComponents(string: pairing.url)!
        components.path = path
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer " + pairing.token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            try body.workspace.validate()
            let bytes = try JSONEncoder().encode(body)
            guard bytes.count <= 150 * 1024 * 1024 else { throw NotebookError.attachmentTooLarge }
            request.httpMethod = "POST"
            request.httpBody = bytes
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (bytes, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw NotebookError.http(0) }
        guard bytes.count <= 150 * 1024 * 1024 else { throw NotebookError.attachmentTooLarge }
        guard response.statusCode == 200 || response.statusCode == 409 else { throw NotebookError.http(response.statusCode) }
        let envelope = try JSONDecoder().decode(SyncEnvelope.self, from: bytes)
        guard !envelope.revision.isEmpty else { throw NotebookError.invalidNotebook }
        try envelope.workspace.validate()
        if response.statusCode == 409 { throw SyncConflict(envelope: envelope) }
        return envelope
    }
}
