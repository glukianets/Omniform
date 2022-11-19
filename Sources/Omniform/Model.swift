import Foundation

// MARK: - Model

public struct FormModel {
    public struct Options: OptionSet {
        public static var includeUnmarked = Self(rawValue: 1 << 0)
        
        public var rawValue: UInt

        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }
    }
    
    private struct FieldsCollection<Visitor: FieldVisiting>: RandomAccessCollection {
        public typealias Element = Visitor.Result
        public typealias Index = Int
        
        private let visitor: Visitor
        private let model: FormModel

        public var startIndex: Index {
            return self.model.members.startIndex
        }
        
        public var endIndex: Index {
            return self.model.members.endIndex
        }
        
        fileprivate init(model: FormModel, visitor: Visitor) {
            self.visitor = visitor
            self.model = model
        }

        public func index(after i: Index) -> Index {
            i + 1
        }
        
        public subscript(index: Index) -> Visitor.Result {
            switch self.model.members[index] {
            case .group(let model, id: let id, ui: let trampoline):
                return trampoline.group(group: model, id: id, builder: self.visitor)
            case .field(let field, id: let id, ui: let trampoline):
                return trampoline.field(field: field, id: id, builder: self.visitor)
            }
        }
    }
    
    fileprivate enum Member: Identifiable {
        case field(Metadata, id: AnyHashable, ui: any MemberProtocol)
        case group(FormModel, id: AnyHashable, ui: any MemberProtocol)
        
        public var id: AnyHashable {
            switch self {
            case .field(_, id: let id, ui: _), .group(_, id: let id, ui: _):
                return id
            }
        }
    }
    
    private static let cache = MirrorCache()

    public var metadata: Metadata
    private var members: [Member]

    public func fields<Visitor: FieldVisiting>(using visitor: Visitor) -> some RandomAccessCollection<Visitor.Result> {
        FieldsCollection<Visitor>(model: self, visitor: visitor)
    }

    public init<S>(through binding: any ValueBinding<S>, options: Options = []) {
        if #available(iOS 16, macOS 13, *) {
            if
                let customType = S.self as? any CustomFormPresentable.Type,
                let model = customType.dataModel(throughErased: binding)
            {
                self = model
                return
            }
        }
        
        self.init(_through: binding, options: options)
    }
    
    private init<S>(_through binding: any ValueBinding<S>, options: Options = []) {
        if #available(iOS 16, macOS 13, *) {
            if
                let customType = S.self as? any CustomFormPresentable.Type,
                let model = customType.dataModel(throughErased: binding)
            {
                self = model
                return
            }
        }
        
        let members: [Member] = Self.cache[for: S.self].children.compactMap { child in
            if let type = type(of: child.keyPath).valueType as? any FieldProtocol.Type {
                return type.build(from: binding, through: child.keyPath, name: child.label)
            } else if options.contains(.includeUnmarked), let type = type(of: child.keyPath).valueType as? any CustomFieldPresentable.Type {
                return type.build(from: binding, through: child.keyPath, name: child.label)
            } else {
                return nil
            }
        }
        
        var metadata = Metadata(type: S.self, id: \S.self, externalName: String(describing: S.self))
        if let customType = S.self as? any CustomFormPresentable.Type {
            metadata = metadata.with(externalName: customType.dataModelTitle)
        }
        
        self.init(metadata: metadata, members: members)
    }
    
    private init(metadata: Metadata, members: [Member]) {
        self.metadata = metadata
        self.members = members
    }
    
    public func filtered(using query: String) -> Self? {
        guard !query.isEmpty else { return self }

        return .init(metadata: self.metadata, members: self.members.compactMap {
            switch $0 {
            case .field(let metadata, id: _, ui: _) where metadata.matches(query: query):
                return $0
            case .group(let model, id: let id, ui: _):
                return model.filtered(using: query).map {
                    .group($0, id: id, ui: FieldPresentations.Group<FormModel>(kind: .section(caption: nil)).bundle(with: bind(value: $0)))
                }
            default:
                return nil
            }
        })
    }
}

// MARK: - Building

