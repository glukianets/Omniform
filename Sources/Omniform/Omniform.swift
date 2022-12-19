import Foundation

// MARK: - PropertyWrapper

/// A typpe that acts as a read-only property wrapper
public protocol PropertyWrapper {
    associatedtype WrappedValue
    
    var wrappedValue: WrappedValue { get }
}

// MARK: - WritablePropertyWrapper

/// A type that acts as a writable property wrapper
public protocol WritablePropertyWrapper: PropertyWrapper {
    var wrappedValue: WrappedValue { get set }
}

// MARK: - FieldVisiting

/// A type that presents ``FormModel`` members in a uniform manner
///
/// See ``FormModel/fields(using:)`` for usage.
public protocol FieldVisiting<Result> {
    associatedtype Result
    
    func visit<Value>(
        field: Metadata,
        id: AnyHashable,
        using presentation: some FieldPresenting<Value>,
        through binding: some ValueBinding<Value>
    ) -> Result
    
    func visit<Value>(
        group: FormModel,
        id: AnyHashable,
        using presentation: some GroupPresenting<Value>,
        through binding: some ValueBinding<Value>
    ) -> Result
}

// MARK: - FormTransforming

/// A type that applies certain transformations to ``FormModel``
///
/// See ``FormModel/applying(tranform:)`` for usage.
public protocol FormTransforming: FieldVisiting {
    func build(metadata: Metadata, fields: some Collection<Result>) throws -> FormModel
}

extension FormTransforming {
    public func build(metadata: Metadata, fields: some Collection<Result>) -> FormModel
    where Result == FormModel.Member {
        FormModel(metadata: metadata, prototype: .init(members: fields))
    }
    
    public func build(metadata: Metadata, fields: some Collection<Result>) -> FormModel
    where Result: Collection<FormModel.Member> {
        FormModel(metadata: metadata, prototype: .init(members: fields.flatMap { $0 }))
    }
    
    public func build(metadata: Metadata, fields: some Collection<Result>) -> FormModel
    where Result == FormModel.Member? {
        FormModel(metadata: metadata, prototype: .init(members: fields.compactMap { $0 }))
    }
}

// MARK: - CustomFormPresentable

/// A type that has customized ``FormModel`` representatoin
public protocol CustomFormPresentable: CustomFieldPresentable {
    static func formModel(for binding: some ValueBinding<Self>) -> FormModel
}

extension CustomFormPresentable {
    public static var preferredPresentation: Presentations.Group<Self> {
        .section()
    }
}

extension CustomFormPresentable where Self: CustomFormBuilding {
    public static func formModel(for binding: some ValueBinding<Self>) -> FormModel {
        let builder: () -> FormModel.Prototype = { self.buildForm(binding) }
        return FormModel(id: ObjectIdentifier(Self.self), name: self.formName, icon: self.formIcon, builder: builder)
    }
}

// MARK: - CustomFormBuilding

/// A type that builds its own custom ``FormModel`` representation
///
/// Conform to this protocol instead of ``CustomFieldPresentable`` when you only
/// want to adjust a few separate things about how your type is presented as form
public protocol CustomFormBuilding: CustomFormPresentable {
    static var formName: Metadata.Text? { get }
    static var formIcon: Metadata.Image? { get }
    
    @FormModel.Builder
    static func buildForm(_ binding: some ValueBinding<Self>) -> FormModel.Prototype
}

extension CustomFormBuilding {
    public static var formName: Metadata.Text? {
        .runtime(self)
    }
    
    public static var formIcon: Metadata.Image? {
        nil
    }
    
    public static func buildForm(_ binding: some ValueBinding<Self>) -> FormModel.Prototype {
        .init(reflecting: binding)
    }
}

// MARK: - FieldPresentable

/// A type that is presentable inside ``FormModel``
///
/// ``FormModel`` will recognize properties of this type as viable fields even
/// when they're not marked with ``Field`` property wrapper
public protocol CustomFieldPresentable {
    associatedtype PreferredPresentation: FieldPresenting<Self>
    
    /// Presentation that is used when none other is specified
    static var preferredPresentation: PreferredPresentation { get }
}

