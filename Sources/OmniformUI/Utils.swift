import Foundation
import SwiftUI

// MARK: - DynamicView

internal struct DynamicView<T: View>: View {
    private let block: () -> T
    
    public init(_ block: @escaping @autoclosure () -> T) {
        self.block = block
    }
    
    public init(@ViewBuilder _ block: @escaping () -> T) {
        self.block = block
    }
    
    public var body: T {
        self.block()
    }
}

internal struct AlwaysRecalculate<Content>: View where Content: View {
    private struct NotEqual: View & Equatable {
        public var body: Content
        
        static func == (lhs: Self, rhs: Self) -> Bool {
            false
        }
    }
    
    private let block: () -> Content
    
    public init(_ block: @escaping @autoclosure () -> Content) {
        self.block = block
    }
    
    public init(@ViewBuilder _ block: @escaping () -> Content) {
        self.block = block
    }
    
    public var body: some View {
        NotEqual(body: self.block()).equatable()
    }
}

// MARK: - scrollDismissesKeyboard

internal enum ScrollDismissesKeyboardMode {
    case automatic, immediately, interactively, never
    
    @available(iOS 16, macOS 13, *)
    internal var nativeValue: SwiftUI.ScrollDismissesKeyboardMode {
        switch self {
        case .automatic:
            return .automatic
        case .immediately:
            return .immediately
        case .interactively:
            return .interactively
        case .never:
            return .never
        }
    }
}

@available(iOS 16, macOS 13, *)
internal struct ScrollDismissesKeyboardModifier: ViewModifier {
    var mode: ScrollDismissesKeyboardMode
    
    func body(content: Content) -> some View {
        content.scrollDismissesKeyboard(self.mode.nativeValue)
    }
}

internal extension View {
    @ViewBuilder
    func scrollDismissesKeyboard(_ mode: ScrollDismissesKeyboardMode) -> some View {
        if #available(iOS 16, macOS 13, *) {
            self.modifier(ScrollDismissesKeyboardModifier(mode: mode))
        } else {
            self
        }
    }
}

// MARK: - View

extension View {
    internal var erased: AnyView {
        if let anyView = self as? AnyView {
            return anyView
        } else {
            return AnyView(self)
        }
    }
    
    internal static var changes: EmptyView {
        if #available(iOS 15.0, *) {
            Self._printChanges()
        }
        return EmptyView()
    }
    
    func modify<Content>(@ViewBuilder _ block: @escaping (Self) -> Content) -> Content {
        block(self)
    }
}

// MARK: - String

internal extension String {
    init<Subject>(optionalyDescribing value: Subject) {
        self = (value as? Any?)?.flatMap { String(describing: $0) } ?? ""
    }
}

// MARK: - Metadata

internal extension Metadata {
    var displayName: String {
        self.name?.description ?? ""
    }
}

// MARK: - Introspect

#if os(iOS)

internal protocol IntrospectionMatching {
    func match<T: UIResponder>(start: UIView, block: (T?) -> Introspection.FlowControl)
}

extension IntrospectionMatching where Self == Introspection.MatchSiblings {
    static var siblings: Self { .init() }
}

extension IntrospectionMatching where Self == Introspection.MatchResponderChain {
    static var responderChain: Self { .init() }
}

extension IntrospectionMatching where Self == Introspection.MatchPresentingHierarchy {
    static var presentingHierarchy: Self { .init() }
}

internal enum Introspection {
    public enum FlowControl {
        case `break`, `continue`
    }

    public struct MatchResponderChain: IntrospectionMatching {
        public func match<T: UIResponder>(start: UIView, block: (T?) -> Introspection.FlowControl) {
            var current: UIResponder = start
            while let next = current.next {
                current = next
                switch (next as? T).map(block) {
                case .break?:
                    return
                case .continue?, nil:
                    continue
                }
            }
            _ = block(nil)
        }
    }
    
    public struct MatchSiblings: IntrospectionMatching {
        public func match<T: UIResponder>(start: UIView, block: (T?) -> Introspection.FlowControl) {
            var children: [UIView] = start.superview?.subviews ?? []
            
            while !children.isEmpty {
                for child in children where child !== start {
                    switch (child as? T).map(block) {
                    case .break?:
                        return
                    case .continue?, nil:
                        continue
                    }
                }
                
                children = children.flatMap(\.subviews)
            }
            
            _ = block(nil)
        }
    }
    
