import Foundation

// MARK: - Model

/// A dynamic form data model type
public struct FormModel {
    /// Dynamic form creation options
    public struct Options: OptionSet {
        /// When this flag is set, model ignores fields that aren't marked with ``Field`` property wrapper
        public static var excludeUnmarked = Self(rawValue: 1 << 0)
        
        public var rawValue: UInt

        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }
    }
    
    fileprivate enum Record: Identifiable {
        case field(Metadata, id: AnyHashable, ui: any FieldRecordProtocol)
        case group(FormModel, id: AnyHashable, ui: any GroupRecordProtocol)
        
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
    
    /// This form's metadata
    public var metadata: Metadata
    private var members: [Record]
    
    /// Builds a new model instance using convenient resultBuilder-based syntax
    ///
    /// You can call various static methods on ``Member`` to produce desired elements:
    /// ```swift
    /// FormModel(name: "To-do list") {
    ///     .field(self.dataModel.$walkTheDog, name: "Walk the dog", presentaton: .toggle);
    ///     .group(name: "Groceries") {
    ///        .field(self.dataModel.$groceries.eggs, name: "Eggs");
    ///        .field(self.dataModel.$groceries.milk, name: "Milk");
    ///    }
    /// }
    /// ```
    /// - Parameters:
    ///   - name: name
    ///   - icon: icon
    ///   - builder: form builder
    public init(
        name: Metadata.Text? = nil,
        icon: Metadata.Image? = nil,
        @Builder builder: () -> Prototype
    ) {
        let metadata = Metadata(type: FormModel.self, id: Member.NoID(), name: name, icon: icon)
        self = .init(metadata: metadata, builder: builder)
    }
    
    /// Builds a new model instance using convenient resultBuilder-based syntax
    ///
    /// You can call various static methods on ``Member`` to produce desired elements:
    /// ```swift
    /// FormModel(name: "To-do list") {
    ///     .field(self.dataModel.$walkTheDog, name: "Walk the dog", presentaton: .toggle);
    ///     .group(name: "Groceries") {
    ///        .field(self.dataModel.$groceries.eggs, name: "Eggs");
    ///        .field(self.dataModel.$groceries.milk, name: "Milk");
    ///    }
    /// }
    /// ```
    /// - Parameters:
    ///   - name: name
    ///   - icon: icon
    ///   - builder: form builder
    public init(
        metadata: Metadata,
        @Builder builder: () -> Prototype
    ) {
        self = .init(metadata: metadata, prototype: builder())
    }
    
    /// Builds a new form model instance by reflecting provided value binding
    /// - Parameters:
    ///   - binding: binding to the root value. Changes inside ui will be reflected back through it.
    ///   - options: form building options. See ``Options`` for further explanation.
    public init<S>(_ binding: some ValueBinding<S>, options: Options = []) {
        if let trampoline = CustomFormPresentableDispatch(type: S.self, binding: binding) as? CustomFormTrampoline {
            self = trampoline.form
        } else {
            let metadata = Metadata(type: S.self, id: \S.self, externalName: String(describing: S.self))
            let members = Prototype(reflecting: binding, options: options).members
            self.init(metadata: metadata, members: members)
        }
    }
    
    /// Builds a new form model instance directly from metadata and prototype
    /// - Parameters:
    ///   - metadata: metadata
    ///   - prototype: prototype
    public init(
        metadata: Metadata,
        prototype: Prototype
    ) {
        self = .init(metadata: metadata, members: prototype.members)
    }

    private init(metadata: Metadata, members: [Member]) {
        self.init(metadata: metadata, records: members.enumerated().map { i, m in m.with(id: i) }.map(\.representation))
    }
    
    private init(metadata: Metadata, records: [Record]) {
        self.metadata = metadata
        self.members = records
    }
    
    /// Builds a collection of form fields elements
    ///
    /// Since forms doesn't store their fields in some uniform way, you have to provide your custom
    /// ``FieldVisiting`` object that can represent them as a single type.
    /// - Note The returned collection will call respective visitor members at each access.
    ///
    /// - Parameter visitor: visitor that builds elements from provided form fields
    /// - Returns: a collection of elements built from this form's fields
    public func fields<Visitor: FieldVisiting>(using visitor: Visitor) -> some RandomAccessCollection<Visitor.Result> {
        
        self.members.lazy.map { record in
            switch record {
            case .group(let model, id: let id, ui: let trampoline):
                return trampoline.visit(group: model, id: id, builder: visitor)
            case .field(let field, id: let id, ui: let trampoline):
                return trampoline.visit(field: field, id: id, builder: visitor)
            }
        }
    }
    
    /// Filters a form to match seqrch query
    /// - Parameter query: string to match with lose text search
    /// - Returns: a derived form that only contains matching members or nil if nothing was found
    public func filtered(using query: String) -> Self? {
        guard !query.isEmpty else { return self }

        return .init(metadata: self.metadata, records: self.members.compactMap {
            switch $0 {
            case .field(let metadata, id: _, ui: _) where metadata.matches(query: query):
                return $0
            case .group(let model, id: let id, ui: _):
                return model.filtered(using: query).flatMap {
                    !$0.members.isEmpty ? FormModel.Member.group(
                        bind(value: $0),
                        model: $0,
                        ui: Presentations.Group<FormModel>.section()
                    ).with(id: id).representation : nil
                }
            default:
                return nil
            }
        })
    }
}

