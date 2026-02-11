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

        // Check Notion auth: env var first, then keychain
        var hasAuth = false
        let envToken = ProcessInfo.processInfo.environment["NOTION_TOKEN"]?.isEmpty == false
        if envToken {
            checks["notion_token"] = ["available": true, "source": "environment"]
            hasAuth = true
        } else if let tokenSource = await NotionCLI.checkAuthStatus() {
            checks["notion_token"] = ["available": true, "source": tokenSource]
            hasAuth = true
        } else {
            checks["notion_token"] = ["available": false]
            allOk = false
        }

        // Check NOTION_TASKS_DB_ID
        let hasDbId = ProcessInfo.processInfo.environment["NOTION_TASKS_DB_ID"]?.isEmpty == false
        checks["env_NOTION_TASKS_DB_ID"] = hasDbId
        if !hasDbId { allOk = false }

        // Check NOTION_AGENT_USER_ID
        let hasAgentUserId = ProcessInfo.processInfo.environment["NOTION_AGENT_USER_ID"]?.isEmpty == false
        checks["env_NOTION_AGENT_USER_ID"] = hasAgentUserId
        if !hasAgentUserId { allOk = false }

        // Check database accessibility (only if auth and db id are present)
        if hasAuth && hasDbId {
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
            let missing = !hasAuth ? "Notion credentials (run `notion auth login` or set NOTION_TOKEN)" :
                          !hasDbId ? "NOTION_TASKS_DB_ID" :
                          !hasAgentUserId ? "NOTION_AGENT_USER_ID" : "notion-cli or database access"
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
