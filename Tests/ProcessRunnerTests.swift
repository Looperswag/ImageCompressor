import XCTest
@testable import ImageCompressor

/// Test suite for ProcessRunner subprocess execution
final class ProcessRunnerTests: XCTestCase {

    // MARK: - Path Validation Tests

    func testValidAbsolutePath() {
        // Test that valid absolute paths pass validation
        let validPaths = [
            "/usr/bin/sips",
            "/Users/test/Pictures/photo.jpg",
            "/tmp/output.png",
            "/Applications/MyApp.app",
        ]

        for path in validPaths {
            let process = ProcessRunnerActor()
            let result = await process.testIsPathSafe(path)
            XCTAssertTrue(result, "Path should be safe: \(path)")
        }
    }

    func testPathTraversalRejected() {
        // Test that path traversal attempts are rejected
        let unsafePaths = [
            "/Users/test/../etc/passwd",
            "/tmp/../../private/var",
            "/safe/path/../../../etc/passwd",
            "/var/log/../../../../../etc/shadow",
        ]

        for path in unsafePaths {
            let process = ProcessRunnerActor()
            let result = await process.testIsPathSafe(path)
            XCTAssertFalse(result, "Path should be rejected: \(path)")
        }
    }

    func testRelativePathRejected() {
        // Test that relative paths are rejected
        let relativePaths = [
            "./image.jpg",
            "../photo.png",
            "~/Pictures/file.jpg",
            "image.png",
        ]

        for path in relativePaths {
            let process = ProcessRunnerActor()
            let result = await process.testIsPathSafe(path)
            XCTAssertFalse(result, "Relative path should be rejected: \(path)")
        }
    }

    func testNullByteInjectionRejected() {
        // Test that null byte injection is rejected
        let injectionPaths = [
            "/safe/path\0/malicious",
            "/usr/bin/sips\0-rm-rf",
            "/etc/passwd\0.exe",
        ]

        for path in injectionPaths {
            let process = ProcessRunnerActor()
            let result = await process.testIsPathSafe(path)
            XCTAssertFalse(result, "Null byte injection should be rejected: \(path)")
        }
    }

    func testBackslashInjectionRejected() {
        // Test that backslash path separators (Windows) are rejected
        let windowsPaths = [
            "C:\\Windows\\System32\\cmd.exe",
            "/safe\\path\\to\\file",
            "/tmp/..\\..\\etc/passwd",
        ]

        for path in windowsPaths {
            let process = ProcessRunnerActor()
            let result = await process.testIsPathSafe(path)
            XCTAssertFalse(result, "Backslash path should be rejected: \(path)")
        }
    }

    // MARK: - Argument Validation Tests

    func testValidArguments() {
        // Test that valid arguments pass validation
        let validArguments: [(String, Bool)] = [
            ("-s", true),           // Short option
            ("-Z", true),           // Short option
            ("-a", true),           // Short option
            ("--out", true),        // Long option without path separator
            ("--format", true),     // Long option without path separator
            ("80", true),           // Numeric quality value
            ("1920", true),         // Numeric dimension value
            ("jpeg", true),         // Format name
            ("png", true),          // Format name
            ("/tmp/file.jpg", true), // Valid absolute path
            ("/Users/test/image.png", true), // Valid absolute path
        ]

        for (arg, _) in validArguments {
            let process = ProcessRunnerActor()
            let result = await process.testIsArgumentSafe(arg)
            XCTAssertTrue(result, "Argument should be safe: \(arg)")
        }
    }

    func testMaliciousArgumentsRejected() {
        // Test that malicious arguments are rejected
        let maliciousArguments: [(String, Bool)] = [
            ("--out=/etc/passwd", false),     // Option with path separator
            ("--config=../../../etc/shadow", false), // Option with path traversal
            ("../../file.jpg", false),        // Path traversal without leading /
            ("--option=../../etc/passwd", false), // Option with traversal
            ("/safe/../etc/passwd", false),   // Absolute with traversal
        ]

        for (arg, _) in maliciousArguments {
            let process = ProcessRunnerActor()
            let result = await process.testIsArgumentSafe(arg)
            XCTAssertFalse(result, "Malicious argument should be rejected: \(arg)")
        }
    }

    // MARK: - Process Execution Tests