extension FormModel: CustomFormPresentable {
    public static func formModel(for binding: some ValueBinding<Self>) -> FormModel {
        binding.value
    }
}

extension FormModel: _CustomFieldFormattable {
    public static var _preferredFormat: AnyFormatStyle<Self, String> {
        .dynamic { _ in "" }
    }
}

extension FormModel: CustomDebugStringConvertible {
    public var debugDescription: String {
        func describe(metadata: Metadata) -> String? {
            let icon: String? = metadata.icon.map {
                switch $0 {
                case .system(let content):
                    return "icon: \'\(content.name)\'"
                case .custom(let content):
                    return "icon: \"\(content.name)\""
                case .native(let content):
                    return "icon: \(ObjectIdentifier(content.image))"
                }
            }
            
            let name: String? = metadata.name.map {
                switch $0 {
                case .text(let content):
                    return "name: \"\(content.key)\""
                }
            }
            
            let fields = [name, icon].compactMap { $0 }
            return fields.isEmpty ? nil : fields.joined(separator: ", ")
        }
        
        let members = self.members.map { record in
            switch record {
            case let .field(metadata, id: _, ui: ui):
                return """
                @Field(ui: \(ui)\(describe(metadata: metadata).map { ", \($0)" } ?? ""))
                """
            case let .group(form, id: _, ui: ui):
                return """
                @Group(ui: \(ui)) \(form)
                """
            }
        }.joined(separator: "\n").indent("    ")
        
        return """
        Form(\(describe(metadata: metadata) ?? "")) {
        \(members)
        }
        """
    }
}

// MARK: - Building

private func fieldRecord<P, B>(presentation: P, binding: B) -> any FieldRecordProtocol
where
    P: FieldPresenting,
    B: ValueBinding,
    P.Value == B.Value
{
    MemberRecord<P, B>(presentation: presentation, binding: binding)
}

private func groupRecord<P, B>(presentation: P, binding: B) -> any GroupRecordProtocol
where
    P: GroupPresenting,
    B: ValueBinding,
    P.Value == B.Value
{
    MemberRecord<P, B>(presentation: presentation, binding: binding)
}

private struct MemberRecord<P: FieldPresenting, B: ValueBinding> where P.Value == B.Value {
    var presentation: P
    var binding: B
}

private protocol FieldRecordProtocol {
    func member(metadata: Metadata) -> FormModel.Member
    
    func visit<FB: FieldVisiting>(field: Metadata, id: AnyHashable, builder: FB) -> FB.Result
}

private protocol GroupRecordProtocol {
    func member(metadata: Metadata) -> FormModel.Member
    
    func visit<FB: FieldVisiting>(group: FormModel, id: AnyHashable, builder: FB) -> FB.Result
}

extension MemberRecord: FieldRecordProtocol {
    func member(metadata: Metadata) -> FormModel.Member {
        if let builder = self as? GroupRecordProtocol {
            return builder.member(metadata: metadata)
        } else {
            return .init(representation: .field(metadata, id: metadata.id, ui: self))
        }
    }
    
    func visit<FB: FieldVisiting>(field: Metadata, id: AnyHashable, builder: FB) -> FB.Result {
        builder.visit(field: field, id: id, using: presentation, through: self.binding)
    }
}

extension MemberRecord: GroupRecordProtocol where P: GroupPresenting {
    func member(metadata: Metadata) -> FormModel.Member {
        var `self` = self
        if let form = self.presentation.makeForm(metadata: metadata, binding: self.binding) {
            return .init(representation: .group(form, id: metadata.id, ui: self))
        } else {
            return .init(representation: .field(metadata, id: metadata.id, ui: self))
        }
    }
    
    func visit<FB: FieldVisiting>(group: FormModel, id: AnyHashable, builder: FB) -> FB.Result {
        builder.visit(group: group, id: id, using: presentation, through: self.binding)
    }
}

extension MemberRecord: CustomStringConvertible {
    var description: String {
        String(describing: self.presentation)
    }
}

