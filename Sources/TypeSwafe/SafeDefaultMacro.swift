/// Synthesizes ``SafeDefault`` for a struct whose stored properties either have
/// explicit defaults or conform to ``SafeDefault``. Declared property defaults
/// are preserved by the synthesized memberwise initializer. Non-optional
/// function properties are rejected because functions have no safe default.
@attached(extension, conformances: SafeDefault, names: named(safeDefault))
public macro SafeDefault() = #externalMacro(
    module: "TypeSwafeMacros",
    type: "SafeDefaultMacro"
)
