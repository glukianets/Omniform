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
    
    fileprivate enum Record: Identifiable, Equatable {
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
        
        public static func ==(lhs: FormModel.Record, rhs: FormModel.Record) -> Bool {
            switch (lhs, rhs) {
            case (.field(let lhsMetadata, let lhsId, _), .field(let rhsMetadata, id: let rhsId, ui: _)):
                return lhsMetadata == rhsMetadata && lhsId == rhsId
            case (.group(let lhsModel, let lhsId, _), .group(let rhsModel, id: let rhsId, ui: _)):
                return lhsModel == rhsModel && lhsId == rhsId
            default:
                return false
            }
        }
    }
    
    private static let cache = MirrorCache()
    
    /// This form's metadata
    public var metadata: Metadata {
        get { self.guts.header.metadata }
        set { self.ensureUniqueness(); self.guts.header.metadata = newValue }
    }

    private var guts: Guts
    
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
        id: AnyHashable? = nil,
        name: Metadata.Text? = nil,
        icon: Metadata.Image? = nil,
        @Builder builder: () -> Prototype
    ) {
        let metadata = Metadata(type: FormModel.self, id: id ?? AnyHashable(Member.NoID()), name: name, icon: icon)
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
            let metadata = Metadata(type: S.self, id: ObjectIdentifier(S.self), externalName: String(describing: S.self))
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

    private init(metadata: Metadata, members: some Sequence<Member>) {
        self.init(guts: .create(
            metadata: metadata.with(id: metadata.id is Member.NoID ? UUID() : metadata.id),
            members: members.enumerated().map { i, m in m.with(id: i) }.map(\.representation)
        ))
    }
    
    private init(guts: Guts) {
        self.guts = guts
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
        self.guts.lazy.map { record in
            switch record {
            case .group(let model, id: let id, ui: let trampoline):
                return trampoline.visit(group: model, id: id, builder: visitor)
            case .field(let field, id: let id, ui: let trampoline):
                return trampoline.visit(field: field, id: id, builder: visitor)
            }
        }
    }
    
    /// Creates a new form applying transform
    ///
    /// - Parameter transform: object that builds form fields and, subsequentially, the entire form.
    /// - Returns: a new form
    public func applying(transform: some FormTransforming) throws -> Self {
        try transform.build(metadata: self.metadata, fields: self.fields(using: transform))
    }

    private mutating func ensureUniqueness() {
        guard !isKnownUniquelyReferenced(&self.guts) else { return }
        self = Self.init(guts: self.guts.clone())
    }
}

extension FormModel: CustomFormPresentable {
    public static func formModel(for binding: some ValueBinding<Self>) -> FormModel {
        binding.value
    }
}

extension FormModel: CustomFieldFormattable {
    public typealias FormatStyle = AnyFormatStyle<Self, String>
    
    @available(iOS 15.0, *)
    public static var preferredFormatStyle: AnyFormatStyle<FormModel, String> {
        AnyFormatStyle<Self, String>.dynamic { _ in "" }
    }
}

extension FormModel: Identifiable {
    public var id: AnyHashable { self.metadata.id }
}

