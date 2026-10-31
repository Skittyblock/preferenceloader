@_cdecl("PLSwiftArrayAppendValue")
public func PLSwiftArrayAppendValue(
    _ arrayField: UnsafeMutableRawPointer,
    _ value: UnsafeRawPointer,
    _ elementMetadata: UnsafeRawPointer
) {
    let elementType = unsafeBitCast(elementMetadata, to: Any.Type.self)
    func append<T>(_: T.Type) {
        let element = value.load(as: T.self)
        arrayField.assumingMemoryBound(to: [T].self).pointee.append(element)
    }
    _openExistential(elementType, do: append)
}

@_cdecl("PLSwiftArrayRemoveAll")
public func PLSwiftArrayRemoveAll(
    _ arrayField: UnsafeMutableRawPointer,
    _ elementMetadata: UnsafeRawPointer
) {
    let elementType = unsafeBitCast(elementMetadata, to: Any.Type.self)
    func clear<T>(_: T.Type) {
        arrayField.assumingMemoryBound(to: [T].self).pointee.removeAll()
    }
    _openExistential(elementType, do: clear)
}

@_cdecl("PLSwiftDictionarySetValue")
public func PLSwiftDictionarySetValue(
    _ dictionary: UnsafeMutableRawPointer,
    _ key: UnsafeRawPointer,
    _ keyMeta: UnsafeRawPointer,
    _ value: UnsafeRawPointer,
    _ valueMeta: UnsafeRawPointer
) -> Bool {
    let keyType = unsafeBitCast(keyMeta, to: Any.Type.self)
    guard let hashableType = keyType as? any Hashable.Type else { return false }
    let valueType = unsafeBitCast(valueMeta, to: Any.Type.self)

    func openKey<K: Hashable>(_: K.Type) {
        func set<V>(_: V.Type) {
            let copiedKey = key.load(as: K.self)
            let copiedValue = value.load(as: V.self)
            dictionary.assumingMemoryBound(to: [K: V].self).pointee.updateValue(
                copiedValue, forKey: copiedKey
            )
        }
        _openExistential(valueType, do: set)
    }

    _openExistential(hashableType, do: openKey)
    return true
}
