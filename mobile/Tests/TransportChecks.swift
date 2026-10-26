import Foundation

@main struct TransportChecks {
    static func main() async throws {
        let args = CommandLine.arguments
        let pairing = Pairing(version: 1, url: args[1], token: "test-only-token", certificateSHA256: args[2])
        let client = SyncClient(pairing: pairing)
        let remote = try await client.exchange()
        precondition(remote.revision == "revision-1")
        print("PASS: exact pinned self-signed leaf authenticates a GET")
        let acknowledged = try await client.exchange(body: SyncWrite(baseRevision: remote.revision, workspace: remote.workspace))
        precondition(acknowledged.revision == "revision-2")
        print("PASS: authenticated snapshot POST returns acknowledged revision")
        do {
            _ = try await client.exchange(path: "/conflict", body: SyncWrite(baseRevision: "stale", workspace: remote.workspace))
            preconditionFailure("Expected conflict")
        } catch let conflict as SyncConflict { precondition(conflict.envelope.revision == "revision-1") }
        print("PASS: 409 is a typed conflict with remote revision")
        do {
            _ = try await client.exchange(path: "/redirect")
            preconditionFailure("Followed forbidden redirect")
        } catch NotebookError.http(let code) { precondition(code == 302) }
        print("PASS: HTTP redirects are refused")
        let wrong = SyncClient(pairing: Pairing(version: 1, url: args[1], token: "must-not-be-sent", certificateSHA256: String(repeating: "0", count: 64)))
        do { _ = try await wrong.exchange(); preconditionFailure("Wrong pin accepted") } catch { }
        print("PASS: mismatched certificate pin is rejected")
        do {
            try Pairing(version: 1, url: "http://127.0.0.1", token: "secret", certificateSHA256: args[2]).validate()
            preconditionFailure("Insecure pairing accepted")
        } catch { }
        print("PASS: insecure pairing URL is rejected")
        precondition(Pairing.isLocalHost("192.168.1.20") && Pairing.isLocalHost("amy.local") && Pairing.isLocalHost("fd00::1"))
        precondition(!Pairing.isLocalHost("8.8.8.8") && !Pairing.isLocalHost("example.com") && !Pairing.isLocalHost("172.32.1.1"))
        print("PASS: pairing is restricted to local-network addresses")
    }
}
