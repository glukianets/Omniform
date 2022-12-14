import Foundation

/// Namespace for model examples
public enum Samples {
    struct Basic {
        enum Options: CaseIterable {
            case option1, option2, option3
        }
        
        var toggle: Bool = true
        
        var input: String = ""
        
        @Field(ui: .display())
        var label: String = "Hello, world!"
        
        @Field(ui: .picker())
        var picker: Options = .option1
        
        @Field(ui: .button())
        var button: () -> Void = {}
    }
    
    struct Values {
        @Field(icon: "switch.2")
        var toggle: Bool = false

        @Field(icon: "numbersign", ui: .stepper(in: 0..<4))
        var stepper: Int = 0

        @Field(icon: "calendar", ui: .picker())
        var date: Date = .distantFuture

        @Field(ui: .slider())
        var slider: Double = 0.5
        
        @Field(ui: .display(style: .elaborate).grouping(inside: .screen(format: .default)))
        var text: String = """
        Lorem ipsum dolor sit amet, consectetur adipiscing elit. Etiam ornare justo dui, et consequat lectus ultricies ac. Fusce aliquet convallis mattis. Aliquam erat volutpat. Sed quis sem convallis, eleifend ipsum vitae, semper sapien. Proin bibendum sapien vel orci porta placerat. In vel dui sit amet dolor gravida facilisis. Aenean porta aliquam nulla ut dignissim. Ut tristique gravida nunc sed suscipit. Phasellus convallis arcu vitae augue tempus viverra. Sed eu convallis eros. Suspendisse mollis orci quis convallis feugiat. Phasellus mattis condimentum sollicitudin. Etiam quam neque, malesuada quis felis vitae, semper semper ligula. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos himenaeos. Sed sollicitudin est arcu, vitae fermentum ligula dapibus at.
        """
    }
    
    @available(iOS 15, macOS 12, *)
    struct Values_iOS15_macOS12 {
        @Field(ui: .display(format: .dateTime))
        var dateLabel: Date = .distantFuture
        
        @Field(ui: .display(format: .byteCount(style: .memory)))
        var memorySize: Int64 = 1024 * 1024
    }

    struct Pickers {
        enum Position: CaseIterable, CustomFieldPresentable {
            case first, second, third
        }
        
        var auto: Position = .first

        @Field(ui: .picker(style: .segments))
        var segments: Position = .first

        @Field(ui: .picker(style: .menu))
        var menu: Position = .first

        @Field(ui: .picker(style: .wheel))
        var wheel: Position = .first

        @Field(ui: .picker(style: .selection))
        var selection: Position = .first
        
        @Field(ui: .picker(style: .selection(.inline())))
        var inlineSelection: Position = .first

        @Field(ui: .picker(style: .selection(.section())))
        var sectionSelection: Position = .first
    }
    
    struct Buttons {
        @Field(icon: "square.and.arrow.up", ui: .button())
        var save: () -> Void = {}
        
        @Field(icon: "trash", ui: .button(role: .destructive))
        var delete: () -> Void = {}
    }
    
    struct Dynamic: CustomFormBuilding {
        static func buildForm(_ binding: some ValueBinding) -> FormModel.Prototype {
            FormModel.Member.group(id: UUID(), name: "group", ui: Presentations.Group<Any>.inline(), binding: bind(value: Void())) {
                for i in 1..<12 {
                    .field(name: "Test", icon: .system("\(i).lane"), ui: .toggle, binding: bind(value: false))
                }
            }
        }
    }
    
    struct Inputs {
        var plain: String = ""
        
        @Field(ui: .input(secure: true))
        var secure: String = ""
    }
    
    @available(iOS 15, macOS 11, *)
    struct Inputs_iOS15_macOS12 {
        @Field(ui: .input(format: .dateTime))
        var date: Date = .now
        
        @Field(ui: .input(format: .iso8601))
        var iso8601: Date = .now
        
        @Field(ui: .input(format: .number))
        var integer: Int = 0
        
