# Omniform

Omniform is a library for generating comprehensive UI forms for arbitrary value types.

From simple structures like this:

```swift
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

        @Field(icon: "gauge.high", ui: .section())
        var values = Values()

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
}

```

It produces UI like this:

![ui example](https://github.com/glukianets/omniform/blob/master/README.png?raw=true#gh-light-mode-only)
![ui example](https://github.com/glukianets/omniform/blob/master/README~dark.png?raw=true#gh-dark-mode-only)

For further guidance please consult built-in documentation
