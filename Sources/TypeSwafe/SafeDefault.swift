/// A type with a predictable value used when an optional value is absent.
///
/// Conforming types should choose a value that is inexpensive to create and has
/// unsurprising value semantics. Implementations must not cache mutable state.
public protocol SafeDefault {
    static var safeDefault: Self { get }
}

extension String: SafeDefault {
    public static var safeDefault: String { "" }
}

extension Int: SafeDefault {
    public static var safeDefault: Int { 0 }
}

extension Double: SafeDefault {
    public static var safeDefault: Double { 0 }
}

extension Float: SafeDefault {
    public static var safeDefault: Float { 0 }
}

extension Bool: SafeDefault {
    public static var safeDefault: Bool { false }
}

extension Array: SafeDefault {
    public static var safeDefault: Array<Element> { [] }
}

extension Dictionary: SafeDefault {
    public static var safeDefault: Dictionary<Key, Value> { [:] }
}

extension Set: SafeDefault {
    public static var safeDefault: Set<Element> { [] }
}

extension Optional: SafeDefault {
    public static var safeDefault: Optional<Wrapped> { nil }
}
