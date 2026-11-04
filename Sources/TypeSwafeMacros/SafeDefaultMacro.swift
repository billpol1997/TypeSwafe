import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

@main
struct TypeSwafePlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        SafeDefaultMacro.self,
    ]
}

struct SafeDefaultMacro: ExtensionMacro {
    static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard let structDeclaration = declaration.as(StructDeclSyntax.self) else {
            throw SafeDefaultMacroError("@SafeDefault can only be applied to a struct.")
        }

        guard structDeclaration.genericParameterClause == nil else {
            throw SafeDefaultMacroError("@SafeDefault does not support generic structs.")
        }

        if explicitlyConformsToSafeDefault(structDeclaration) {
            throw SafeDefaultMacroError(
                "@SafeDefault cannot be applied to a struct that already declares SafeDefault conformance."
            )
        }

        if structDeclaration.memberBlock.members.contains(where: { $0.decl.is(InitializerDeclSyntax.self) }) {
            throw SafeDefaultMacroError(
                "@SafeDefault does not support structs with custom initializers because it cannot safely select an initializer."
            )
        }

        let arguments = try storedPropertyArguments(in: structDeclaration)
        let accessModifier = try witnessAccessModifier(for: structDeclaration)
        let usesSafeDefault = arguments.contains(where: \ .requiresSafeDefault)
        var extensionSource = "extension \(type.trimmedDescription): SafeDefault {\n"
        extensionSource += "    \(accessModifier)static var safeDefault: Self {\n"

        if usesSafeDefault {
            extensionSource += "        func safeDefaultValue<Value: SafeDefault>(_: Value.Type) -> Value {\n"
            extensionSource += "            Value.safeDefault\n"
            extensionSource += "        }\n\n"
        }

        extensionSource += "        \(usesSafeDefault ? "return " : "")Self("
        if arguments.isEmpty {
            extensionSource += ")\n"
        } else {
            extensionSource += "\n"
            extensionSource += arguments
                .map { "            \($0.label): \($0.value)" }
                .joined(separator: ",\n")
            extensionSource += "\n        )\n"
        }
        extensionSource += "    }\n}"
        return [try ExtensionDeclSyntax("\(raw: extensionSource)")]
    }

    private static func storedPropertyArguments(
        in declaration: StructDeclSyntax
    ) throws -> [(label: String, value: String, requiresSafeDefault: Bool)] {
        var arguments: [(label: String, value: String, requiresSafeDefault: Bool)] = []

        for member in declaration.memberBlock.members {
            guard let variable = member.decl.as(VariableDeclSyntax.self) else {
                continue
            }

            try validateModifiers(of: variable)

            if !variable.attributes.isEmpty {
                throw SafeDefaultMacroError("@SafeDefault does not support property attributes or wrappers.")
            }

            for binding in variable.bindings {
                guard binding.accessorBlock == nil else {
                    throw SafeDefaultMacroError("@SafeDefault only supports stored properties.")
                }
                guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else {
                    throw SafeDefaultMacroError("@SafeDefault only supports properties with identifier patterns.")
                }

                if binding.initializer != nil {
                    // The memberwise initializer supplies declared defaults for both
                    // `let` and `var` properties when their arguments are omitted.
                    continue
                }

                guard let type = binding.typeAnnotation?.type else {
                    throw SafeDefaultMacroError(
                        "@SafeDefault requires a type annotation for property '\(identifier)'."
                    )
                }

                let value: String
                if isOptionalType(type) {
                    value = "nil"
                } else if isFunctionType(type) {
                    throw SafeDefaultMacroError(
                        "@SafeDefault does not support non-optional function-typed properties."
                    )
                } else {
                    value = "safeDefaultValue(\(type.trimmedDescription).self)"
                }
                arguments.append((identifier, value, !isOptionalType(type)))
            }
        }

        return arguments
    }

    private static func explicitlyConformsToSafeDefault(_ declaration: StructDeclSyntax) -> Bool {
        declaration.inheritanceClause?.inheritedTypes.contains(where: { inheritedType in
            let typeName = inheritedType.type.trimmedDescription
            return typeName == "SafeDefault" || typeName.hasSuffix(".SafeDefault")
        }) ?? false
    }

    private static func isOptionalType(_ type: some TypeSyntaxProtocol) -> Bool {
        type.is(OptionalTypeSyntax.self) || type.is(ImplicitlyUnwrappedOptionalTypeSyntax.self)
    }

    private static func isFunctionType(_ type: some TypeSyntaxProtocol) -> Bool {
        if type.is(FunctionTypeSyntax.self) {
            return true
        }

        if let attributedType = type.as(AttributedTypeSyntax.self) {
            return isFunctionType(attributedType.baseType)
        }

        guard let tupleType = type.as(TupleTypeSyntax.self), tupleType.elements.count == 1,
              let element = tupleType.elements.first,
              element.firstName == nil,
              element.secondName == nil
        else {
            return false
        }

        return isFunctionType(element.type)
    }

    private static func witnessAccessModifier(for declaration: StructDeclSyntax) throws -> String {
        let modifierKinds = Set(declaration.modifiers.map(\.name.tokenKind))

        if modifierKinds.contains(.keyword(.private)) || modifierKinds.contains(.keyword(.fileprivate)) {
            throw SafeDefaultMacroError("@SafeDefault does not support private or fileprivate structs.")
        }
        if modifierKinds.contains(.keyword(.public)) {
            return "public "
        }
        if modifierKinds.contains(.keyword(.package)) {
            return "package "
        }
        return ""
    }

    private static func validateModifiers(of variable: VariableDeclSyntax) throws {
        for modifier in variable.modifiers {
            switch modifier.name.tokenKind {
            case .keyword(.static):
                throw SafeDefaultMacroError("@SafeDefault does not support static properties.")
            case .keyword(.lazy):
                throw SafeDefaultMacroError("@SafeDefault does not support lazy properties.")
            case .keyword(.public), .keyword(.package), .keyword(.internal), .keyword(.private), .keyword(.fileprivate):
                continue
            default:
                throw SafeDefaultMacroError(
                    "@SafeDefault does not support the '\(modifier.name.text)' property modifier."
                )
            }
        }
    }
}

private struct SafeDefaultMacroError: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}