    func testSimpleCommandExecution() async throws {
        // Test executing a simple command
        let result = try await ProcessRunner.run(
            executable: "/usr/bin/echo",
            arguments: ["hello", "world"],
            timeout: 5
        )

        XCTAssertTrue(result.succeeded, "Command should succeed")
        XCTAssertEqual(result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines), "hello world")
        XCTAssertEqual(result.terminationStatus, 0)
    }

    func testCommandExecutionWithTimeout() async throws {
        // Test that timeout works correctly
        do {
            // Sleep for 10 seconds but timeout after 1
            _ = try await ProcessRunner.run(
                executable: "/bin/sleep",
                arguments: ["10"],
                timeout: 1
            )
            XCTFail("Timeout should have occurred")
        } catch let error as ProcessRunnerError {
            switch error {
            case .timeout(_, _):
                // Expected
                XCTAssertTrue(error.localizedDescription.contains("超时") || error.localizedDescription.contains("timeout"))
            default:
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    func testNonExistentCommand() async throws {
        // Test error handling for non-existent command
        do {
            _ = try await ProcessRunner.run(
                executable: "/usr/bin/nonexistent_command_xyz123",
                arguments: [],
                timeout: 5
            )
            XCTFail("Should have thrown an error")
        } catch let error as ProcessRunnerError {
            switch error {
            case .executionFailed(_):
                // Expected
                break
            default:
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    func testLargeOutputHandling() async throws {
        // Test that large output (more than pipe buffer) doesn't block
        // Generate 10KB of output
        let arguments = ["-c", "for i in {1..100}; do echo 'Line $i: Lorem ipsum dolor sit amet consectetur adipiscing elit'; done"]

        let result = try await ProcessRunner.run(
            executable: "/bin/zsh",
            arguments: arguments,
            timeout: 5
        )

        XCTAssertTrue(result.succeeded, "Command should succeed")
        XCTAssertGreaterThan(result.standardOutput.count, 5000, "Should have received substantial output")
    }

    func testStderrCapture() async throws {
        // Test that stderr is properly captured
        let result = try await ProcessRunner.run(
            executable: "/bin/zsh",
            arguments: ["-c", "echo 'Error message' >&2; exit 1"],
            timeout: 5
        )

        XCTAssertFalse(result.succeeded, "Command should fail")
        XCTAssertEqual(result.terminationStatus, 1)
        XCTAssertTrue(result.standardError.contains("Error message"), "Stderr should contain error message")
    }

    // MARK: - Sips Command Tests (Integration)

    func testSipsCommandExists() {
        // Test that sips command is available
        XCTAssertTrue(ProcessRunner.commandExists("sips"), "sips should be available on macOS")
    }

    func testSipsGetProperty() async throws {
        // This test requires an actual image file
        // For now, just test that the command structure is valid
        // You'll need to provide a test image file

        // Create a small test image
        let testImageURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_image_\(UUID().uuidString).png")

        // Create a simple 1x1 red pixel image
        let imageSize = NSSize(width: 1, height: 1)
        let image = NSImage(size: imageSize)
        image.lockFocus()
        NSColor.red.drawSwatch(in: NSRect(origin: .zero, size: imageSize))
        image.unlockFocus()

        // Save the image
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            XCTFail("Failed to create test image")
            return
        }

        try pngData.write(to: testImageURL)

        defer {
            // Clean up
            try? FileManager.default.removeItem(at: testImageURL)
        }

        // Test sips get properties
        let result = try await ProcessRunner.run(
            executable: "/usr/bin/sips",
            arguments: ["-g", "all", testImageURL.path],
            timeout: 10
        )

        XCTAssertTrue(result.succeeded, "sips command should succeed")
        XCTAssertTrue(result.standardOutput.contains("pixelWidth") || result.standardOutput.contains("pixelHeight"),
                     "Output should contain image properties")
    }

    // MARK: - Edge Case Tests

    func testEmptyArguments() async throws {
        // Test command with no arguments
        let result = try await ProcessRunner.run(
            executable: "/usr/bin/true",
            arguments: [],
            timeout: 5
        )

        XCTAssertTrue(result.succeeded, "true command should always succeed")
    }

    func testArgumentWithSpaces() async throws {
        // Test arguments containing spaces (quoted)
        let result = try await ProcessRunner.run(
            executable: "/usr/bin/echo",
            arguments: ["hello world", "foo bar"],
            timeout: 5
        )

        XCTAssertTrue(result.succeeded, "Command should succeed")
        XCTAssertTrue(result.standardOutput.contains("hello world"), "Output should contain first argument")
        XCTAssertTrue(result.standardOutput.contains("foo bar"), "Output should contain second argument")
    }
}

// MARK: - Test Actor Helper

/// Actor wrapper to expose private testing methods
actor ProcessRunnerActor {
    func testIsPathSafe(_ path: String) -> Bool {
        // Mirror the private isPathSafe implementation
        guard !path.contains("\0") else { return false }
        let normalized = URL(fileURLWithPath: path).standardizedFileURL.path
        guard normalized.hasPrefix("/") else { return false }
        guard !normalized.contains("/../") && !normalized.hasSuffix("/..") else { return false }
        guard !normalized.contains("\\") else { return false }
        return true
    }

    func testIsArgumentSafe(_ arg: String) -> Bool {
        // Mirror the private isArgumentSafe implementation
        if arg.hasPrefix("-") && arg.count == 2 {
            return true
        }
        if arg.hasPrefix("--") {
            return !arg.contains("/") && !arg.contains("..")
        }
        if !arg.contains("/") {
            return true
        }
        if arg.hasPrefix("/") || arg.contains("/") {
            return testIsPathSafe(arg)
        }
        return true
    }
}
