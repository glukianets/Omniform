import Foundation

internal struct TypeMirror<T> {
    public typealias SubjectType = T.Type
    public typealias Children = AnyCollection<Child>
    
    public struct Child {
        let label: String?
        let keyPath: PartialKeyPath<T>
    }
    
    public struct Options: OptionSet {
        public static var lenient: Self { Self(rawValue: 1 << 1) }
        public static var transformLabels: Self { Self(rawValue: 1 << 2) }

        public var rawValue: UInt
        
        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }
    }
        
    public let subjectType: SubjectType
    public let children: Children
    
    public init() {
        self.subjectType = T.self
        self.children = .init([])
    }
    
    public init?(reflecting type: SubjectType, options: Options = .lenient) {
        self.subjectType = type
        
        var children: [Child] = []
       
        func appendChild(name: UnsafePointer<CChar>, keyPath: PartialKeyPath<T>) -> Bool {
            guard let name = String(cString: name, encoding: .utf8) else { return options.contains(.lenient) }
            let prettyName = options.contains(.transformLabels) ? name.dropPrefix("_").humanReadable : name
            children.append(Child(label: prettyName, keyPath: keyPath))
            return true
        }
        
        var filedEnumerationOptions: EachFieldOptions = options.contains(.lenient) ? .ignoreUnknown : []
        guard forEachFieldWithKeyPath(of: type, options: &filedEnumerationOptions, body: appendChild(name:keyPath:)) else { return nil }
        
        self.children = AnyCollection(children)
    }
}

// MARK: - Shenanigans

internal struct EachFieldOptions: OptionSet {
    public static var classType = Self(rawValue: 1 << 0)
    public static var ignoreUnknown = Self(rawValue: 1 << 1)

    public var rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
}

@available(swift 5.4)
@discardableResult
@_silgen_name("$ss24_forEachFieldWithKeyPath2of7options4bodySbxm_s01_bC7OptionsVSbSPys4Int8VG_s07PartialeF0CyxGtXEtlF")
internal func forEachFieldWithKeyPath<Root>(
    of type: Root.Type,
    options: inout EachFieldOptions,
    body: (UnsafePointer<CChar>, PartialKeyPath<Root>) -> Bool
) -> Bool


