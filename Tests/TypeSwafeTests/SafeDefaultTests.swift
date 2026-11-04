import Testing
import TypeSwafe

@Suite("SafeDefault")
struct SafeDefaultTests {
    @Test("Primitive and collection defaults are predictable")
    func primitiveDefaults() {
        #expect(String.safeDefault == "")
        #expect(Int.safeDefault == 0)
        #expect(Double.safeDefault == 0)
        #expect(Float.safeDefault == 0)
        #expect(Bool.safeDefault == false)
        #expect([Int].safeDefault.isEmpty)
        #expect([String: Int].safeDefault.isEmpty)
        #expect(Set<Int>.safeDefault.isEmpty)
    }

    @Test("Optional defaults are nil and safe uses the wrapped default")
    func optionalDefaults() {
        let absent: Int? = nil
        let present: Int? = 42

        #expect(Optional<Int>.safeDefault == nil)
        #expect(absent.safe == 0)
        #expect(present.safe == 42)
    }

    @Test("The public macro synthesizes accessible defaults")
    func publicCustomStruct() {
        #expect(Profile.safeDefault == Profile(name: "", score: 0, nickname: nil))
    }

    @Test("The macro supports package-access structs")
    func packageCustomStruct() {
        #expect(PackageProfile.safeDefault == PackageProfile(value: 0))
    }

    @Test("The macro composes nested SafeDefault models")
    func nestedModelDefaults() {
        #expect(Account.safeDefault == Account(profile: .safeDefault, enabled: false))
    }

    @Test("The macro defaults optional nested models to nil")
    func optionalNestedModelDefaults() {
        #expect(OptionalAccount.safeDefault == OptionalAccount(profile: nil))
    }

    @Test("The macro defaults collections of custom models to empty")
    func customModelCollectionDefaults() {
        #expect(Directory.safeDefault == Directory(profiles: []))
    }

    @Test("The macro preserves explicit property defaults")
    func explicitPropertyDefaults() {
        #expect(Preferences.safeDefault == Preferences(retryCount: 3, labels: ["starter"]))
    }

    @Test("The macro preserves initialized properties while synthesizing the rest")
    func mixedPropertyDefaults() {
        #expect(Configuration.safeDefault == Configuration(enabled: false))
    }

    @Test("The macro preserves existing protocol conformances")
    func existingProtocolConformances() {
        #expect(IdentifiedProfile.safeDefault == IdentifiedProfile(identifier: 0))
    }

    @Test("The macro supports optional function properties")
    func optionalFunctionProperty() {
        #expect(OptionalHandler.safeDefault == OptionalHandler(handler: nil))
    }
}

@SafeDefault
public struct Profile: Equatable {
    public var name: String
    public var score: Int
    public var nickname: String?
}

@SafeDefault
package struct PackageProfile: Equatable {
    package var value: Int
}

@SafeDefault
struct Account: Equatable {
    var profile: Profile
    var enabled: Bool
}

@SafeDefault
struct OptionalAccount: Equatable {
    var profile: Profile?
}

@SafeDefault
struct Directory: Equatable {
    var profiles: [Profile]
}

@SafeDefault
struct Preferences: Equatable {
    var retryCount: Int = 3
    var labels: [String] = ["starter"]
}

@SafeDefault
struct Configuration: Equatable {
    let identifier: Int = 7
    var retryCount: Int = 3
    var enabled: Bool
}

@SafeDefault
struct IdentifiedProfile: Equatable, Sendable {
    var identifier: Int
}

@SafeDefault
struct OptionalHandler: Equatable {
    let handler: (() -> Void)?

    static func == (lhs: OptionalHandler, rhs: OptionalHandler) -> Bool {
        lhs.handler == nil && rhs.handler == nil
    }
}
