import Foundation
import SwiftUI

// MARK: - Omniform
public struct Omniform: View {
    @Environment(\.presentationMode) @Binding private var presentationMode
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    @State private var query: String = ""
    private let binding: any ValueBinding
    
    public init(_ binding: some ValueBinding) {
        self.binding = binding
    }
    
    public init(model: FormModel) {
        let binding = bind(value: model)
        self.init(binding)
    }
    
    public var body: some View {
        let omniform = OmniformView(self.binding)
            .omniformPresentation(self.presentationKind)
            .navigationBarItems(leading: self.leadingNavigationItems)
            .modify { content in
                if #available(iOS 15.0, *) {
                    content
                        .searchable(text: self.$query, placement: .navigationBarDrawer(displayMode: .automatic))
                } else {
                    content
                }
            }
        
        switch self.presentationKind {
        case .stack:
            NavigationView {
                omniform
            }.navigationViewStyle(.stack)
        case .split:
            SplitNavigationView {
                omniform
            } detail: {
                Text("")
            }
        default:
            omniform
        }
    }
    
    private var presentationKind: OmniformPresentation {
        switch self.horizontalSizeClass {
        case .regular?:
            switch UIDevice.current.userInterfaceIdiom {
            case .pad, .mac:
                return .split
            default:
                return .stack
            }
        case .compact?:
            return .stack
        default:
            return .embed
        }
    }
    
    private var navigationViewStyle: any NavigationViewStyle {
        switch self.presentationKind {
        case .split:
            if #available(iOS 15.0, *) {
                return .columns
            } else {
                return .automatic
            }
        case .stack:
            return .stack
        case .embed:
            return .automatic
        default:
            return .automatic
        }
    }
    
    private var leadingNavigationItems: some View {
        Group {
            if self.presentationMode.isPresented {
                Button { self.presentationMode.dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                        .contentShape(Circle())
                }
            }
        }
    }
}

extension Omniform: Equatable {
    public static func ==(lhs: Self, rhs: Self) -> Bool {
        false
    }
}

// MARK: - OmniformView

public struct OmniformView: View {
    @Environment(\.omniformResourceResolver) var resourceResolver
    @Environment(\.omniformPresentation) var presentation
    private var model: FormModel
    
    private var barTitleDisplayMode: NavigationBarItem.TitleDisplayMode {
        switch (self.presentation, self.presentation.isDerived) {
        case (.stack, false), (.split, false):
            return .large
        default:
            return .inline
        }
    }
    
    public init(_ binding: some ValueBinding) {
        self.init(model: FormModel(binding))
    }
    
    public init(model: FormModel) {
        self.model = model
    }
    
    public var body: some View {
        Form {
            OmniformContentView(model: model)
        }
        .scrollDismissesKeyboard(.immediately)
        .navigationTitle(self.model.metadata.name.map(self.resourceResolver.string(_:)) ?? "")
        .navigationBarTitleDisplayMode(self.barTitleDisplayMode)
    }
}

// MARK: - OmniformContentView

internal struct OmniformContentView: View {
    @Environment(\.omniformStyle) var style
    
    private let model: FormModel
    
    public init(model: FormModel) {
        self.model = model
    }

    public var body: some View {
        self.style.view(for: self.model)
    }
}

// MARK: - Utility

fileprivate extension OmniformStyle {
    func view(for model: FormModel) -> AnyView {
        ForEach(model.fields(using: SwiftUIFieldVisitor(style: self)), id: \ViewElement.0) { (it: ViewElement) -> AnyView in it.1 }
            .erased
    }
}
