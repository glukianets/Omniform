import Foundation
import SwiftUI

// MARK: - Omniform

public struct Omniform: View {
    @Environment(\.presentationMode) @Binding private var presentationMode

    private let model: FormModel
    @State private var query: String = ""

    public init(_ binding: some ValueBinding) {
        self.init(model: FormModel(binding))
    }
    
    public init(model: FormModel) {
        self.model = model
    }

    public var body: some View {
        let omniform = OmniformView(model: self.model)
            .navigationBarItems(leading: Button { self.presentationMode.dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                    .contentShape(Circle())
            })
            .omniformPresentation(.navigation(fromRoot: true))
        
        return NavigationView {
                if #available(iOS 15.0, *) {
                    omniform
                        .searchable(text: self.$query, placement: .navigationBarDrawer(displayMode: .automatic))
                } else {
                    omniform
                }
        }
        .navigationViewStyle(.stack)
        .omniformPresentation(.navigation)
    }
}

// MARK: - OmniformView

public struct OmniformView: View {
    @Environment(\.omniformResourceResolver) var resourceResolver
    @Environment(\.omniformPresentation) var presentation
    private var model: FormModel
    
    private var barTitleDisplayMode: NavigationBarItem.TitleDisplayMode {
        switch self.presentation {
        case .navigation(fromRoot: true):
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
