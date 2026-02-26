// AuthTokenStoreTests.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import ClingsCore

@Suite("AuthTokenStore", .serialized)
struct AuthTokenStoreTests {

    @Suite("saveToken validation")
    struct SaveTokenValidation {
        @Test func rejectsEmptyToken() {
            #expect(throws: (any Error).self) {
                try AuthTokenStore.saveToken("")
            }
        }

        @Test func rejectsWhitespaceOnlyToken() {
            #expect(throws: (any Error).self) {
                try AuthTokenStore.saveToken("   \n\t  ")
            }
        }
    }

    @Suite("saveToken and loadToken round-trip", .serialized)
    struct RoundTrip {
        @Test func savesAndLoadsToken() throws {
            let testToken = "test-token-\(UUID().uuidString)"
            try AuthTokenStore.saveToken(testToken)
            let loaded = try AuthTokenStore.loadToken()
            #expect(loaded == testToken)
        }

        @Test func trimsWhitespace() throws {
            let core = "trimmed-token-\(UUID().uuidString)"
            let testToken = "  \(core)  \n"
            try AuthTokenStore.saveToken(testToken)
            let loaded = try AuthTokenStore.loadToken()
            #expect(loaded == core)
        }

        @Test func setsRestrictedPermissions() throws {
            try AuthTokenStore.saveToken("perm-test-\(UUID().uuidString)")
            let tokenPath = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".config/clings/auth-token")
            let attrs = try FileManager.default.attributesOfItem(atPath: tokenPath.path)
            let perms = (attrs[.posixPermissions] as? Int) ?? 0
            #expect(perms == 0o600)
        }

        @Test func overwritesPreviousToken() throws {
            let first = "first-\(UUID().uuidString)"
            let second = "second-\(UUID().uuidString)"
            try AuthTokenStore.saveToken(first)
            try AuthTokenStore.saveToken(second)
            let loaded = try AuthTokenStore.loadToken()
            #expect(loaded == second)
        }
    }

    @Suite("loadToken errors")
    struct LoadTokenErrors {
        @Test func throwsWhenTokenFileIsEmpty() throws {
            // Write an empty file (bypassing saveToken which rejects empty)
            let tokenPath = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".config/clings/auth-token")
            try Data().write(to: tokenPath)
            defer {
                // Restore a valid token so other tests aren't affected
                try? AuthTokenStore.saveToken("restored-after-empty-test")
            }
            #expect(throws: (any Error).self) {
                _ = try AuthTokenStore.loadToken()
            }
        }
    }
}
