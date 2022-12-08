import Foundation
import SwiftUI

// MARK: -

/// Stores a value and creates binding to it
/// - Parameter value: stored value
/// - Returns: read-only binding
public func bind<Value>(value: Value) -> any ValueBinding<Value>  {
    bind(value: value, through: \.self)
}

/// Stores a value and creates binding to its property denoted by `keyPath`
/// - Parameters:
///   - root: stored value
///   - keyPath: key path to the presented value
/// - Returns: read-only binding
public func bind<Root, Value>(value root: Root, through keyPath: KeyPath<Root, Value>) -> any ValueBinding<Value> {
    KeyPathBinding(from: root, through: keyPath).normalized
}

/// Stores a reference to given object and creates value binding to its property denoted by `keyPath`
/// - Parameters:
///   - root: object
///   - keyPath: key path to the presented value
/// - Returns: writable binding
public func bind<Root: AnyObject, Value>(object root: Root, through keyPath: ReferenceWritableKeyPath<Root, Value>
) -> any WritableValueBinding<Value> {
    KeyPathBinding<Root, Value, ReferenceWritableKeyPath<Root, Value>>(from: root, through: keyPath)
}

/// Creates binding to a value accessed through block
/// - Parameter get: block that will be called on each value access
/// - Returns: read-only binding
public func bind<Value>(get: @escaping () -> Value) -> any ValueBinding<Value> {
    ClosureBinding(get)
}

/// Creates binding to a value accessed and mutated through respective blocks
/// - Parameters:
///   - get: block that will be called on each value access
///   - set: block that will be called on each value mutation
/// - Returns: writable binding
public func bind<Value>(get: @escaping () -> Value, set: @escaping (Value) -> Void) -> any WritableValueBinding<Value> {
    ClosureBinding(get, set: set)
}

// MARK: - ValueBinding

/// A type that can read value stored externally
public protocol ValueBinding<Value> {
    associatedtype Value
    
    var value: Value { get }
    
    var forSwiftUI: SwiftUI.Binding<Value> { get }
    
    func map<Result>(keyPath: KeyPath<Value, Result>) -> any ValueBinding<Result>
   
    func map<Result>(get: @escaping (Value) -> Result) -> any ValueBinding<Result>
    
    func map<Result>(get: @escaping (Value) -> Result, set: @escaping (inout Value, Result) -> Void) -> any ValueBinding<Result>
    
    func map<Result>(get: @escaping (Value) -> Result, set: @escaping (Result) -> Value?) -> any ValueBinding<Result>
}

// MARK: - WritableValueBinding

/// A type that can read and write value stored externally
public protocol WritableValueBinding<Value>: ValueBinding {
    var value: Value { get nonmutating set }
    
    func map<Result>(keyPath: WritableKeyPath<Value, Result>) -> any WritableValueBinding<Result>

    func map<Result>(get: @escaping (Value) -> Result, set: @escaping (inout Value, Result) -> Void) -> any WritableValueBinding<Result>
    
    func map<Result>(get: @escaping (Value) -> Result, set: @escaping (Result) -> Value?) -> any WritableValueBinding<Result>
}

extension WritableValueBinding {
    public func map<Result>(keyPath: WritableKeyPath<Value, Result>) -> any WritableValueBinding<Result> {
        let kp: ReferenceWritableKeyPath<Self, Result> = (\Self.value).appending(path: keyPath)
        return KeyPathBinding(from: self, through: kp)
    }
    
    public func map<Result>(get: @escaping (Value) -> Result, set: @escaping (Result) -> Value?) -> any WritableValueBinding<Result> {
        self.map(get: get) { `var`, val in set(val).map { `var` = $0 } }
    }

    public func map<Result>(get: @escaping (Value) -> Result, set: @escaping (inout Value, Result) -> Void) -> any WritableValueBinding<Result> {
        ClosureBinding { get(self.value) } set: { set(&self.value, $0) }
    }
}

// MARK: - KeyPathBinding

private struct KeyPathBinding<Root, Value, Path: KeyPath<Root, Value>>: ValueBinding {
    public typealias Root = Root
    
    fileprivate var root: Root
    fileprivate let keyPath: Path
    
    public var value: Value {
        self.root[keyPath: self.keyPath]
    }
    
    internal var normalized: any ValueBinding<Value> {
        switch self.keyPath {
        case let kp as ReferenceWritableKeyPath<Root, Value>:
            return KeyPathBinding<Root, Value, ReferenceWritableKeyPath<Root, Value>>(from: self.root, through: kp)
        case let kp as WritableKeyPath<Root, Value>:
            return KeyPathBinding<Root, Value, WritableKeyPath<Root, Value>>(from: self.root, through: kp)
        default:
            return self
        }
    }
    
