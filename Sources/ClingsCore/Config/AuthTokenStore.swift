// AuthTokenStore.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Manages the Things 3 auth token used for URL scheme operations (e.g., heading updates).
public enum AuthTokenStore {
    private static var configDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config")
            .appendingPathComponent("clings")
    }

    private static var tokenFile: URL {
        configDir.appendingPathComponent("auth-token")
    }

    /// Load the stored auth token.
    public static func loadToken() throws -> String {
        let token = try String(contentsOf: tokenFile, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            throw ThingsError.invalidState("Auth token file is empty")
        }
        return token
    }

    /// Save an auth token to the config directory.
    public static func saveToken(_ token: String) throws {
        try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        try token.trimmingCharacters(in: .whitespacesAndNewlines)
            .write(to: tokenFile, atomically: true, encoding: .utf8)
    }
}
