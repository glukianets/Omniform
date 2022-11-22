import Foundation
import SwiftUI

// MARK: - OmniformPresentation

public struct OmniformPresentation: Equatable {
    internal enum PresentationKind {
        case standalone
        case navigation
    }
    
    public static var standalone: Self = Self(kind: .standalone)
    public static var navigation: Self = Self(kind: .navigation)

    internal let kind: PresentationKind
}

private struct OmniformPresentationEnvironmentKey: EnvironmentKey {
    static let defaultValue: OmniformPresentation = .standalone
}

internal extension EnvironmentValues {
    var omniformPresentation: OmniformPresentation {
        get { self[OmniformPresentationEnvironmentKey.self] }
        set { self[OmniformPresentationEnvironmentKey.self] = newValue }
    }
}

public extension View {
    func omniformPresentation(_ kind: OmniformPresentation) -> some View {
        self.environment(\.omniformPresentation, kind)
    }
}

// MARK: - OmniformResourceResolving

public protocol OmniformResourceResolving {
    func image(_ icon: Metadata.Image, value: some Any) -> Image
    func text(_ string: Metadata.Text, value: some Any) -> Text
}

public extension OmniformResourceResolving {
    func image(_ icon: Metadata.Image, value: some Any) -> Image {
        switch icon {
        case .system(let content):
            if #available(iOS 16.0, *) {
                return Image(systemName: content.name, variableValue: content.value)
            } else {
                return Image(systemName: content.name)
            }
        case .custom(let content):
            if #available(iOS 16.0, *) {
                return Image(decorative: content.name, variableValue: content.value)
            } else {
                return Image(decorative: content.name)
            }
        case .native(let content):
            return Image(decorative: content.image, scale: content.scale, orientation: content.orientation.swiftUI)
        }
    }
    
    func text(_ string: Metadata.Text, value: some Any) -> Text {
        switch string {
        case .text(let content):
            var result: String
            if content.options.contains(.localizable) {
                result = NSLocalizedString(
                    content.key,
                    tableName: content.table,
                    bundle: content.bundle ?? .main,
                    comment: content.key
                )
            } else {
                result = content.key
            }
            
            if content.options.contains([.formattable, .localizable]) {
                result = String.localizedStringWithFormat(result, [value])
            } else if content.options.contains([.formattable]) {
                result = String(format: result, [value])
            }

            return Text(verbatim: result)
        }
    }
}

private struct OmniformResourceResolvingEnvironmentKey: EnvironmentKey {
    static let defaultValue: any OmniformResourceResolving = OmniformResourceResolver()
}

public extension EnvironmentValues {
    var omniformResourceResolver: any OmniformResourceResolving {
        get { self[OmniformResourceResolvingEnvironmentKey.self] }
        set { self[OmniformResourceResolvingEnvironmentKey.self] = newValue }
    }
}

public extension View {
    func omniformResourceResolver(_ value: any OmniformResourceResolving) -> some View {
        self.environment(\.omniformResourceResolver, value)
    }
}

private struct OmniformResourceResolver: OmniformResourceResolving { }

private extension Metadata.Image.Orientation {
    var swiftUI: Image.Orientation {
        switch self {
        case .up(false):
            return .up
        case .up(true):
            return .upMirrored
        case .down(false):
            return .down
        case .down(true):
            return .downMirrored
        case .left(false):
            return .left
        case .left(true):
            return .leftMirrored
        case .right(false):
            return .right
        case .right(true):
            return .rightMirrored
        }
    }
}


// MARK: - OmniformStyleEnvironmentKey

private struct OmniformStyleEnvironmentKey: EnvironmentKey {
    static let defaultValue: any OmniformStyle = .settings()
}

public extension EnvironmentValues {
    var omniformStyle: any OmniformStyle {
        get { self[OmniformStyleEnvironmentKey.self] }
        set { self[OmniformStyleEnvironmentKey.self] = newValue }
    }
}

public extension View {
    func omniformStyle(_ style: some OmniformStyle) -> some View {
        self.environment(\.omniformStyle, style)
    }
}

// MARK: - OmniformStyle

