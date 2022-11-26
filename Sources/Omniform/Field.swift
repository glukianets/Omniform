import Foundation

internal protocol FieldProtocol: WritablePropertyWrapper {
    var metadata: SurrogateMetadata { get }
  
    var presentation: any FieldPresenting<Self.WrappedValue> { get }
}

/// A property wrapper type that marks property as part of a dynamic form.
/// You can use it to customize part of a dynamic form generated for the property it was applied to.
@propertyWrapper
public struct Field<WrappedValue>: FieldProtocol {
    public var wrappedValue: WrappedValue
    internal let metadata: SurrogateMetadata
    internal let presentation: any FieldPresenting<WrappedValue>
    
    /// Creates the property wrapper with set name, icon, presentation and tags
    /// - Parameters:
    ///   - wrappedValue: The initial value of the underlying property
    ///   - name: Display name used for the field
    ///   - icon: Image used as Icon for the field
    ///   - ui: Presentation of the field: kind of ui used to edit the field
    ///   - tags: Arbitrary tag values
    public init(
        wrappedValue: WrappedValue,
        name: Metadata.Text? = nil,
        icon: Metadata.Image? = nil,
        ui presentation: some FieldPresenting<WrappedValue>,
        tags: AnyHashable...
    ) {
        self.wrappedValue = wrappedValue
        self.presentation = presentation
        self.metadata = .init(type: Self.self, name: name, icon: icon, tags: tags)
    }
}

extension Field {
    /// Creates the property wrapper with set name, icon, and tags, using default presentation provided for thy type
    /// - Parameters:
    ///   - name: Display name used for the field
    ///   - icon: Image used as Icon for the field
    ///   - tags: Arbitrary tag values
    @inlinable
    public init(
        name: Metadata.Text? = nil,
        icon: Metadata.Image? = nil,
        tags: AnyHashable...
    ) where WrappedValue: CustomFieldPresentable, WrappedValue: _DefaultInitializable {
        self.init(
            wrappedValue: .init(),
            name: name,
            icon: icon,
            ui: WrappedValue.preferredPresentation,
            tags: tags
        )
    }
    
    /// Creates the property wrapper with set name, icon, and tags, using default presentation provided for thy type
    /// - Parameters:
    ///   - wrappedValue: The initial value of the underlying property
    ///   - name: Display name used for the field
    ///   - icon: Image used as Icon for the field
    ///   - tags: Arbitrary tag values
    @inlinable
    public init(
        wrappedValue: WrappedValue,
        name: Metadata.Text? = nil,
        icon: Metadata.Image? = nil,
        tags: AnyHashable...
    ) where WrappedValue: CustomFieldPresentable {
        self.init(
            wrappedValue: wrappedValue,
            name: name,
            icon: icon,
            ui: WrappedValue.preferredPresentation,
            tags: tags
        )
    }
    
    /// Creates the property wrapper with set name, icon, presentation and tags
    /// - Parameters:
    ///   - name: Display name used for the field
    ///   - icon: Image used as Icon for the field
    ///   - ui: Presentation of the field: kind of ui used to edit the field
    ///   - tags: Arbitrary tag values
    @inlinable
    public init(
        name: Metadata.Text? = nil,
        icon: Metadata.Image? = nil,
        ui presentation: some FieldPresenting<WrappedValue>,
        tags: AnyHashable...
    ) where WrappedValue: _DefaultInitializable {
        self.init(
            wrappedValue: .init(),
            name: name,
            icon: icon,
            ui: presentation,
            tags: tags
        )
    }
}

extension Field {
    /// Creates the property wrapper with set name, icon and tags, using default presentation and targeting nested value
    /// - Parameters:
    ///   - wrappedValue: The initial value of the underlying property
    ///   - name: Display name used for the field
    ///   - icon: Image used as Icon for the field
    ///   - tags: Arbitrary tag values
    @inlinable
    public init(
        wrappedValue: WrappedValue,
        name: Metadata.Text? = nil,
        icon: Metadata.Image? = nil,
        tags: AnyHashable...
    ) where
        WrappedValue: PropertyWrapper,
        WrappedValue.WrappedValue: CustomFieldPresentable
    {
        self.init(
            wrappedValue: wrappedValue,
            name: name,
            icon: icon,
            ui: WrappedValue.WrappedValue.preferredPresentation.lifting(
                through: \.wrappedValue
            ),
            tags: tags
        )
    }
    
    /// Creates the property wrapper with set name, icon presentation and tags, and targeting nested value
    /// - Parameters:
    ///   - wrappedValue: The initial value of the underlying property
    ///   - name: Display name used for the field
    ///   - icon: Image used as Icon for the field
    ///   - ui: Presentation of the field: kind of ui used to edit the field
    ///   - tags: Arbitrary tag values
    @inlinable
    public init(
        wrappedValue: WrappedValue,
        name: Metadata.Text? = nil,
        icon: Metadata.Image? = nil,
        ui presentation: some FieldPresenting<WrappedValue.WrappedValue>,
        tags: AnyHashable...
    ) where
        WrappedValue: PropertyWrapper
    {
        self.init(
            wrappedValue: wrappedValue,
            name: name,
            icon: icon,
            ui: presentation.lifting(
                through: \WrappedValue.wrappedValue
            ),
            tags: tags
        )
    }
    
