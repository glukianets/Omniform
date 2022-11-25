import Foundation

// MARK: - Model

public struct FormModel {
    public struct Options: OptionSet {
        public static var includeUnmarked = Self(rawValue: 1 << 0)
       
        public static var `default`: Self = [.includeUnmarked]
        
        public var rawValue: UInt

        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }
    }
    
    fileprivate enum Record: Identifiable {
        case field(Metadata, id: AnyHashable, ui: any MemberProtocol)
        case group(FormModel, id: AnyHashable, ui: any MemberProtocol)
        
        public var id: AnyHashable {
            get {
                switch self {
                case .field(_, id: let id, ui: _), .group(_, id: let id, ui: _):
                    return id
                }
            }
            set {
                switch self {
                case let .field(metadata, id: _, ui: ui):
                    self = .field(metadata, id: newValue, ui: ui)
                case let .group(model, id: _, ui: ui):
                    self = .group(model, id: newValue, ui: ui)
                }
            }
        }
    }
    
    private static let cache = MirrorCache()

    public var metadata: Metadata
    private var members: [Record]
    
    public init(
        name: Metadata.Text? = nil,
        icon: Metadata.Image? = nil,
        @Builder builder: () -> Prototype
    ) {
        let metadata = Metadata(type: FormModel.self, id: Member.NoID(), name: name, icon: icon)
        let prototype = builder()
        self = .init(metadata: metadata, members: prototype.members)
    }
    
    public init<S>(for binding: some ValueBinding<S>, options: Options = .default) {
        if let trampoline = CustomFormPresentableDispatch(type: S.self, binding: binding) as? CustomFormTrampoline {
            self = trampoline.form
        } else {
            let metadata = Metadata(type: S.self, id: \S.self, externalName: String(describing: S.self))
            let members = Prototype(dynamicallyInspecting: binding, options: options).members
            self.init(metadata: metadata, members: members)
        }
    }
    
    internal init(
        name: Metadata.Text? = nil,
        icon: Metadata.Image? = nil,
        prototype: Prototype
    ) {
        let metadata = Metadata(type: Self.self, id: Member.NoID(), name: name, icon: icon)
        self = .init(metadata: metadata, members: prototype.members)
    }

    private init(metadata: Metadata, members: [Member]) {
        self.init(metadata: metadata, records: members.enumerated().map { i, m in m.with(id: i) }.map(\.representation))
    }
    
    private init(metadata: Metadata, records: [Record]) {
        self.metadata = metadata
        self.members = records
    }
    
    public func fields<Visitor: FieldVisiting>(using visitor: Visitor) -> some RandomAccessCollection<Visitor.Result> {
        FieldsCollection<Visitor>(model: self, visitor: visitor)
    }

    public func filtered(using query: String) -> Self? {
        guard !query.isEmpty else { return self }

        return .init(metadata: self.metadata, records: self.members.compactMap {
            switch $0 {
            case .field(let metadata, id: _, ui: _) where metadata.matches(query: query):
                return $0
            case .group(let model, id: let id, ui: _):
                return model.filtered(using: query).flatMap {
                    !$0.members.isEmpty ? FormModel.Member.group(
                        model: $0,
                        presentation: FieldPresentations.Group<FormModel>.section(),
                        binding: bind(value: $0)
                    ).with(id: id).representation : nil
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
    func bundle(with binding: some ValueBinding<Self.Value>) -> any MemberProtocol {
        FieldRecord(presentation: self, binding: binding)
    }
}

private func fieldRecord<P: FieldPresenting, B: ValueBinding>(presentation: P, binding: B) -> MemberProtocol where P.Value == B.Value {
    FieldRecord<P, B>(presentation: presentation, binding: binding)
}

private struct FieldRecord<P: FieldPresenting, B: ValueBinding>: MemberProtocol where P.Value == B.Value {
    let presentation: P
    let binding: B
    
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
            var model = FormModel(for: wrappedValueBinding)
            model.metadata = model.metadata.with(type: self, id: keyPath, externalName: name)
            return .group(
                model: model,
                presentation: presentation,
                binding: wrappedValueBinding
            ).with(id: keyPath)
        } else {
            let presentation = self.preferredPresentation
            let metadata = Metadata(type: self, id: keyPath, externalName: name)
            return .field(
                wrappedValueBinding,
                metadata: metadata,
                presentation: presentation
            ).with(id: keyPath)
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
            var model = FormModel(for: wrappedValueBinding)
            model.metadata = value.metadata.with(id: keyPath, externalName: name).coalescing(with: model.metadata)
            return .group(
                model: model,
                presentation: presentation,
                binding: wrappedValueBinding
            ).with(id: keyPath)
        } else {
            let presentation = value.presentation
            let metadata = value.metadata.with(id: keyPath, externalName: name)
            return .field(
                wrappedValueBinding,
                metadata: metadata,
                presentation: presentation
            ).with(id: keyPath)
        }
    }
}

// MARK: - Searching

extension Metadata {
    fileprivate func matches(query: String) -> Bool {
        return self.name?.description.localizedStandardContains(query) ?? false
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

private protocol CustomFormTrampoline {
    var form: FormModel { get }
}

private struct CustomFormPresentableDispatch<T, B: ValueBinding<T>> {
    let type: T.Type
    let binding: B
}

extension CustomFormPresentableDispatch: CustomFormTrampoline where T: CustomFormPresentable {
    var form: FormModel {
        self.type.formModel(for: self.binding)
    }
}

// MARK: - Misc

extension FormModel: CustomFormPresentable {
    public static func formModel(for binding: some ValueBinding<Self>) -> FormModel {
        binding.value
    }
}

// MARK: FieldsCollection

extension FormModel {
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
}

// MARK: Prototype

extension FormModel {
    public struct Prototype {
        fileprivate let members: [Member]
        
        fileprivate init(members: [Member]) {
            self.members = members
        }
        
        public init<S>(dynamicallyInspecting binding: some ValueBinding<S>, options: FormModel.Options) {
            let members: [Member] = FormModel.cache[for: S.self].children.compactMap { child in
                if let type = type(of: child.keyPath).valueType as? any FieldProtocol.Type {
                    return type.build(from: binding, through: child.keyPath, name: child.label)
                } else if options.contains(.includeUnmarked),
                          let type = type(of: child.keyPath).valueType as? any CustomFieldPresentable.Type {
                    return type.build(from: binding, through: child.keyPath, name: child.label)
                } else {
                    return nil
                }
            }
            
            self.init(members: members)
        }
    }
}

// MARK: Member

extension FormModel {
    public struct Member {
        fileprivate struct NoID: Hashable {
            // nothing
        }
                
        public static func group(
            model: FormModel,
            presentation: FieldPresentations.Group<FormModel> = .section()
        ) -> Self {
            .group(
                model: model,
                presentation: presentation,
                binding: bind(value: model)
            )
        }
        
        public static func group<T>(
            binding: any ValueBinding<T>,
            presentation: some FieldPresenting<T>
        ) -> Self {
            .group(
                model: FormModel(for: binding),
                presentation: presentation,
                binding: binding
            )
        }
        
        public static func group(
            name: Metadata.Text? = nil,
            icon: Metadata.Image? = nil,
            presentation: FieldPresentations.Group<FormModel> = .section(),
            @Builder _ builder: () -> Prototype
        ) -> Self {
            let model = FormModel(name: name, icon: icon, prototype: builder())
            return .group(
                model: model,
                presentation: presentation,
                binding: bind(value: model)
            )
        }
        
        internal static func group<T>( // Designated
            model: FormModel,
            presentation: some FieldPresenting<T>,
            binding: any ValueBinding<T>
        ) -> Self {
            .init(representation: .group(
                model,
                id: NoID(),
                ui: fieldRecord(presentation: presentation, binding: binding))
            )
        }
        
        public static func field<T>(
            _ binding: any ValueBinding<T>,
            name: Metadata.Text? = nil,
            icon: Metadata.Image? = nil,
            presentation: some FieldPresenting<T>
        ) -> Self {
            .field(
                binding,
                metadata: Metadata(type: T.self, id: NoID(), name: name, icon: icon),
                presentation: presentation
            )
        }
        
        public static func field<T>(
            _ binding: any ValueBinding<T>,
            name: Metadata.Text? = nil,
            icon: Metadata.Image? = nil
        ) -> Self where T: CustomFieldPresentable {
            .field(
                binding,
                metadata: Metadata(type: T.self, id: NoID(), name: name, icon: icon),
                presentation: T.preferredPresentation
            )
        }
        
        public static func field<T>( // Designated
            _ binding: any ValueBinding<T>,
            metadata: Metadata,
            presentation: any FieldPresenting<T>
        ) -> Self {
            .init(representation: .field(
                metadata,
                id: metadata.id,
                ui: fieldRecord(presentation: presentation, binding: binding))
            )
        }
        
        public static func field<T>(
            binding: any ValueBinding<T>,
            metadata: Metadata
        ) -> Self where T: CustomFieldPresentable {
            .field(
                binding,
                metadata: metadata,
                presentation: T.preferredPresentation
            )
        }

        fileprivate private(set) var representation: FormModel.Record
        
        private init(representation: FormModel.Record) {
            self.representation = representation
        }
        
        fileprivate func with(id: AnyHashable) -> Self {
            guard self.representation.id == NoID() as AnyHashable else { return self }
            var result = self
            result.representation.id = id
            return result
        }
    }
}

// MARK: - Builder

extension FormModel {
    @resultBuilder public struct Builder {
        public static func buildBlock() -> Prototype {
            Prototype(members: [])
        }
        
        public static func buildBlock(_ components: Prototype...) -> Prototype {
            self.buildArray(components)
        }
        
        public static func buildExpression(_ expression: Member) -> Prototype {
            Prototype(members: [expression])
        }
        
        public static func buildExpression(_ expression: ()) -> Prototype {
            self.buildBlock()
        }
        
        public static func buildOptional(_ component: Prototype?) -> Prototype {
            self.buildBlock()
        }
        
        public static func buildEither(first component: Prototype) -> Prototype {
            component
        }
        
        public static func buildEither(second component: Prototype) -> Prototype {
            component
        }
        
        public static func buildArray(_ components: [Prototype]) -> Prototype {
            Prototype(members: components.flatMap(\.members))
        }
    }
}
