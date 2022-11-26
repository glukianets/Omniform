import Foundation
import CoreGraphics

/// Additional info about form entity
///
/// When Omniform creates dynamic form model, it stores all relevant data about each field inside this structure.
/// This structure is then used by other parts of the framework for different purposes, including building ui
public struct Metadata: Equatable, Identifiable {
    /// Dynamic type of the entity this object refers to.
    /// Should match propety type in most cases, but may differ in few others
    public let type: Any.Type
    
    /// Identity of this field inside the containing form
    public let id: AnyHashable
    
    /// Display name for this field
    public let name: Metadata.Text?

    /// Icon image for this field
    public let icon: Metadata.Image?

    /// Arbitrary tag values used to identify this field
    public let tags: Set<AnyHashable>
    
    internal init(
        type: Any.Type,
        id: AnyHashable,
        name: Metadata.Text? = nil,
        icon: Metadata.Image? = nil,
        externalName: String? = nil,
        tags: Set<AnyHashable> = []
    ) {
        self.type = type
        self.id = id
        self.name = name ?? (externalName?.dropPrefix("_").humanReadable).map(Metadata.Text.verbatim(_:))
        self.icon = icon
        self.tags = tags
    }
    
    internal func with(
        type: Any.Type? = nil,
        id: AnyHashable? = nil,
        name: Metadata.Text?? = .none,
        icon: Metadata.Image?? = .none,
        externalName: String?? = .none
    ) -> Self {
        .init(
            type: type ?? self.type,
            id: id ?? self.id,
            name: name ?? self.name,
            icon: icon ?? self.icon
        )
    }
    
    internal func coalescing(with other: Metadata) -> Self {
        self.with(
            type: other.type,
            id: other.id,
            name: other.name.map { $0 },
            icon: other.icon.map { $0 }
        )
    }
    
    public static func == (lhs: Metadata, rhs: Metadata) -> Bool {
        return lhs.type == rhs.type
        && lhs.name == rhs.name
        && lhs.icon == rhs.icon
    }
}

internal struct SurrogateMetadata: Equatable {
    public var type: Any.Type
    public var name: Metadata.Text?
    public var icon: Metadata.Image?
    public var tags: Set<AnyHashable>
    
    internal init(type: Any.Type, name: Metadata.Text? = nil, icon: Metadata.Image? = nil, tags: AnyHashable...) {
        self.type = type
        self.name = name
        self.icon = icon
        self.tags = Set(tags)
    }
    
    internal func with(id: AnyHashable, externalName: String? = nil) -> Metadata {
        .init(type: self.type, id: id, name: self.name, icon: self.icon, externalName: externalName)
    }
    
    public static func == (lhs: SurrogateMetadata, rhs: SurrogateMetadata) -> Bool {
        lhs.type == rhs.type
    }
}

// MARK: - FieldIcon

extension Metadata {
    /// Image resource
    ///
    /// Values of this type represent images in not yet determined form, like a name to a local resource or url
    public enum Image: ExpressibleByStringLiteral, Equatable {
        public enum Orientation: Equatable {
            case up(mirrored: Bool = false)
            case down(mirrored: Bool = false)
            case left(mirrored: Bool = false)
            case right(mirrored: Bool = false)
        }
        
        /// System image type
        public struct System: Equatable {
            /// Name a the system symbol image, like in `UIImage(systemName:)`
            public let name: String
            /// Numeric value
            public let value: Double?
        }
        
        /// Custom image type
        public struct Custom: Equatable {
            // Name of a local image resource
            public let name: String
            // Bundle containing local image resource
            public let bundle: Bundle?
            // Numeric value
            public let value: Double?
        }
        
        /// Native image type
        public struct Native: Equatable {
            /// CoreGraphics image
            public let image: CGImage
            /// Image scale
            public let scale: CGFloat
            /// Image orientation
            public let orientation: Orientation
        }
        
        case system(System)
        case custom(Custom)
        case native(Native)
        
        /// Creates system symbol image
        /// - Parameters:
        ///   - name: System symbol image name
        ///   - value: Numeric value
        /// - Returns: Metadata image object
        public static func system<S: StringProtocol>(_ name: S, value: Double? = nil) -> Self {
            .system(.init(name: String(name), value: value))
        }
        