    /// Creates the property wrapper with set name, icon and tags, using default presentation and targeting nested value
    /// - Parameters:
    ///   - wrappedValue: The initial value of the underlying property
    ///   - name: Display name used for the field
    ///   - icon: Image used as Icon for the field
    ///   - tags: Arbitrary tag values
    @inlinable
    public init(
        wrappedValue: WrappedValue,
        name: Metadata.Text? = nil,
        icon: Metadata.Image? = nil,
        tags: AnyHashable...
    ) where
        WrappedValue: WritablePropertyWrapper,
        WrappedValue.WrappedValue: CustomFieldPresentable
    {
        self.init(
            wrappedValue: wrappedValue,
            name: name,
            icon: icon,
            ui: WrappedValue.WrappedValue.preferredPresentation.lifting(through: \.wrappedValue),
            tags: tags
        )
    }
    
    /// Creates the property wrapper with set name, icon, presentation and tags and targeting nested value
    /// - Parameters:
    ///   - wrappedValue: The initial value of the underlying property
    ///   - name: Display name used for the field
    ///   - icon: Image used as Icon for the field
    ///   - ui: Presentation of the field: kind of ui used to edit the field
    ///   - tags: Arbitrary tag values
    @inlinable
    public init(
        wrappedValue: WrappedValue,
        name: Metadata.Text? = nil,
        icon: Metadata.Image? = nil,
        ui presentation: some FieldPresenting<WrappedValue.WrappedValue>,
        tags: AnyHashable...
    ) where
        WrappedValue: WritablePropertyWrapper
    {
        self.init(
            wrappedValue: wrappedValue,
            name: name,
            icon: icon,
            ui: presentation.lifting(
                through: \WrappedValue.wrappedValue as WritableKeyPath<WrappedValue, WrappedValue.WrappedValue>
            ),
            tags: tags
        )
    }
}

extension Field {
    /// Creates the property wrapper with set name, icon and tags, using default presentation and targeting nested value
    /// - Parameters:
    ///   - wrappedValue: The initial value of the underlying property
    ///   - name: Display name used for the field
    ///   - icon: Image used as Icon for the field
    ///   - tags: Arbitrary tag values
    @inlinable
    public init(
        wrappedValue: WrappedValue,
        name: Metadata.Text? = nil,
        icon: Metadata.Image? = nil,
        tags: AnyHashable...
    ) where
        WrappedValue: PropertyWrapper,
        WrappedValue.WrappedValue: PropertyWrapper,
        WrappedValue.WrappedValue.WrappedValue: CustomFieldPresentable
    {
        self.init(
            wrappedValue: wrappedValue,
            name: name,
            icon: icon,
            ui: WrappedValue.WrappedValue.WrappedValue.preferredPresentation.lifting(through: \.wrappedValue.wrappedValue),
            tags: tags
        )
    }

    /// Creates the property wrapper with set name, icon presentation and tags, and targeting nested value
    /// - Parameters:
    ///   - wrappedValue: The initial value of the underlying property
    ///   - name: Display name used for the field
    ///   - icon: Image used as Icon for the field
    ///   - ui: Presentation of the field: kind of ui used to edit the field
    ///   - tags: Arbitrary tag values
    @inlinable
    public init(
        wrappedValue: WrappedValue,
        name: Metadata.Text? = nil,
        icon: Metadata.Image? = nil,
        ui presentation: some FieldPresenting<WrappedValue.WrappedValue.WrappedValue>,
        tags: AnyHashable...
    ) where
        WrappedValue: PropertyWrapper,
        WrappedValue.WrappedValue: PropertyWrapper
    {
        self.init(
            wrappedValue: wrappedValue,
            name: name,
            icon: icon,
            ui: presentation.lifting(
                through: \WrappedValue.wrappedValue.wrappedValue
            ),
            tags: tags
        )
    }
    
    /// Creates the property wrapper with set name, icon and tags, using default presentation and targeting nested value
    /// - Parameters:
    ///   - wrappedValue: The initial value of the underlying property
    ///   - name: Display name used for the field
    ///   - icon: Image used as Icon for the field
    ///   - tags: Arbitrary tag values
    @inlinable
    public init(
        wrappedValue: WrappedValue,
        name: Metadata.Text? = nil,
        icon: Metadata.Image? = nil,
        tags: AnyHashable...
    ) where
        WrappedValue: WritablePropertyWrapper,
        WrappedValue.WrappedValue: WritablePropertyWrapper,
        WrappedValue.WrappedValue.WrappedValue: CustomFieldPresentable
    {
        self.init(
            wrappedValue: wrappedValue,
            name: name,
            icon: icon,
            ui: WrappedValue.WrappedValue.WrappedValue.preferredPresentation.lifting(through: \.wrappedValue.wrappedValue),
            tags: tags
        )
    }

    /// Creates the property wrapper with set name, icon, presentation and tags and targeting nested value
    /// - Parameters:
    ///   - wrappedValue: The initial value of the underlying property
    ///   - name: Display name used for the field
    ///   - icon: Image used as Icon for the field
    ///   - ui: Presentation of the field: kind of ui used to edit the field
    ///   - tags: Arbitrary tag values
    @inlinable
    public init(
        wrappedValue: WrappedValue,
        name: Metadata.Text? = nil,
        icon: Metadata.Image? = nil,
        ui presentation: some FieldPresenting<WrappedValue.WrappedValue.WrappedValue>,
        tags: AnyHashable...
    ) where
        WrappedValue: WritablePropertyWrapper,
        WrappedValue.WrappedValue: WritablePropertyWrapper
    {
        self.init(
            wrappedValue: wrappedValue,
            name: name,
            icon: icon,
            ui: presentation.lifting(
                through: \WrappedValue.wrappedValue.wrappedValue as WritableKeyPath<WrappedValue, WrappedValue.WrappedValue.WrappedValue>
            ),
            tags: tags
        )
    }
}
