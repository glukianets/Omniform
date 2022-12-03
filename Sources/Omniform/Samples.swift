import Foundation

/// Namespace for model examples
@available(iOS 16, macOS 13, *)
public enum Samples {
    public struct Tutorial {
        struct Basic {
            var toggle: Bool = true
            
            var text: String = ""
            
            @Field(ui: .button())
            var button: () -> Void = {}
        }

        struct Examples {
            struct Values {
                @Field(icon: "switch.2")
                var toggle: Bool = false

                @Field(icon: "numbersign", ui: .stepper(in: 0..<4))
                var stepper: Int = 0

                @Field(icon: "calendar", ui: .picker())
                var date: Date = .distantFuture

                @Field(ui: .slider())
                var slider: Double = 0.5
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
            
            struct Inputs {
                struct Formatted {
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
                    
                    @Field(ui: .input(format: .url))
                    var url: URL = URL(string: "www.example.com")!
                    
                    @Field(ui: .input(format: .currency(code: "RUR")))
                    var currency: Decimal = 0
                }
                
                var plain: String = ""
                
                @Field(ui: .input(secure: true))
                var secure: String = ""
                
                @Field(ui: .input(secure: true, presentation: .screen, prompt: "Footnote"))
                var secureOutline: String = ""
                
                @Field(ui: .section())
                var formatted = Formatted()
            }
            
            struct Buttons {
                @Field(icon: "square.and.arrow.up", ui: .button())
                var save: () -> Void = {}
                
                @Field(icon: "trash", ui: .button(role: .destructive))
                var delete: () -> Void = {}
            }
            
            struct Dynamic: CustomFormBuilding {
                static func buildForm(_ binding: some ValueBinding) -> FormModel.Prototype {
                    .group(name: "group") {
                        for i in 1..<12 {
                            .field(bind(value: false), name: "Test", icon: .system("\(i).lane"), ui: .toggle)
                        }
                    }
                }
            }

            @Field(icon: "gauge.high", ui: .section())
            var values = Values()

            @Field(icon: "keyboard", ui: .section())
            var inputs = Inputs()

            @Field(icon: "eyedropper", ui: .section())
            var pickers = Pickers()
            
            @Field(icon: "cursorarrow.rays", ui: .section())
            var buttons = Buttons()
            
            @Field(icon: "questionmark.diamond", ui: .section())
            var dynamic = Dynamic()

        }
        
        @Field(icon: "star", ui: .section())
        var basic = Basic()
        
        @Field(icon: "graduationcap", ui: .section())
        var examples = Examples()
        
        public init() {
            // nothing
        }
    }
}
