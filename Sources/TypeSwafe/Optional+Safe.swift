public extension Optional where Wrapped: SafeDefault {
    /// Returns the wrapped value or the wrapped type's safe default.
    @inlinable
    var safe: Wrapped {
        self ?? Wrapped.safeDefault
    }
}
