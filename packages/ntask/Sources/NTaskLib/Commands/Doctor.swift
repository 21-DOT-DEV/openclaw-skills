import ArgumentParser
import Foundation

struct Doctor: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Validate environment, credentials, and ntn CLI"
    )

    func run() async throws {
        var allOk = true

        // Check ntn CLI presence and version
        var cliCheck: NotionCliCheck
        do {
            let version = try await NotionCLI.checkVersion()
            cliCheck = NotionCliCheck(found: true, version: version)
        } catch {
            cliCheck = NotionCliCheck(found: false, version: nil)
            allOk = false
        }

        // Check Notion auth: env var first, then keychain
        var hasAuth = false
        var tokenCheck: NotionTokenCheck
        let envToken = ProcessInfo.processInfo.environment["NOTION_TOKEN"]?.isEmpty == false
        if envToken {
            tokenCheck = NotionTokenCheck(available: true, source: "environment")
            hasAuth = true
        } else if let tokenSource = await NotionCLI.checkAuthStatus() {
            tokenCheck = NotionTokenCheck(available: true, source: tokenSource)
            hasAuth = true
        } else {
            tokenCheck = NotionTokenCheck(available: false, source: nil)
            allOk = false
        }

        // Check NOTION_TASKS_DB_ID
        let hasDbId = ProcessInfo.processInfo.environment["NOTION_TASKS_DB_ID"]?.isEmpty == false
        if !hasDbId { allOk = false }

        // Check NOTION_AGENT_USER_ID
        let hasAgentUserId = ProcessInfo.processInfo.environment["NOTION_AGENT_USER_ID"]?.isEmpty == false
        if !hasAgentUserId { allOk = false }

        // Check database accessibility (only if auth and db id are present)
        var dbAccessible: Bool? = nil
        if hasAuth && hasDbId {
            do {
                try await NotionCLI.checkDatabaseAccess()
                dbAccessible = true
            } catch {
                dbAccessible = false
                allOk = false
            }
        }

        let checks = DoctorChecks(
            notionCli: cliCheck,
            notionToken: tokenCheck,
            envNotionTasksDbId: hasDbId,
            envNotionAgentUserId: hasAgentUserId,
            dbAccessible: dbAccessible
        )

        if allOk {
            JSONOut.printEncodable(NTaskSuccessResponse<TaskSummary>(checks: checks))
        } else {
            let missing = !hasAuth ? "Notion credentials (run `ntn auth login` or set NOTION_TOKEN)" :
                          !hasDbId ? "NOTION_TASKS_DB_ID" :
                          !hasAgentUserId ? "NOTION_AGENT_USER_ID" : "ntn CLI or database access"
            let code = !cliCheck.found ? "CLI_MISSING" : "MISCONFIGURED"
            JSONOut.printEncodable(DoctorErrorResponse(
                error: NTaskErrorPayload(code: code, message: "Environment check failed: \(missing) not configured"),
                checks: checks
            ))
            Darwin.exit(ExitCodes.misconfigured)
        }
    }
}
