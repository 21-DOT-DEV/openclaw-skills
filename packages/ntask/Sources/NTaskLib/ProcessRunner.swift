import Foundation
import Subprocess

struct ProcessResult: Sendable {
    let stdout: String
    let stderr: String
    let exitCode: Int
}

enum ProcessRunner {
    static func run(
        executable: String,
        arguments: [String],
        environment: [String: String]? = nil
    ) async throws -> ProcessResult {
        let env: Subprocess.Environment
        if let environment {
            var overrides: [Subprocess.Environment.Key: String?] = [:]
            for (key, value) in environment {
                overrides[Subprocess.Environment.Key(stringLiteral: key)] = value
            }
            env = Subprocess.Environment.inherit.updating(overrides)
        } else {
            env = .inherit
        }

        let result = try await Subprocess.run(
            .name(executable),
            arguments: .init(arguments),
            environment: env,
            output: .string(limit: 1024 * 1024),
            error: .string(limit: 1024 * 1024)
        )

        let stdout = result.standardOutput ?? ""
        let stderr = result.standardError ?? ""

        let exitCode: Int
        switch result.terminationStatus {
        case .exited(let code):
            exitCode = Int(code)
        default:
            exitCode = 1
        }

        return ProcessResult(stdout: stdout, stderr: stderr, exitCode: exitCode)
    }

    static func findExecutable(_ name: String) async -> Bool {
        do {
            let result = try await Subprocess.run(
                .name("which"),
                arguments: .init([name]),
                output: .string(limit: 4096),
                error: .string(limit: 4096)
            )
            if case .exited(0) = result.terminationStatus {
                return true
            }
            return false
        } catch {
            return false
        }
    }
}
