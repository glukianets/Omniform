import Foundation
import SwiftUI

// MARK: - Omniform

public struct Omniform: View {
    @Environment(\.presentationMode) @Binding private var presentationMode
    
    private let model: FormModel
    
    public init(_ binding: some ValueBinding) {
        self.init(model: FormModel(binding))
    }
    
    public init(model: FormModel) {
        self.model = model
    }

    public var body: some View {
        NavigationView {
            OmniformView(model: self.model)
                .navigationBarTitle(self.model.metadata.displayName)
                .navigationBarItems(leading: Button { self.presentationMode.dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                        .contentShape(Circle())
                })
        }
        .navigationViewStyle(.stack)
        .omniformPresentation(.navigation)
    }
}

// MARK: - OmniformView

public struct OmniformView: View {
    private struct RegularContentView: View {
        private let model: FormModel

        public init(model: FormModel) {
            self.model = model
        }

        public var body: some View {
            Form {
                OmniformContentView(model: model)
            }
        }
    }

    @available(iOS 15, *)
    private struct SearchableContentView: View {
        private let model: FormModel
        @State private var query: String = ""
        
        public init(model: FormModel) {
            self.model = model
        }

        public var body: some View {
            Form {
                if let model = self.model.filtered(using: self.query) {
                    OmniformContentView(model: model)
                }
            }
            .searchable(text: self.$query, placement: .navigationBarDrawer)
        }
    }
    
    private var model: FormModel
    
    public init(_ binding: some ValueBinding) {
        self.init(model: FormModel(binding))
    }
    
    public init(model: FormModel) {
        self.model = model
    }

    public var body: some View {
        Group {
            if #available(iOS 15, *) {
                SearchableContentView(model: self.model)
            } else {
                RegularContentView(model: self.model)
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .navigationBarTitle(self.model.metadata.displayName)
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