private extension CustomFieldPresentable {
    static func build<Root>(from binding: some ValueBinding<Root>, through keyPath: PartialKeyPath<Root>, name: String?) -> FormModel.Member? {
        guard let keyPath = keyPath as? KeyPath<Root, Self> else { return nil }
        let wrappedValueBinding = binding.map(keyPath: keyPath)
        
        return fieldRecord(presentation: self.preferredPresentation, binding: wrappedValueBinding)
            .member(metadata: Metadata(type: self, id: keyPath, externalName: name))
    }
}

private extension FieldProtocol {
    static func build<Root>(from binding: some ValueBinding<Root>, through keyPath: PartialKeyPath<Root>, name: String?) -> FormModel.Member? {
        guard let keyPath = keyPath as? KeyPath<Root, Self> else { return nil }
        let fieldBinding = binding.map(keyPath: keyPath)
        let value = fieldBinding.value
        let wrappedValueBinding = fieldBinding.map(keyPath: \.wrappedValue)

        return fieldRecord(presentation: value.presentation, binding: wrappedValueBinding)
            .member(metadata: value.metadata.with(id: keyPath, externalName: name))
    }
}

// MARK: - Searching

extension Metadata {
    fileprivate func matches(query: String) -> Bool {
        return self.name?.description.localizedStandardContains(query) ?? false
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

// MARK: - CustomFormPresentable + Utility

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

// MARK: Prototype

extension FormModel {
    /// ``Builder`` result type
    public struct Prototype {
        fileprivate let members: [Member]
        
        /// Create instance directly from members
        /// - Parameter members: members
        public init(members: [Member]) {
            self.members = members
        }
        
        /// Create instace by inspecting the contents of provided binding
        /// - Parameters:
        ///   - binding: binding to a reflected value
        ///   - options: form building options. See ``FormModel/Options`` for further explanation.
        public init<S>(reflecting binding: some ValueBinding<S>, options: FormModel.Options = []) {
            let members: [Member] = FormModel.cache[for: S.self].children.compactMap { child in
                if let type = type(of: child.keyPath).valueType as? any FieldProtocol.Type {
                    return type.build(from: binding, through: child.keyPath, name: child.label)
                } else if
                    !options.contains(.excludeUnmarked),
                    let type = type(of: child.keyPath).valueType as? any CustomFieldPresentable.Type
                {
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
    /// ``Builder`` element type
    public struct Member {
        fileprivate struct NoID: Hashable {
            // nothing
        }
                
        public static func group(
            model: FormModel,
            ui presentation: some GroupPresenting<FormModel> = .section()
        ) -> Self {
            .group(
                bind(value: model),
                model: model,
                ui: presentation
            )
        }
        
        public static func group<T>(
            binding: any ValueBinding<T>,
            ui presentation: some GroupPresenting<T>
        ) -> Self {
            .group(
                binding,
                model: FormModel(binding),
                ui: presentation
            )
        }
        
        public static func group(
            name: Metadata.Text? = nil,
            icon: Metadata.Image? = nil,
            ui presentation: Presentations.Group<FormModel> = .section(),
            @Builder _ builder: () -> Prototype
        ) -> Self {
            let model = FormModel(name: name, icon: icon, builder: builder)
            return .group(
                bind(value: model),
                model: model,
                ui: presentation
            )
        }
        
        public static func group<T>( // Designated
            _ binding: any ValueBinding<T>,
            model: FormModel,
            ui presentation: some GroupPresenting<T>
        ) -> Self {
            .init(representation: .group(
                model,
                id: NoID(),
                ui: groupRecord(presentation: presentation, binding: binding)
            ))
        }
        
        public static func field<T>(
            _ binding: any ValueBinding<T>,
            name: Metadata.Text? = nil,
            icon: Metadata.Image? = nil,
            ui presentation: some FieldPresenting<T>
        ) -> Self {
            .field(
                binding,
                metadata: Metadata(type: T.self, id: NoID(), name: name, icon: icon),
                ui: presentation
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
                ui: T.preferredPresentation
            )
        }
        
        public static func field<T>( // Designated
            _ binding: any ValueBinding<T>,
            metadata: Metadata,
            ui presentation: any FieldPresenting<T>
        ) -> Self {
            .init(representation: .field(
                metadata,
                id: metadata.id,
                ui: fieldRecord(presentation: presentation, binding: binding)
            ))
        }
        
        public static func field<T>(
            binding: any ValueBinding<T>,
            metadata: Metadata
        ) -> Self where T: CustomFieldPresentable {
            .field(
                binding,
                metadata: metadata,
                ui: T.preferredPresentation
            )
        }

        fileprivate private(set) var representation: FormModel.Record
        
        fileprivate init(representation: FormModel.Record) {
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
    /// resultBuilder type used in building models
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