private protocol MemberProtocol {
    func field<FB: FieldVisiting>(field: Metadata, id: AnyHashable, builder: FB) -> FB.Result
    func group<FB: FieldVisiting>(group: FormModel, id: AnyHashable, builder: FB) -> FB.Result
}

private extension FieldPresenting {
    func bundle(with binding: any ValueBinding<Self.Value>) -> any MemberProtocol {
        FieldRecord(presentation: self, binding: binding)
    }
}

private struct FieldRecord<P: FieldPresenting>: MemberProtocol {
    let presentation: P
    let binding: any ValueBinding<P.Value>
    
    func field<FB: FieldVisiting>(field: Metadata, id: AnyHashable, builder: FB) -> FB.Result {
        builder.visit(field: field, id: id, using: presentation, through: self.binding)
    }
    
    func group<FB: FieldVisiting>(group: FormModel, id: AnyHashable, builder: FB) -> FB.Result {
        builder.visit(group: group, id: id, using: presentation, through: self.binding)
    }
}

private extension CustomFieldPresentable {
    static func build<Root>(from binding: some ValueBinding<Root>, through keyPath: PartialKeyPath<Root>, name: String?) -> FormModel.Member? {
        guard let keyPath = keyPath as? KeyPath<Root, Self> else { return nil }
        let wrappedValueBinding = binding.map(keyPath: keyPath)
        
        if let presentation = self.preferredPresentation as? FieldPresentations.Group<Self> {
            var model = FormModel(through: wrappedValueBinding)
            model.metadata = model.metadata.with(externalName: name)
            return .group(model, id: keyPath, ui: presentation.bundle(with: wrappedValueBinding))
        } else {
            let presentation = self.preferredPresentation
            let metadata = Metadata(type: self, id: keyPath, externalName: name)
            return .field(metadata, id: keyPath, ui: presentation.bundle(with: wrappedValueBinding))
        }
    }
}

private extension FieldProtocol {
    static func build<Root>(from binding: some ValueBinding<Root>, through keyPath: PartialKeyPath<Root>, name: String?) -> FormModel.Member? {
        guard let keyPath = keyPath as? KeyPath<Root, Self> else { return nil }
        let fieldBinding = binding.map(keyPath: keyPath)
        let value = fieldBinding.value
        let wrappedValueBinding = fieldBinding.map(keyPath: \.wrappedValue)

        if let presentation = value.presentation as? FieldPresentations.Group<Self.WrappedValue> {
            var model = FormModel(through: wrappedValueBinding)
            model.metadata = model.metadata.with(externalName: name)
            return .group(model, id: keyPath, ui: presentation.bundle(with: wrappedValueBinding))
        } else {
            let presentation = value.presentation
            let metadata = value.metadata.with(id: keyPath, externalName: name)
            return .field(metadata, id: keyPath, ui: presentation.bundle(with: wrappedValueBinding))
        }
    }
}

// MARK: - Searching

extension Metadata {
    fileprivate func matches(query: String) -> Bool {
        return self.name?.localizedStandardContains(query) ?? false
            || self.externalName?.localizedCaseInsensitiveContains(query) ?? false
    }
}

// MARK: - Cache

private final class MirrorCache {
    private var cache: [ObjectIdentifier: Any] = [:]
    private let lock: Lock = .init()
    
    public subscript<T>(for type: T.Type) -> TypeMirror<T> {
        lock.whileLocked {
            if let mirror = self.cache[ObjectIdentifier(type)] {
                guard let mirror = mirror as? TypeMirror<T> else {
                    preconditionFailure("Mismatching mirror type \(Swift.type(of: mirror)) for \(type) as \(T.self)")
                }
                return mirror
            } else {
                let mirror = TypeMirror<T>(reflecting: type) ?? .init()
                self.cache[ObjectIdentifier(type)] = mirror
                return mirror
            }
        }
    }
}

// MARK: - Utility

fileprivate extension CustomFormPresentable {
    @available(iOS 16, macOS 13, *)
    static func dataModel(throughErased binding: any ValueBinding) -> FormModel? {
        (binding as? any ValueBinding<Self>).flatMap(self.dataModel(through:))
    }
}