/// A type that is presentable inside ``FormModel`` as formatted display
@available(iOS 15, macOS 13, *)
public protocol CustomFieldFormattable {
    associatedtype FormatStyle: Foundation.FormatStyle
    where FormatStyle.FormatInput == Self, FormatStyle.FormatOutput == String
    
    /// Format used when presenting in formatted context, like .display() presentation
    static var preferredFormatStyle: FormatStyle { get }
}

extension Bool: CustomFieldPresentable {
    public static var preferredPresentation: some FieldPresenting<Self> {
        .toggle
    }
}

extension String: CustomFieldPresentable {
    public static var preferredPresentation: some FieldPresenting<Self> {
        .input()
    }
}

extension Character: CustomFieldPresentable {
    public static var preferredPresentation: some FieldPresenting<Self> {
        .input()
    }
}

extension Float: CustomFieldPresentable {
    public static var preferredPresentation: some FieldPresenting<Self> {
        .input()
    }
}

extension Double: CustomFieldPresentable {
    public static var preferredPresentation: some FieldPresenting<Self> {
        .input()
    }
}

extension Int: CustomFieldPresentable {
    public static var preferredPresentation: some FieldPresenting<Self> {
        .input()
    }
}

extension Int8: CustomFieldPresentable {
    public static var preferredPresentation: some FieldPresenting<Self> {
        .input()
    }
}

extension Int16: CustomFieldPresentable {
    public static var preferredPresentation: some FieldPresenting<Self> {
        .input()
    }
}

extension Int32: CustomFieldPresentable {
    public static var preferredPresentation: some FieldPresenting<Self> {
        .input()
    }
}

extension Int64: CustomFieldPresentable {
    public static var preferredPresentation: some FieldPresenting<Self> {
        .input()
    }
}

extension UInt: CustomFieldPresentable {
    public static var preferredPresentation: some FieldPresenting<Self> {
        .input()
    }
}

extension UInt8: CustomFieldPresentable {
    public static var preferredPresentation: some FieldPresenting<Self> {
        .input()
    }
}

extension UInt16: CustomFieldPresentable {
    public static var preferredPresentation: some FieldPresenting<Self> {
        .input()
    }
}

extension UInt32: CustomFieldPresentable {
    public static var preferredPresentation: some FieldPresenting<Self> {
        .input()
    }
}

extension UInt64: CustomFieldPresentable {
    public static var preferredPresentation: some FieldPresenting<Self> {
        .input()
    }
}

extension Date: CustomFieldPresentable {
    public static var preferredPresentation: some FieldPresenting<Self> {
        .picker()
    }
}

@available(iOS 16.0, macOS 13, *)
extension URL: CustomFieldPresentable {
    public static var preferredPresentation: some FieldPresenting<Self> {
        .input(format: .url)
    }
}

extension Optional: CustomFieldPresentable where Wrapped: CustomFieldPresentable & Equatable & _DefaultInitializable {
    public static var preferredPresentation: Presentations.Nullified<Self, Wrapped.PreferredPresentation> {
        Wrapped.preferredPresentation.nullifying(when: Wrapped.init())
    }
}

extension CustomFieldPresentable where Self: Hashable & CaseIterable {
    public static var preferredPresentation: Presentations.Picker<Self> {
        .picker()
    }
}

// MARK: - _DefaultInitializable

public protocol _DefaultInitializable {
    init()
}

extension _DefaultInitializable where Self: ExpressibleByNilLiteral {
    public init() {
        self = nil
    }
}

extension Bool: _DefaultInitializable { }

extension String: _DefaultInitializable { }

extension Float: _DefaultInitializable { }

extension Double: _DefaultInitializable { }

extension Int: _DefaultInitializable { }

extension Int8: _DefaultInitializable { }

extension Int16: _DefaultInitializable { }

extension Int32: _DefaultInitializable { }

extension Int64: _DefaultInitializable { }

extension UInt: _DefaultInitializable { }

extension UInt8: _DefaultInitializable { }

extension UInt16: _DefaultInitializable { }

extension UInt32: _DefaultInitializable { }

extension UInt64: _DefaultInitializable { }

extension Optional: _DefaultInitializable { }