    internal init(from root: Root, through keyPath: Path) {
        self.root = root
        self.keyPath = keyPath
    }
    
    public func map<Result>(keyPath: KeyPath<Value, Result>) -> any ValueBinding<Result> {
        return KeyPathBinding<Root, Result, KeyPath<Root, Result>>(
            from: self.root,
            through: self.keyPath.appending(path: keyPath)
        ).normalized
    }
    
    public func map<Result>(get: @escaping (Value) -> Result) -> any ValueBinding<Result> {
        ClosureBinding { get(self.value) }
    }
        
    public func map<Result>(get: @escaping (Value) -> Result, set: @escaping (Result) -> Value?) -> any ValueBinding<Result> {
        if let kp = self.keyPath as? ReferenceWritableKeyPath<Root, Value> {
            let root = self.root
            return ClosureBinding { get(root[keyPath: kp]) } set: { set($0).map { root[keyPath: kp] = $0 } }
        } else {
            return ClosureBinding { get(self.value) }
        }
    }
    
    public func map<Result>(get: @escaping (Value) -> Result, set: @escaping (inout Value, Result) -> Void) -> any ValueBinding<Result> {
        if let kp = self.keyPath as? ReferenceWritableKeyPath<Root, Value> {
            let root = self.root
            return ClosureBinding { get(root[keyPath: kp]) } set: { set(&root[keyPath: kp], $0) }
        } else {
            return ClosureBinding { get(self.value) }
        }
    }

    public var forSwiftUI: SwiftUI.Binding<Value> {
        if let writableKeyPath = self.keyPath as? WritableKeyPath<Root, Value> {
            var root = self.root
            return .init(get: { root[keyPath: writableKeyPath] }, set: { root[keyPath: writableKeyPath] = $0 })
        } else {
            return .init(get: { self.root[keyPath: self.keyPath] }, set: { _, _ in })
        }
    }
}

extension KeyPathBinding: WritableValueBinding where Path: ReferenceWritableKeyPath<Root, Value> {
    var value: Value {
        get { self.root[keyPath: self.keyPath] }
        nonmutating set { self.root[keyPath: self.keyPath] = newValue }
    }
    
    func map<Result>(keyPath: WritableKeyPath<Value, Result>) -> any WritableValueBinding<Result> {
        // TODO: Why it doesnt infer proper type without a cast?
        let kp = self.keyPath.appending(path: keyPath) as! ReferenceWritableKeyPath<Root, Result>
        return KeyPathBinding<Root, Result, ReferenceWritableKeyPath<Root, Result>>(from: self.root, through: kp)
    }
}

extension KeyPathBinding: CustomDebugStringConvertible {
    var debugDescription: String {
        var access: String {
            switch self.keyPath {
            case is ReferenceWritableKeyPath<Root, Value>:
                return "rw"
            case is WritableKeyPath<Root, Value>:
                return "w"
            default:
                return "r"
            }
        }
        var base : String {
            if self.root is any ValueBinding {
                return String(reflecting: self.root)
            } else {
                return "\(Self.Root)"
            }
        }
        return "KeyPathBinding<\(Self.Value)>(\(self.value)) { \(access) through \(base) }"
    }
}

// MARK: - ClosureBinding

private struct ClosureBinding<Value, Set>: ValueBinding {
    fileprivate let get: () -> Value
    fileprivate let set: Set
    
    public var value: Value {
        self.get()
    }
    
    internal init(_ get: @escaping () -> Value, set: @escaping (Value) -> Void) where Set == (Value) -> Void {
        self.get = get
        self.set = set
    }
    
    internal init(_ get: @escaping () -> Value) where Set == Void {
        self.get = get
        self.set = ()
    }

    public func map<Result>(keyPath: KeyPath<Value, Result>) -> any ValueBinding<Result> {
        if let selfSet = self.set as? (Value) -> Void {
            typealias Rebound = ClosureBinding<Value, (Value) -> Void>
            let rebound = Rebound(self.get, set: selfSet)
            return KeyPathBinding(from: rebound, through: (\Rebound.value).appending(path: keyPath))
        } else {
            let kp: KeyPath<Self, Result> = (\Self.value).appending(path: keyPath)
            return KeyPathBinding(from: self, through: kp).normalized
        }
    }

