import Foundation
import CoreGraphics

// MARK: - FieldIcon

public struct FieldIcon: ExpressibleByStringLiteral, Equatable {
    public enum Orientation: Equatable {
        case up(mirrored: Bool = false)
        case down(mirrored: Bool = false)
        case left(mirrored: Bool = false)
        case right(mirrored: Bool = false)
    }
    
    private enum Representation: Equatable {
        case system(name: String, value: Double?)
        case custom(name: String, bundle: Bundle?, value: Double?)
        case native(image: CGImage, scale: CGFloat, orientation: Orientation)
    }
    
    public static func system<S: StringProtocol>(_ name: S, value: Double? = nil) -> Self {
        .init(.system(name: String(name), value: value))
    }

    public static func custom<S: StringProtocol>(_ name: S, value: Double? = nil, bundle: Bundle? = nil) -> Self {
        .init(.custom(name: String(name), bundle: bundle, value: value))
    }
    
    public static func native(cgImage: CGImage, scale: CGFloat = 1.0, orientation: Orientation = .up()) -> Self {
        .init(.native(image: cgImage, scale: scale, orientation: orientation))
    }
    
    private let representation: Representation

    public init(stringLiteral value: String) {
        self = .custom(value)
    }

    private init(_ representation: Representation) {
        self.representation = representation
    }
}

// MARK: - FieldName

public struct FieldName: ExpressibleByStringLiteral, CustomStringConvertible, Equatable {
    public struct Options: OptionSet {
        public static var localizable = Self(rawValue: 1 << 1)
        public static var formattable = Self(rawValue: 1 << 2)
        
        public var rawValue: UInt8

        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }
    }
    
    public var description: String { self.value }
    private let value: String
    private var Bundle: Bundle?
    private let options: Options

    public init<S: StringProtocol>(_ value: S, bundle: Bundle? = nil, options: Options = [.localizable]) {
        self.value = String(value)
        self.Bundle = bundle
        self.options = options
    }

    public init(stringLiteral value: String) {
        self.init(value)
    }
}