        /// Creates custom resource image
        /// - Parameters:
        ///   - name: Local image resource name
        ///   - value: Numeric value
        ///   - bundle: Bundle containing local image
        /// - Returns: Metadata image object
        public static func custom<S: StringProtocol>(_ name: S, value: Double? = nil, bundle: Bundle? = nil) -> Self {
            .custom(.init(name: String(name), bundle: bundle, value: value))
        }
        
        /// Creates native image
        /// - Parameters:
        ///   - cgImage: CoreGraphics image
        ///   - scale: Image render scale
        ///   - orientation: Image orientation
        /// - Returns: Metadata image object
        public static func native(cgImage: CGImage, scale: CGFloat = 1.0, orientation: Orientation = .up()) -> Self {
            .native(.init(image: cgImage, scale: scale, orientation: orientation))
        }
        
        public init(stringLiteral value: String) {
            self = .system(value)
        }
    }
}

// MARK: - FieldName

extension Metadata {
    /// Text string
    ///
    /// Values of this type represent yet-to-be-resolved strings that may be localizable or formattable
    public enum Text: ExpressibleByStringLiteral, ExpressibleByStringInterpolation, CustomStringConvertible, Equatable {
        /// ``Text`` string options
        public struct Options: OptionSet {
            /// When set, ``Metadata/Text`` will be localized before display
            public static var localizable = Self(rawValue: 1 << 1)
            /// When set, ``Metadata/Text`` will be formatted using cocoa format syntax before display
            public static var formattable = Self(rawValue: 1 << 2)
            
            public var rawValue: UInt8

            public init(rawValue: UInt8) {
                self.rawValue = rawValue
            }
        }
        
        public struct Text: Equatable {
            public let key: String
            public let table: String?
            public let bundle: Bundle?
            public let options: Options
        }
        
        case text(Text)
       
        public var description: String {
            switch self {
            case .text(let text):
                return text.key
            }
        }
        
        internal static func runtime<S: StringProtocol>(_ value: S) -> Self {
            .verbatim(String(value).dropPrefix("_").humanReadable)
        }
        
        internal static func runtime<T>(_ type: T.Type) -> Self {
            .runtime(String(describing: type))
        }

        public static func verbatim<S: StringProtocol>(_ value: S) -> Self {
            .text(.init(key: String(value), table: nil, bundle: nil, options: []))
        }
        
        /// Creates fromattable text string
        /// - Parameter format: format string according to
        /// - Returns: ``Text`` object
        public static func format<S: StringProtocol>(_ format: S) -> Self {
            .text(.init(key: String(format), table: nil, bundle: nil, options: [.formattable]))
        }
        
        /// Creates localizable text string
        /// - Parameters:
        ///   - key: localization string table key
        ///   - table: localization string table (default is `Localizable.strings`)
        ///   - bundle: localization string table bundle (default is `main`)
        /// - Returns: ``Text`` object
        public static func localizable<S: StringProtocol>(_ key: S, table: String? = nil, bundle: Bundle? = nil) -> Self {
            .text(.init(key: String(key), table: table, bundle: bundle, options: [.localizable]))
        }
        
        /// Creates localizable format string
        ///
        /// When displayed, its first localized and then formatted according to cocoa format syntax
        /// - Parameters:
        ///   - formatKey: localization string table key
        ///   - table: localization string table (default is `Localizable.strings`)
        ///   - bundle: localization string table bundle (default is `main`)
        /// - Returns: ``Text`` object
        public static func localizableFormat<S: StringProtocol>(_ formatKey: S, table: String? = nil, bundle: Bundle? = nil) -> Self {
            .text(.init(key: String(formatKey), table: table, bundle: bundle, options: [.localizable, .formattable]))
        }
        
        /// Creates localizable strigng.
        /// This has the same effect as calling .localizable(stringLiteral, table: nil, bundle: nil)
        /// - Parameter value: localiztion string key
        public init(stringLiteral value: String) {
            self = .localizable(value)
        }
    }
}
