import Foundation
import CoreGraphics

public struct Metadata: Equatable {
    public let type: Any.Type
    public let id: AnyHashable
    public let name: Metadata.Name?
    public let icon: Metadata.Icon?
    public let externalName: String?
    public let tags: Set<AnyHashable>
    
    internal init(
        type: Any.Type,
        id: AnyHashable,
        name: Metadata.Name? = nil,
        icon: Metadata.Icon? = nil,
        externalName: String? = nil,
        tags: Set<AnyHashable> = []
    ) {
        self.type = type
        self.id = id
        self.name = name ?? (externalName?.dropPrefix("_").humanReadable).map(Metadata.Name.verbatim(_:))
        self.icon = icon
        self.externalName = externalName
        self.tags = tags
        print(self)
    }
    
    internal func with(
        type: Any.Type? = nil,
        id: AnyHashable? = nil,
        name: Metadata.Name?? = .none,
        icon: Metadata.Icon?? = .none,
        externalName: String?? = .none
    ) -> Self {
        .init(
            type: type ?? self.type,
            id: id ?? self.id,
            name: name ?? self.name,
            icon: icon ?? self.icon,
            externalName: externalName ?? self.externalName
        )
    }
    
    public static func == (lhs: Metadata, rhs: Metadata) -> Bool {
        return lhs.type == rhs.type
        && lhs.name == rhs.name
        && lhs.icon == rhs.icon
        && lhs.externalName == rhs.externalName
    }
}

internal struct SurrogateMetadata: Equatable {
    public var type: Any.Type
    public var name: Metadata.Name?
    public var icon: Metadata.Icon?
    public var tags: Set<AnyHashable>
    
    internal init(type: Any.Type, name: Metadata.Name? = nil, icon: Metadata.Icon? = nil, tags: AnyHashable...) {
        self.type = type
        self.name = name
        self.icon = icon
        self.tags = Set(tags)
    }
    
    internal func with(id: AnyHashable, externalName: String? = nil) -> Metadata {
        .init(type: self.type, id: id, name: self.name, externalName: externalName)
    }
    
    public static func == (lhs: SurrogateMetadata, rhs: SurrogateMetadata) -> Bool {
        lhs.type == rhs.type
    }
}

// MARK: - FieldIcon

extension Metadata {
    public enum Icon: ExpressibleByStringLiteral, Equatable {
        public enum Orientation: Equatable {
            case up(mirrored: Bool = false)
            case down(mirrored: Bool = false)
            case left(mirrored: Bool = false)
            case right(mirrored: Bool = false)
        }
        
        public struct System: Equatable {
            public let name: String
            public let value: Double?
        }
        
        public struct Custom: Equatable {
            public let name: String
            public let bundle: Bundle?
            public let value: Double?
        }
        
        public struct Native: Equatable {
            public let image: CGImage
            public let scale: CGFloat
            public let orientation: Orientation
        }
        
        case system(System)
        case custom(Custom)
        case native(Native)

        public static func system<S: StringProtocol>(_ name: S, value: Double? = nil) -> Self {
            .system(.init(name: String(name), value: value))
        }

        public static func custom<S: StringProtocol>(_ name: S, value: Double? = nil, bundle: Bundle? = nil) -> Self {
            .custom(.init(name: String(name), bundle: bundle, value: value))
        }
        
        public static func native(cgImage: CGImage, scale: CGFloat = 1.0, orientation: Orientation = .up()) -> Self {
            .native(.init(image: cgImage, scale: scale, orientation: orientation))
        }
        
        public init(stringLiteral value: String) {
            self = .custom(value)
        }
    }
}

// MARK: - FieldName

extension Metadata {
    public enum Name: ExpressibleByStringLiteral, CustomStringConvertible, Equatable {
        public struct Options: OptionSet {
            public static var localizable = Self(rawValue: 1 << 1)
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

        public static func verbatim<S: StringProtocol>(_ value: S) -> Self {
            .text(.init(key: String(value), table: nil, bundle: nil, options: []))
        }
        
        public static func format<S: StringProtocol>(_ format: S) -> Self {
            .text(.init(key: String(format), table: nil, bundle: nil, options: [.formattable]))
        }
        
        public static func localizable<S: StringProtocol>(_ key: S, table: String? = nil, bundle: Bundle? = nil) -> Self {
            .text(.init(key: String(key), table: table, bundle: bundle, options: [.localizable]))
        }

        public static func localizableFormat<S: StringProtocol>(_ formatKey: S, table: String? = nil, bundle: Bundle? = nil) -> Self {
            .text(.init(key: String(formatKey), table: table, bundle: bundle, options: [.localizable, .formattable]))
        }

        public init(stringLiteral value: String) {
            self = .localizable(value)
        }
    }
}
