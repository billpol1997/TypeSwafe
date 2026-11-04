import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing
@testable import TypeSwafeMacros

private let testMacros: [String: Macro.Type] = [
    "SafeDefault": SafeDefaultMacro.self,
]

@Suite("SafeDefault macro")
struct SafeDefaultMacroTests {
    @Test("Synthesizes a struct default from SafeDefault properties")
    func expansion() {
        assertMacroExpansion(
            """
            @SafeDefault
            struct Person {
                var name: String
                var age: Int
                var nickname: String?
            }
            """,
            expandedSource: """
            struct Person {
                var name: String
                var age: Int
                var nickname: String?
            }

            extension Person: SafeDefault {
                static var safeDefault: Self {
                    func safeDefaultValue<Value: SafeDefault>(_: Value.Type) -> Value {
                        Value.safeDefault
                    }

                    return Self(
                        name: safeDefaultValue(String.self),
                        age: safeDefaultValue(Int.self),
                        nickname: nil
                    )
                }
            }
            """,
            macros: testMacros
        )
    }

    @Test("Omits explicitly initialized properties from the memberwise initializer")
    func explicitDefaults() {
        assertMacroExpansion(
            """
            @SafeDefault
            struct Settings {
                let identifier: Int = 7
                var retryCount: Int = 3
                var labels: [String] = ["starter"]
                var enabled: Bool
            }
            """,
            expandedSource: """
            struct Settings {
                let identifier: Int = 7
                var retryCount: Int = 3
                var labels: [String] = ["starter"]
                var enabled: Bool
            }

            extension Settings: SafeDefault {
                static var safeDefault: Self {
                    func safeDefaultValue<Value: SafeDefault>(_: Value.Type) -> Value {
                        Value.safeDefault
                    }

                    return Self(
                        enabled: safeDefaultValue(Bool.self)
                    )
                }
            }
            """,
            macros: testMacros
        )
    }

    @Test("Synthesizes an empty initializer call when every property has a default")
    func allExplicitDefaults() {
        assertMacroExpansion(
            """
            @SafeDefault
            struct Settings {
                let identifier: Int = 7
                var retryCount: Int = 3
                var labels: [String] = ["starter"]
            }
            """,
            expandedSource: """
            struct Settings {
                let identifier: Int = 7
                var retryCount: Int = 3
                var labels: [String] = ["starter"]
            }

            extension Settings: SafeDefault {
                static var safeDefault: Self {
                    Self()
                }
            }
            """,
            macros: testMacros
        )
    }

    @Test("Diagnoses unsupported declarations")
    func unsupportedDeclaration() {
        assertMacroExpansion(
            """
            @SafeDefault
            enum State {
                case ready
            }
            """,
            expandedSource: """
            enum State {
                case ready
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@SafeDefault can only be applied to a struct.", line: 1, column: 1),
            ],
            macros: testMacros
        )
    }

    @Test("Diagnoses property wrappers")
    func propertyWrapper() {
        assertMacroExpansion(
            """
            @SafeDefault
            struct Wrapped {
                @Wrapper var value: Int
            }
            """,
            expandedSource: """
            struct Wrapped {
                @Wrapper var value: Int
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@SafeDefault does not support property attributes or wrappers.", line: 1, column: 1),
            ],
            macros: testMacros
        )
    }

    @Test("Diagnoses generic structs")
    func genericStruct() {
        assertMacroExpansion(
            """
            @SafeDefault
            struct Box<Value> {
                var value: Value
            }
            """,
            expandedSource: """
            struct Box<Value> {
                var value: Value
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@SafeDefault does not support generic structs.", line: 1, column: 1),
            ],
            macros: testMacros
        )
    }

    @Test("Diagnoses lazy properties")
    func lazyProperty() {
        assertMacroExpansion(
            """
            @SafeDefault
            struct DeferredValue {
                lazy var value: Int = 1
            }
            """,
            expandedSource: """
            struct DeferredValue {
                lazy var value: Int = 1
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@SafeDefault does not support lazy properties.", line: 1, column: 1),
            ],
            macros: testMacros
        )
    }

    @Test("Diagnoses private structs")
    func privateStruct() {
        assertMacroExpansion(
            """
            @SafeDefault
            private struct Hidden {
                var value: Int
            }
            """,
            expandedSource: """
            private struct Hidden {
                var value: Int
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@SafeDefault does not support private or fileprivate structs.", line: 1, column: 1),
            ],
            macros: testMacros
        )
    }

    @Test("Diagnoses an existing SafeDefault conformance")
    func existingSafeDefaultConformance() {
        assertMacroExpansion(
            """
            @SafeDefault
            struct Existing: SafeDefault {
                var value: Int
            }
            """,
            expandedSource: """
            struct Existing: SafeDefault {
                var value: Int
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@SafeDefault cannot be applied to a struct that already declares SafeDefault conformance.",
                    line: 1,
                    column: 1
                ),
            ],
            macros: testMacros
        )
    }

    @Test("Preserves existing protocol conformances")
    func otherProtocolConformances() {
        assertMacroExpansion(
            """
            @SafeDefault
            struct Identified: Equatable, Sendable {
                var identifier: Int
            }
            """,
            expandedSource: """
            struct Identified: Equatable, Sendable {
                var identifier: Int
            }

            extension Identified: SafeDefault {
                static var safeDefault: Self {
                    func safeDefaultValue<Value: SafeDefault>(_: Value.Type) -> Value {
                        Value.safeDefault
                    }

                    return Self(
                        identifier: safeDefaultValue(Int.self)
                    )
                }
            }
            """,
            macros: testMacros
        )
    }

    @Test("Diagnoses function properties without parameters")
    func noParameterFunctionProperty() {
        assertFunctionPropertyDiagnostic(for: "() -> Void")
    }

    @Test("Diagnoses function properties with multiple parameters")
    func multipleParameterFunctionProperty() {
        assertFunctionPropertyDiagnostic(for: "(Int, String) -> Void")
    }

    @Test("Diagnoses function properties with return values")
    func returningFunctionProperty() {
        assertFunctionPropertyDiagnostic(for: "() -> String")
    }

    @Test("Diagnoses nested function properties")
    func nestedFunctionProperty() {
        assertFunctionPropertyDiagnostic(for: "(Int) -> (() -> Void)")
    }

    @Test("Synthesizes nil for optional function properties")
    func optionalFunctionProperty() {
        assertMacroExpansion(
            """
            @SafeDefault
            struct OptionalHandler {
                let handler: (() -> Void)?
            }
            """,
            expandedSource: """
            struct OptionalHandler {
                let handler: (() -> Void)?
            }

            extension OptionalHandler: SafeDefault {
                static var safeDefault: Self {
                    Self(
                        handler: nil
                    )
                }
            }
            """,
            macros: testMacros
        )
    }

    private func assertFunctionPropertyDiagnostic(for type: String) {
        assertMacroExpansion(
            """
            @SafeDefault
            struct HandlerContainer {
                let handler: \(type)
            }
            """,
            expandedSource: """
            struct HandlerContainer {
                let handler: \(type)
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@SafeDefault does not support non-optional function-typed properties.",
                    line: 1,
                    column: 1
                ),
            ],
            macros: testMacros
        )
    }
}