    public struct MatchPresentingHierarchy: IntrospectionMatching {
        public func match<T: UIResponder>(start: UIView, block: (T?) -> Introspection.FlowControl) {
            func next(of controller: UIViewController) -> UIViewController? {
                controller.parent // ?? controller.presentingViewController
            }
            
            var currentResponder: UIResponder = start
            while let next = currentResponder.next {
                currentResponder = next
            }

            var currentController = currentResponder as? UIViewController
            
            while let controller = currentController {
                switch (controller as? T).map(block) {
                case .break?:
                    return
                case .continue?, nil:
                    break
                }
                currentController = next(of: controller)
            }
            
            _ = block(nil)
        }
    }
}

internal struct UIIntrospectionView<T: UIResponder>: UIViewRepresentable {
    private final class IntrospectionView: UIView {
        override public init(frame: CGRect) {
            super.init(frame: frame)
            self.setup()
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            self.setup()
        }
        
        private func setup() {
            self.backgroundColor = .clear
            self.isHidden = true
            self.translatesAutoresizingMaskIntoConstraints = false
        }
    }
    
    private let block: (T?) -> Introspection.FlowControl
    private let matcher: IntrospectionMatching

    public init(matcher: IntrospectionMatching, _ block: @escaping (T?) -> Introspection.FlowControl) {
        self.block = block
        self.matcher = matcher
    }
    
    public func makeUIView(context: Context) -> UIView {
        return IntrospectionView(frame: .zero)
    }

    public func updateUIView(_ uiView: UIView, context: Context) {
        var hostView = uiView
        
        DispatchQueue.main.async {
            while let view = hostView.superview {
                if String(reflecting: type(of: view)).contains("ViewHost") {
                    hostView = view
                    break
                }
            }
            hostView = hostView.superview?.superview ?? hostView
            
            self.matcher.match(start: hostView, block: self.block)
        }
    }
}
#endif

internal extension View {
#if os(iOS)
    @_disfavoredOverload
    func introspect<T: UIResponder>(
        matching match: some IntrospectionMatching,
        _ block: @escaping (T?) -> Introspection.FlowControl
    ) -> some View {
        self.background(UIIntrospectionView(matcher: match, block))
    }

    func introspect<T: UIResponder>(
        matching match: some IntrospectionMatching,
        _ block: @escaping (T?) -> Void
    ) -> some View {
        self.background(UIIntrospectionView<T>(matcher: match) { (it: T?) -> Introspection.FlowControl in block(it); return .break })
    }
#endif
}

extension Color {
    internal static var primaryLabel: Self {
        .init(UIColor.label)
    }
    
    internal static var secondaryLabel: Self {
        .init(UIColor.secondaryLabel)
    }
    
    internal static var tertiaryLabel: Self {
        .init(UIColor.tertiaryLabel)
    }
    
    internal static var primaryBackground: Self {
        .init(UIColor.systemBackground)
    }
    
    internal static var secondaryBackground: Self {
        .init(UIColor.secondarySystemBackground)
    }
    
    internal static var tertiaryBackground: Self {
        .init(UIColor.tertiarySystemBackground)
    }
    
    internal static var primaryGroupedBackground: Self {
        .init(UIColor.systemGroupedBackground)
    }
    
    internal static var secondaryGroupedBackground: Self {
        .init(UIColor.secondarySystemGroupedBackground)
    }
    
    internal static var tertiaryGroupedBackground: Self {
        .init(UIColor.tertiarySystemGroupedBackground)
    }
}

extension EmptyView {
    internal init(_ block: () -> Void) {
        block()
        self.init()
    }
}

// MARK: - TypeBox

internal struct TypeBox<T>: Hashable {
    static func == (lhs: TypeBox<T>, rhs: TypeBox<T>) -> Bool {
        lhs.type == rhs.type
    }

    public let type: T.Type
    
    public init(_ type: T.Type = T.self) {
        self.type = type
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self.type))
    }
}

// MARK: - ImposedIdentity

@dynamicMemberLookup
internal struct ImposedIdentity<ID: Hashable, Value>: Identifiable {
    public let id: ID
    public var value: Value
   
    public init(id: ID, value: Value) {
        self.id = id
        self.value = value
    }

    subscript<R>(dynamicMember keyPath: KeyPath<Value, R>) -> R {
        self.value[keyPath: keyPath]
    }
    
    subscript<R>(dynamicMember keyPath: WritableKeyPath<Value, R>) -> R {
        get { self.value[keyPath: keyPath] }
        set { self.value[keyPath: keyPath] = newValue }
    }
    
    subscript<R>(dynamicMember keyPath: ReferenceWritableKeyPath<Value, R>) -> R {
        get { self.value[keyPath: keyPath] }
        nonmutating set { self.value[keyPath: keyPath] = newValue }
    }
}

extension ImposedIdentity: Hashable {
    static func == (lhs: ImposedIdentity<ID, Value>, rhs: ImposedIdentity<ID, Value>) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }
}
