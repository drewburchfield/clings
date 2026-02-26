# `update --when` and `--heading` Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add `--when` and `--heading` flags to the `clings update` command so tasks can be scheduled and moved between project headings from the CLI.

**Architecture:** `--when` uses JXA `activationDate` property (same pattern as createProject). `--heading` uses the Things URL scheme (`things:///update?heading=X`) because Things 3 doesn't expose heading assignment via JXA/AppleScript. Auth token for URL scheme stored in `~/.config/clings/auth-token`.

**Tech Stack:** Swift 6, ArgumentParser, JXA (JavaScript for Automation), Things 3 URL scheme

---

### Task 1: Add `--when` parameter to ThingsClientProtocol

**Files:**
- Modify: `Sources/ClingsCore/ThingsClient/ThingsClient.swift:65`
- Modify: `Sources/ClingsCore/ThingsClient/ThingsClient.swift:285`
- Modify: `Sources/ClingsCore/ThingsClient/HybridThingsClient.swift:155`
- Modify: `Tests/ClingsCoreTests/Mocks/MockThingsClient.swift:54,152`

**Step 1: Update protocol signature**

In `ThingsClient.swift:65`, change:
```swift
func updateTodo(id: String, name: String?, notes: String?, dueDate: Date?, tags: [String]?) async throws
```
to:
```swift
func updateTodo(id: String, name: String?, notes: String?, dueDate: Date?, when: Date?, tags: [String]?) async throws
```

**Step 2: Update ThingsClient actor implementation**

In `ThingsClient.swift:285`, add `when` parameter and pass to JXA:
```swift
public func updateTodo(id: String, name: String?, notes: String?, dueDate: Date?, when: Date? = nil, tags: [String]?) async throws {
    if name != nil || notes != nil || dueDate != nil || when != nil {
        let script = JXAScripts.updateTodo(id: id, name: name, notes: notes, dueDate: dueDate, when: when, tags: nil)
        ...
    }
    ...
}
```

**Step 3: Update HybridThingsClient implementation**

In `HybridThingsClient.swift:155`, same pattern:
```swift
public func updateTodo(id: String, name: String?, notes: String?, dueDate: Date?, when: Date? = nil, tags: [String]?) async throws {
    if name != nil || notes != nil || dueDate != nil || when != nil {
        let script = JXAScripts.updateTodo(id: id, name: name, notes: notes, dueDate: dueDate, when: when, tags: nil)
        ...
    }
    ...
}
```

**Step 4: Update MockThingsClient**

In `MockThingsClient.swift`, update tracking tuple and method signature:
```swift
private(set) var updateOperations: [(id: String, name: String?, notes: String?, dueDate: Date?, when: Date?, tags: [String]?)] = []

func updateTodo(id: String, name: String?, notes: String?, dueDate: Date?, when: Date?, tags: [String]?) async throws {
    if let error = errorToThrow { throw error }
    updateOperations.append((id, name, notes, dueDate, when, tags))
}
```

**Step 5: Build to verify compilation**

Run: `swift build`
Expected: PASS (no call sites pass `when:` yet, default nil)

**Step 6: Commit**

```bash
git add -A && git commit -m "feat: add when parameter to updateTodo protocol and implementations"
```

---

### Task 2: Add `--when` support to JXAScripts.updateTodo

**Files:**
- Modify: `Sources/ClingsCore/ThingsClient/JXAScripts.swift:271-299`
- Test: `Tests/ClingsCoreTests/ThingsClient/JXAScriptsTests.swift`

**Step 1: Write failing tests**

Add to JXAScriptsTests.swift UpdateTodoScript suite:
```swift
@Test func withWhen() {
    let date = Date()
    let script = JXAScripts.updateTodo(id: "todo-123", when: date)
    #expect(script.contains("todo.activationDate = new Date("))
}

@Test func withWhenDoesNotAffectDueDate() {
    let date = Date()
    let script = JXAScripts.updateTodo(id: "todo-123", when: date)
    #expect(!script.contains("todo.dueDate"))
}
```

**Step 2: Run tests to verify they fail**