        @Field(ui: .input(format: .number))
        var double: Double = 0
        
        @Field(ui: .input(format: .percent))
        var percent: Double = 0
        
        @Field(ui: .input(format: .currency(code: "RUR")))
        var currency: Decimal = 0
    }
    
    @available(iOS 16, macOS 13, *)
    struct Inputs_iOS16_macOS13 {
        @Field(ui: .input(format: .url))
        var url: URL = URL(string: "www.example.com")!
    }
    
    public struct Examples_iOS14_macOS11 {
        @Field(icon: "gauge.high", ui: .screen())
        var values = Values()
        
        @Field(icon: "keyboard", ui: .screen())
        var inputs = Inputs()
        
        @Field(icon: "eyedropper", ui: .screen())
        var pickers = Pickers()

        @Field(icon: "cursorarrow.rays", ui: .screen())
        var buttons = Buttons()

        @Field(icon: "questionmark.diamond", ui: .screen())
        var dynamic = Dynamic()
    }
    
    @available(iOS 15, macOS 12, *)
    public struct Examples_iOS15_macOS12 {
        @Field(icon: "graduationcap", ui: .section())
        var examples_iOS14_macOS11 = Examples_iOS14_macOS11()
        
        @Field(icon: "gauge.high", ui: .screen())
        var values = Values_iOS15_macOS12()
        
        @Field(icon: "keyboard", ui: .screen())
        var inputs = Inputs_iOS15_macOS12()
    }
    
    @available(iOS 16, macOS 13, *)
    public struct Examples_iOS16_macOS13 {
        @Field(icon: "graduationcap", ui: .section())
        var examples_iOS15_macOS12 = Examples_iOS15_macOS12()
        
        @Field(icon: "keyboard", ui: .screen())
        var inputs = Inputs_iOS16_macOS13()
    }

    public struct Tutorial: CustomFormPresentable {
        @Field(icon: "star", ui: .section())
        var basic = Basic()
                
        private var _examples: Any = {
            if #available(iOS 16, macOS 13, *) {
                return Examples_iOS16_macOS13()
            } else if #available(iOS 15, macOS 12, *) {
                return Examples_iOS15_macOS12()
            } else {
                return Examples_iOS14_macOS11()
            }
        }()

        @available(iOS, introduced: 14, obsoleted: 15)
        @available(macOS, introduced: 11, obsoleted: 12)
        var examples_iOS14_macOS11: Examples_iOS14_macOS11 {
            get { self._examples as! Examples_iOS14_macOS11 }
            set { self._examples = newValue }
        }
        
        @available(iOS, introduced: 15, obsoleted: 16)
        @available(macOS, introduced: 12, obsoleted: 13)
        var examples_iOS15_macOS12: Examples_iOS15_macOS12 {
            get { self._examples as! Examples_iOS15_macOS12 }
            set { self._examples = newValue }
        }
        
        @available(iOS 16, macOS 13, *)
        var examples_iOS16_macOS13: Examples_iOS16_macOS13 {
            get { self._examples as! Examples_iOS16_macOS13 }
            set { self._examples = newValue }
        }
        
        public init() {
            // nothing
        }
        
        public static func formModel(for binding: some ValueBinding<Self>) -> FormModel {
            .init(name: "Tutorial") {
                .field(ui: .section(), binding: binding.map(keyPath: \.basic))

                if #available(iOS 16, macOS 13, *) {
                    .group(icon: "graduationcap", ui: .section(), binding: binding.map(keyPath: \Self.examples_iOS16_macOS13))
                } else if #available(iOS 15, macOS 12, *) {
                    .group(icon: "graduationcap", ui: .section(), binding: binding.map(keyPath: \Self.examples_iOS15_macOS12))
                } else if #available(iOS 14, macOS 11, *) {
                    .group(icon: "graduationcap", ui: .section(), binding: binding.map(keyPath: \Self.examples_iOS14_macOS11))
                }
            }
        }
    }
}