public protocol OmniformStyle {
    associatedtype FieldModifier: ViewModifier
    associatedtype GroupModifier: ViewModifier
    
    var fieldModifier: FieldModifier { get }
    var groupModifier: GroupModifier { get }
}

extension OmniformStyle {
    public static func settings<FM, GM>(fieldModifier: FM, groupModifier: GM) -> Self
    where Self == SettingsOmniformViewStyle<FM, GM>
    {
        .init(fieldModifier: fieldModifier, groupModifier: groupModifier)
    }

    public static func settings<FM>(fieldModifier: FM) -> Self where Self == SettingsOmniformViewStyle<FM, EmptyModifier> {
        .init(fieldModifier: fieldModifier, groupModifier: EmptyModifier())
    }
    
    public static func settings<GM>(groupModifier: GM) -> Self where Self == SettingsOmniformViewStyle<EmptyModifier, GM> {
        .init(fieldModifier: EmptyModifier(), groupModifier: groupModifier)
    }
    
    public static func settings() -> Self where Self == SettingsOmniformViewStyle<EmptyModifier, EmptyModifier> {
        .init(fieldModifier: EmptyModifier(), groupModifier: EmptyModifier())
    }
}

public struct SettingsOmniformViewStyle<FieldModifier: ViewModifier, GroupModifier: ViewModifier>: OmniformStyle {
    public let fieldModifier: FieldModifier
    public let groupModifier: GroupModifier
    
    public init(fieldModifier: FieldModifier, groupModifier: GroupModifier) {
        self.fieldModifier = fieldModifier
        self.groupModifier = groupModifier
    }
}

// MARK: - FieldBuilder

internal typealias ViewElement = (id: AnyHashable, view: AnyView)

private protocol FieldViewBuilding {
    func build(field: Metadata, id: AnyHashable) -> ViewElement
}

private protocol GroupViewBuilding {
    func build<R>(model: FormModel, id: AnyHashable, builder: some FieldVisiting<R>) -> R
}

// TODO: Replace with simple cast for iOS >= 16 & macOS >= 13
private struct Dispatch<P, B, S> where P: FieldPresenting, B: ValueBinding, S: OmniformStyle,  P.Value == B.Value {
    public let presentation: P
    public let binding: B
    public let style: S
}

extension Dispatch: FieldViewBuilding where P: SwiftUIFieldPresenting {
    func build(field: Metadata, id: AnyHashable) -> ViewElement {
        return (id, self.presentation.body(for: field, binding: self.binding, modifier: self.style.fieldModifier).erased)
    }
}

extension Dispatch: GroupViewBuilding where P: SwiftUIFormPresenting {
    func build<R>(model: FormModel, id: AnyHashable, builder: some FieldVisiting<R>) -> R {
        return self.presentation.body(for: model, id: id, builder: builder)
    }
}

internal struct SwiftUIFieldVisitor<Style: OmniformStyle>: FieldVisiting {
    let style: Style
    
    public init(style: Style) {
        self.style = style
    }

    public func visit<Value>(
        field: Metadata,
        id: AnyHashable,
        using presentation: some FieldPresenting<Value>,
        through binding: some ValueBinding<Value>
    ) -> ViewElement {
        if let dd = Dispatch(presentation: presentation, binding: binding, style: self.style) as? FieldViewBuilding {
            return dd.build(field: field, id: id)
        } else {
            return (id, EmptyView().erased)
        }
    }
    
    public func visit<Value>(
        group model: FormModel,
        id: AnyHashable,
        using presentation:
        some FieldPresenting<Value>,
        through binding: some ValueBinding<Value>
    ) -> ViewElement {
        if let dd = Dispatch(presentation: presentation, binding: binding, style: self.style) as? GroupViewBuilding {
            return dd.build(model: model, id: id, builder: self)
        } else {
            return (id, EmptyView().erased)
        }
    }
}

// MARK: - Utility

fileprivate extension SwiftUIFieldPresenting {
    func body(for field: Metadata, binding: some ValueBinding<Value>, modifier: some ViewModifier) -> AnyView {
        self.body(for: field, binding: binding).modifier(modifier).erased
    }
}
