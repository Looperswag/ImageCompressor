import Foundation

/// Utility for running shell commands asynchronously
actor ProcessRunner {

    /// Result of a shell command execution
    struct ProcessResult {
        let terminationStatus: Int32
        let standardOutput: String
        let standardError: String

        var succeeded: Bool {
            terminationStatus == 0
        }
    }

    /// Validates that a path is safe (absolute, no path traversal, no null bytes)
    private static func isPathSafe(_ path: String) -> Bool {
        // Check for null bytes (path injection)
        guard !path.contains("\0") else { return false }

        let normalized = URL(fileURLWithPath: path).standardizedFileURL.path

        // Must be absolute path
        guard normalized.hasPrefix("/") else { return false }

        // Must not contain path traversal patterns
        guard !normalized.contains("/../") && !normalized.hasSuffix("/..") else { return false }

        // Must not contain backslashes (Windows path separator, potential injection)
        guard !normalized.contains("\\") else { return false }

        return true
    }

    /// Validate argument to ensure it's not a malicious path
    /// - Returns: true if argument is safe (numeric flag, option, or valid absolute path)
    private static func isArgumentSafe(_ arg: String) -> Bool {
        // Allow short options: -s, -Z, -a, -g, -v, etc.
        if arg.hasPrefix("-") && arg.count == 2 {
            return true
        }

        // Allow long options: --option, --out, --format
        if arg.hasPrefix("--") {
            // Validate it doesn't contain path separator or parent reference
            return !arg.contains("/") && !arg.contains("..")
        }

        // Allow plain strings without path separators (format names, etc.)
        if !arg.contains("/") {
            return true
        }

        // If it looks like a path, validate it thoroughly
        if arg.hasPrefix("/") || arg.contains("/") {
            return isPathSafe(arg)
        }

        // Default: safe (numbers, simple values)
        return true
    }

    /// Run a shell command with arguments
    static func run(
        executable: String,
        arguments: [String],
        timeout: TimeInterval = 30
    ) async throws -> ProcessResult {
        // Validate executable path
        guard isPathSafe(executable) else {
            throw ProcessRunnerError.invalidPath("Invalid executable path")
        }

        // Validate all arguments for path injection
        for arg in arguments {
            guard isArgumentSafe(arg) else {
                throw ProcessRunnerError.invalidPath("Invalid argument: \(arg)")
            }
        }

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            // Use serial queue for thread-safe state access
            let stateQueue = DispatchQueue(label: "com.imagecompressor.processrunner")
            var hasCompleted = false
            var outputData = Data()
            var errorData = Data()

            // Set up async reading to avoid blocking on large output
            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                let available = handle.availableData
                stateQueue.sync {
                    if !available.isEmpty {
                        outputData.append(available)
                    }
                }
            }

            errorPipe.fileHandleForReading.readabilityHandler = { handle in
                let available = handle.availableData
                stateQueue.sync {
                    if !available.isEmpty {
                        errorData.append(available)
                    }
                }
            }

            // Timeout handling with cancellation support
            let timeoutTask = DispatchWorkItem {
                stateQueue.sync {
                    guard !hasCompleted else { return }
                    hasCompleted = true
                }

                // Clean up readability handlers
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil

                process.terminate()

                // Try to get any data we've collected so far
                let finalOutput = stateQueue.sync { outputData }
                let finalError = stateQueue.sync { errorData }

                let timeoutError = ProcessRunnerError.timeout(
                    output: String(data: finalOutput, encoding: .utf8) ?? "",
                    error: String(data: finalError, encoding: .utf8) ?? ""
                )
                continuation.resume(throwing: timeoutError)
            }

            DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutTask)

            // Completion handling
            process.terminationHandler = { _ in
                timeoutTask.cancel()

                stateQueue.sync {
                    guard !hasCompleted else { return }
                    hasCompleted = true
                }

                // Clean up readability handlers
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil

                // Read any remaining data
                let remainingOutput = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let remainingError = errorPipe.fileHandleForReading.readDataToEndOfFile()

                let finalOutput = stateQueue.sync { outputData + remainingOutput }
                let finalError = stateQueue.sync { errorData + remainingError }

                let result = ProcessResult(
                    terminationStatus: process.terminationStatus,
                    standardOutput: String(data: finalOutput, encoding: .utf8) ?? "",
                    standardError: String(data: finalError, encoding: .utf8) ?? ""
                )

                continuation.resume(returning: result)
            }

            do {
                try process.run()
            } catch {
                timeoutTask.cancel()

                stateQueue.sync {
                    guard !hasCompleted else { return }
                    hasCompleted = true
                }

                // Clean up readability handlers
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil

                continuation.resume(throwing: ProcessRunnerError.executionFailed(error.localizedDescription))
            }
        }
    }

    /// Check if a command exists in PATH (synchronous version)
    static func commandExists(_ command: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [command]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}

enum ProcessRunnerError: LocalizedError {
    case timeout(output: String, error: String)
    case executionFailed(String)
    case invalidPath(String)

    var errorDescription: String? {
        switch self {
        case .timeout(let output, let error):
            var result = "命令超时"
            if !error.isEmpty {
                result += "\n错误信息: \(error)"
            }
            if !output.isEmpty && output.count < 500 {
                result += "\n输出: \(output)"
            }
            return result
        case .executionFailed(let message):
            return "执行失败: \(message)"
        case .invalidPath(let message):
            return "无效的路径：\(message)"
        }
    }
}