    public func map<Result>(get: @escaping (Value) -> Result, set: @escaping (inout Value, Result) -> Void) -> any ValueBinding<Result> {
        if let selfSet = self.set as? (Value) -> Void {
            return ClosureBinding<Result, (Result) -> Void> { [selfGet = self.get] in
                get(selfGet())
            } set: { [selfGet = self.get] in
                var value = selfGet()
                set(&value, $0)
                selfSet(value)
            }
        } else {
            return ClosureBinding<Result, Void> { [selfGet = self.get] in
                get(selfGet())
            }
        }
    }
    
    public func map<Result>(get: @escaping (Value) -> Result, set: @escaping (Result) -> Value?) -> any ValueBinding<Result> {
        if let selfSet = self.set as? (Value) -> Void {
            return ClosureBinding<Result, (Result) -> Void> { [selfGet = self.get] in get(selfGet()) } set: { set($0).map(selfSet) }
        } else {
            return ClosureBinding<Result, Void> { [selfGet = self.get] in get(selfGet()) }
        }
    }

    public func map<Result>(get: @escaping (Value) -> Result) -> any ValueBinding<Result> {
        ClosureBinding<Result, Void> { [selfGet = self.get] in get(selfGet()) }
    }
    public var forSwiftUI: SwiftUI.Binding<Value> {
        if let set = self.set as? (Value) -> Void {
            return .init(get: self.get, set: set)
        } else {
            return .init(get: self.get, set: { _ in })
        }
    }
}

extension ClosureBinding: WritableValueBinding where Set == (Value) -> Void {
    var value: Value {
        get { self.get() }
        nonmutating set { self.set(newValue) }
    }
    
    func map<Result>(get: @escaping (Value) -> Result, set: @escaping (inout Value, Result) -> Void) -> any WritableValueBinding<Result> {
        ClosureBinding<Result, (Result) -> Void> { [selfGet = self.get] in
            get(selfGet())
        } set: { [selfGet = self.get, selfSet = self.set] in
            var value = selfGet()
            set(&value, $0)
            selfSet(value)
        }
    }
    
    func map<Result>(get: @escaping (Value) -> Result, set: @escaping (Result) -> Value?) -> any WritableValueBinding<Result> {
        ClosureBinding<Result, (Result) -> Void> { [selfGet = self.get] in
            get(selfGet())
        } set: { [selfSet = self.set] in
            set($0).map(selfSet)
        }
    }
}

extension ClosureBinding: CustomDebugStringConvertible {
    var debugDescription: String {
        "ClosureBinding<\(Self.Value)>(\(self.value)) { get\(self.set is (Value) -> Void ? " set" : "") }"
    }
}

// MARK: - SwiftUI.Binding

extension SwiftUI.Binding: WritableValueBinding {
    public var value: Value {
        get { self.wrappedValue }
        nonmutating set { self.wrappedValue = newValue }
    }
    
    public var forSwiftUI: SwiftUI.Binding<Value> {
        self
    }
    
    public func map<Result>(get: @escaping (Value) -> Result) -> any ValueBinding<Result> {
        ClosureBinding { get(self.value) }
    }
    
    public func map<Result>(keyPath: KeyPath<Value, Result>) -> any ValueBinding<Result> {
        let kp: KeyPath<Self, Result> = (\Self.value).appending(path: keyPath)
        return KeyPathBinding(from: self, through: kp).normalized
    }
    
    @_disfavoredOverload
    public func map<Result>(get: @escaping (Value) -> Result, set: @escaping (Result) -> Value?) -> any ValueBinding<Result> {
        ClosureBinding { get(self.value) } set: { set($0).map { self.value = $0 } }
    }
    
    @_disfavoredOverload
    public func map<Result>(get: @escaping (Value) -> Result, set: @escaping (inout Value, Result) -> Void) -> any ValueBinding<Result> {
        ClosureBinding { get(self.value) } set: { set(&self.value, $0) }
    }

    public func map<Result>(get: @escaping (Value) -> Result, set: @escaping (Result) -> Value?) -> any WritableValueBinding<Result> {
        self.map(get: get) { `var`, val in set(val).map { `var` = $0 } }
    }

    public func map<Result>(get: @escaping (Value) -> Result, set: @escaping (inout Value, Result) -> Void) -> any WritableValueBinding<Result> {
        ClosureBinding { get(self.value) } set: { set(&self.value, $0) }
    }
}

// MARK: - Debugging

extension ValueBinding {
    public func print(_ tag: String, describeValue: @escaping (Value) -> String = String.init(describing:)) -> any ValueBinding<Value> {
        return self.map {
            Swift.print("\(tag) get: \(describeValue($0))")
            return $0
        } set: {
            Swift.print("\(tag) set: \(describeValue($0)) -> \(describeValue($1))")
            $0 = $1
        }
    }
}
