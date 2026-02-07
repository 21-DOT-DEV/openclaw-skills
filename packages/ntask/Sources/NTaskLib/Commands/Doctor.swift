import ArgumentParser
import Foundation

struct Doctor: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Validate environment, credentials, and notion-cli"
    )

    func run() async throws {
        var checks: [String: Any] = [:]
        var allOk = true

        // Check notion-cli presence and version
        do {
            let version = try await NotionCLI.checkVersion()
            checks["notion_cli"] = ["found": true, "version": version]
        } catch {
            checks["notion_cli"] = ["found": false]
            allOk = false
        }

        // Check NOTION_TOKEN
        let hasToken = ProcessInfo.processInfo.environment["NOTION_TOKEN"]?.isEmpty == false
        checks["env_NOTION_TOKEN"] = hasToken
        if !hasToken { allOk = false }

        // Check NOTION_TASKS_DB_ID
        let hasDbId = ProcessInfo.processInfo.environment["NOTION_TASKS_DB_ID"]?.isEmpty == false
        checks["env_NOTION_TASKS_DB_ID"] = hasDbId
        if !hasDbId { allOk = false }

        // Check database accessibility (only if token and db id are present)
        if hasToken && hasDbId {
            do {
                try await NotionCLI.checkDatabaseAccess()
                checks["db_accessible"] = true
            } catch {
                checks["db_accessible"] = false
                allOk = false
            }
        }

        if allOk {
            JSONOut.success(["checks": checks])
        } else {
            let missing = !hasToken ? "NOTION_TOKEN" :
                          !hasDbId ? "NOTION_TASKS_DB_ID" : "notion-cli or database access"
            let code = (checks["notion_cli"] as? [String: Any])?["found"] as? Bool == false
                    ? "CLI_MISSING" : "MISCONFIGURED"
            let dict: [String: Any] = [
                "ok": false,
                "error": ["code": code, "message": "Environment check failed: \(missing) not configured"],
                "checks": checks
            ]
            JSONOut.printJSON(dict)
            Darwin.exit(ExitCodes.misconfigured)
        }
    }
}