Run: `swift test --filter JXAScriptsTests`
Expected: FAIL (updateTodo doesn't accept `when` parameter yet)

**Step 3: Update JXAScripts.updateTodo**

In `JXAScripts.swift:271`, add `when` parameter:
```swift
public static func updateTodo(
    id: String,
    name: String? = nil,
    notes: String? = nil,
    dueDate: Date? = nil,
    when: Date? = nil,
    tags: [String]? = nil
) -> String {
    let dueDateISO = dueDate.map { ISO8601DateFormatter().string(from: $0) }
    let whenISO = when.map { ISO8601DateFormatter().string(from: $0) }
    _ = tags

    return """
    (() => {
        const app = Application('Things3');
        const todo = app.toDos.byId('\(id.jxaEscaped)');

        if (!todo.exists()) {
            return JSON.stringify({ success: false, error: 'Todo not found' });
        }

        \(name != nil ? "todo.name = '\(name!.jxaEscaped)';" : "")
        \(notes != nil ? "todo.notes = '\(notes!.jxaEscaped)';" : "")
        \(dueDateISO != nil ? "todo.dueDate = new Date('\(dueDateISO!)');" : "")
        \(whenISO != nil ? "todo.activationDate = new Date('\(whenISO!)');" : "")

        return JSON.stringify({ success: true, id: '\(id.jxaEscaped)' });
    })()
    """
}
```

**Step 4: Run tests to verify they pass**

Run: `swift test --filter JXAScriptsTests`
Expected: PASS

**Step 5: Commit**

```bash
git add -A && git commit -m "feat: add when (activationDate) support to JXA updateTodo script"
```

---

### Task 3: Add `--when` and `--heading` flags to UpdateCommand

**Files:**
- Modify: `Sources/ClingsCLI/Commands/MutationCommands.swift:175-258`
- Test: `Tests/ClingsCLITests/ArgumentParsingTests.swift`

**Step 1: Write failing argument parsing tests**

Add to ArgumentParsingTests.swift UpdateCommandParsing suite:
```swift
@Test func whenOption() throws {
    let command = try UpdateCommand.parse(["JKL012", "--when", "tomorrow"])
    #expect(command.when == "tomorrow")
}

@Test func whenOptionToday() throws {
    let command = try UpdateCommand.parse(["JKL012", "--when", "today"])
    #expect(command.when == "today")
}

@Test func headingOption() throws {
    let command = try UpdateCommand.parse(["JKL012", "--heading", "Waiting on them"])
    #expect(command.heading == "Waiting on them")
}
```

**Step 2: Run tests to verify they fail**

Run: `swift test --filter ArgumentParsingTests`
Expected: FAIL (no `when` or `heading` properties on UpdateCommand)

**Step 3: Add flags to UpdateCommand**

In MutationCommands.swift, add to UpdateCommand struct:
```swift
@Option(name: .long, help: "Schedule for a date (YYYY-MM-DD, 'today', 'tomorrow')")
var when: String?

@Option(name: .long, help: "Move to a heading within the task's project")
var heading: String?
```

Update the guard:
```swift
guard name != nil || notes != nil || due != nil || !tags.isEmpty || when != nil || heading != nil else {
    throw ThingsError.invalidState("No update options provided. Use --name, --notes, --due, --when, --heading, or --tags.")
}
```

Add when date parsing and pass to client:
```swift
var whenDate: Date? = nil
if let whenStr = when {
    whenDate = parseDate(whenStr)
    if whenDate == nil {
        throw ThingsError.invalidState("Invalid date format: \(whenStr). Use YYYY-MM-DD, 'today', or 'tomorrow'.")
    }
}

try await client.updateTodo(
    id: id,
    name: name,
    notes: notes,
    dueDate: dueDate,
    when: whenDate,
    tags: tags.isEmpty ? nil : tags
)
```

For heading, add after the updateTodo call:
```swift
if let heading = heading {
    try setHeading(id: id, heading: heading)
}
```

Add helper method:
```swift
private func setHeading(id: String, heading: String) throws {
    guard let token = try? AuthTokenStore.loadToken() else {
        throw ThingsError.invalidState(
            "Things auth token required for --heading. Set with: clings config set-auth-token <token>"
        )
    }
    let encoded = heading.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? heading
    let url = "things:///update?auth-token=\(token)&id=\(id)&heading=\(encoded)"
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    process.arguments = [url]
    try process.run()
    process.waitUntilExit()
}
```

**Step 4: Run tests to verify they pass**

Run: `swift test --filter ArgumentParsingTests`
Expected: PASS

**Step 5: Commit**

```bash
git add -A && git commit -m "feat: add --when and --heading flags to update command"
```

---

### Task 4: Add auth token storage

**Files:**
- Create: `Sources/ClingsCore/Config/AuthTokenStore.swift`

**Step 1: Create AuthTokenStore**

```swift
import Foundation

public enum AuthTokenStore {
    private static var configDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config")
            .appendingPathComponent("clings")
    }

    private static var tokenFile: URL {
        configDir.appendingPathComponent("auth-token")
    }

    public static func loadToken() throws -> String {
        let token = try String(contentsOf: tokenFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            throw ThingsError.invalidState("Auth token file is empty")
        }
        return token
    }

    public static func saveToken(_ token: String) throws {
        try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        try token.trimmingCharacters(in: .whitespacesAndNewlines).write(to: tokenFile, atomically: true, encoding: .utf8)
    }
}
```

**Step 2: Add config command for setting token**

Create `Sources/ClingsCLI/Commands/ConfigCommand.swift`:
```swift
import ArgumentParser
import ClingsCore

struct ConfigCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "config",
        abstract: "Configure clings settings",
        subcommands: [SetAuthToken.self]
    )
}

struct SetAuthToken: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "set-auth-token",
        abstract: "Set the Things 3 auth token for URL scheme operations"
    )

    @Argument(help: "The auth token from Things 3")
    var token: String

    func run() throws {
        try AuthTokenStore.saveToken(token)
        print("Auth token saved.")
    }
}
```

Register in main command (find the root command file and add ConfigCommand to subcommands).

**Step 3: Build to verify**

Run: `swift build`
Expected: PASS

**Step 4: Commit**

```bash
git add -A && git commit -m "feat: add auth token storage and config command for Things URL scheme"
```

---

### Task 5: Update MockThingsClient reset

**Files:**
- Modify: `Tests/ClingsCoreTests/Mocks/MockThingsClient.swift:203-219`

**Step 1: Verify reset() clears when from updateOperations**

The reset already clears `updateOperations = []` so no change needed. Just verify the tuple shape is updated (done in Task 1).

---

### Task 6: Full build and test

**Step 1: Run full build**

Run: `swift build`
Expected: PASS

**Step 2: Run full test suite**

Run: `swift test`
Expected: All tests PASS

**Step 3: Commit any fixes**

---

### Task 7: Final review and PR

**Step 1: Review diff**

Run: `git diff main...HEAD`

**Step 2: Create PR**

Target: `drewburchfield/clings:main` (our fork)
Title: "feat: add --when and --heading support to update command"