extension FormModel: Equatable {
    public static func ==(lhs: Self, rhs: Self) -> Bool {
        // TODO: Proper model equality
        false
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
        
        let members = self.guts.map { record in
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
        public init(members: some Collection<Member>) {
            self.members = Array(members)
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
        
        public static func group<T>(
            metadata: Metadata,
            ui presentation: some GroupPresenting<T>,
            binding: any ValueBinding<T>,
            @Builder _ builder: () -> Prototype
        ) -> Self {
            .group(
                ui: presentation,
                binding: binding,
                model: FormModel(metadata: metadata, builder: builder)
            )
        }
        
        public static func group<T>(
            id: AnyHashable? = nil,
            name: Metadata.Text? = nil,
            icon: Metadata.Image? = nil,
            ui presentation: some GroupPresenting<T>,
            binding: any ValueBinding<T>,
            @Builder _ builder: () -> Prototype
        ) -> Self {
            self.group(
                metadata: Metadata(type: T.self, id: id ?? .noId, name: name, icon: icon),
                ui: presentation,
                binding: binding,
                builder
            )
        }
        
        public static func group<T>(
            metadata: Metadata,
            ui presentation: some GroupPresenting<T>,
            binding: any ValueBinding<T>
        ) -> Self {
            groupRecord(presentation: presentation, binding: binding)
                .member(metadata: metadata)
        }
        
        public static func group<T>(
            id: AnyHashable? = nil,
            name: Metadata.Text? = nil,
            icon: Metadata.Image? = nil,
            ui presentation: some GroupPresenting<T>,
            binding: any ValueBinding<T>
        ) -> Self {
            self.group(
                metadata: .init(type: T.self, id: id ?? .noId, name: name, icon: icon),
                ui: presentation,
                binding: binding
            )
        }
        
        public static func group(
            ui presentation: some GroupPresenting<Void>,
            model: FormModel
        ) -> Self {
            .group(
                ui: presentation,
                binding: bind { Void() },
                model: model
            )
        }
        
        public static func group<T>( // Designated
            ui presentation: some GroupPresenting<T>,
            binding: any ValueBinding<T>,
            model: FormModel
        ) -> Self {
            .init(representation: .group(
                model,
                id: NoID(),
                ui: groupRecord(presentation: presentation, binding: binding)
            ))
        }
        
        public static func field<T>(
            id: AnyHashable? = nil,
            name: Metadata.Text? = nil,
            icon: Metadata.Image? = nil,
            ui presentation: some FieldPresenting<T>,
            binding: any ValueBinding<T>
        ) -> Self {
            .field(
                metadata: Metadata(type: T.self, id: id ?? .noId, name: name, icon: icon),
                ui: presentation,
                binding: binding
            )
        }
        
        public static func field<T>(
            id: AnyHashable? = nil,
            name: Metadata.Text? = nil,
            icon: Metadata.Image? = nil,
            binding: any ValueBinding<T>
        ) -> Self where T: CustomFieldPresentable {
            .field(
                id: id,
                name: name,
                icon: icon,
                ui: T.preferredPresentation,
                binding: binding
            )
        }
        
        public static func field<T>( // Designated
            metadata: Metadata,
            ui presentation: any FieldPresenting<T>,
            binding: any ValueBinding<T>
        ) -> Self {
            fieldRecord(presentation: presentation, binding: binding)
                .member(metadata: metadata)
        }
        
        public static func field<T>(
            metadata: Metadata,
            binding: any ValueBinding<T>
        ) -> Self where T: CustomFieldPresentable {
            .field(
                metadata: metadata,
                ui: T.preferredPresentation,
                binding: binding
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
            component ?? self.buildBlock()
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
        
        public static func buildLimitedAvailability(_ component: Prototype) -> Prototype {
            component
        }
    }
}

// MARK: - FormModelGuts

extension FormModel {
    fileprivate final class Guts: ManagedBuffer<Guts.Header, Record> {
        public struct Header {
            var count: Int
            var metadata: Metadata
        }
        
        public static func create(metadata: Metadata, members: some Collection<Record>) -> Self {
            let buffer = Self.create(minimumCapacity: members.count) { _ in
                Header(count: 0, metadata: metadata)
            } as! Self
            
            buffer.append(members)
            
            return buffer
        }
        
        deinit {
            self.withUnsafeMutablePointers { headerPtr, bodyPtr in
                _ = bodyPtr.deinitialize(count: headerPtr.pointee.count)
            }
        }
        
        public func append(_ members: some Collection<Record>) {
            assert(self.capacity >= self.header.count + members.count, "No capacity left")
            
            self.header.count += members.count
            
            self.withUnsafeMutablePointerToElements { bodyPtr in
                guard members.withContiguousStorageIfAvailable({ buffer in
                    bodyPtr.initialize(from: buffer.baseAddress!, count: buffer.count)
                }) == nil else { return }
                
                members.enumerated().forEach { i, e in (bodyPtr + i).initialize(to: e) }
            }
        }
        
        public func clone() -> Self {
            Self.create(metadata: self.header.metadata, members: self)
        }
    }
}

extension FormModel.Guts: RandomAccessCollection & MutableCollection {
    typealias Element = FormModel.Record
    typealias Index = Int

    var startIndex: Int { 0 }
    var endIndex: Int { self.header.count }

    subscript(position: Int) -> FormModel.Record {
        get {
            assert(self.indices.contains(position), "Index \(position) is out of range \(self.indices)")
            return self.withUnsafeMutablePointerToElements { ($0 + position).pointee }
        }
        set {
            assert(self.indices.contains(position), "Index \(position) is out of range \(self.indices)")
            return self.withUnsafeMutablePointerToElements { ($0 + position).pointee = newValue }
        }
    }
    
    func withContiguousStorageIfAvailable<R>(
        _ body: (UnsafeBufferPointer<FormModel.Record>) throws -> R
    ) rethrows -> R? {
        try self.withUnsafeMutablePointers { headerPtr, bodyPtr in
            try body(UnsafeBufferPointer(start: bodyPtr, count: headerPtr.pointee.count))
        }
    }
    
    func withContiguousMutableStorageIfAvailable<R>(
        _ body: (inout UnsafeMutableBufferPointer<FormModel.Record>) throws -> R
    ) rethrows -> R? {
        try self.withUnsafeMutablePointers { headerPtr, bodyPtr in
            var bufferPtr = UnsafeMutableBufferPointer(start: bodyPtr, count: headerPtr.pointee.count) {
                didSet { assertionFailure("Buffer must not be replaced") }
            }
            return try body(&bufferPtr)
        }
    }
}

fileprivate extension AnyHashable {
    static var noId: Self {
        FormModel.Member.NoID()
    }
}
