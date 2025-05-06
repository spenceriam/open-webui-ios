import SwiftUI

/// Helper class to manage dynamic type functionality across the app
class DynamicTypeHelper {
    // Define scale factors for each text style based on the current content size category
    static func scaleFactor(for contentSizeCategory: ContentSizeCategory) -> CGFloat {
        switch contentSizeCategory {
        case .extraSmall:
            return 0.8
        case .small:
            return 0.9
        case .medium:
            return 1.0
        case .large:
            return 1.1
        case .extraLarge:
            return 1.2
        case .extraExtraLarge:
            return 1.3
        case .extraExtraExtraLarge:
            return 1.4
        case .accessibilityMedium:
            return 1.6
        case .accessibilityLarge:
            return 1.8
        case .accessibilityExtraLarge:
            return 2.0
        case .accessibilityExtraExtraLarge:
            return 2.2
        case .accessibilityExtraExtraExtraLarge:
            return 2.4
        @unknown default:
            return 1.0
        }
    }
    
    // Get the scaled font size based on a base size and content size category
    static func scaledFontSize(baseSize: CGFloat, for contentSizeCategory: ContentSizeCategory) -> CGFloat {
        return baseSize * scaleFactor(for: contentSizeCategory)
    }
    
    // Get the appropriate SwiftUI font with dynamic type scaling
    static func scaledFont(style: Font.TextStyle, design: Font.Design = .default) -> Font {
        return Font.system(style, design: design)
    }
    
    // Get a custom scaled font with specific size
    static func customScaledFont(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        return Font.system(size: size, weight: weight, design: design)
    }
}

// MARK: - View Extensions for Dynamic Type

extension View {
    // Apply consistent spacing for the current dynamic type size
    func dynamicSpacing(_ baseSpacing: CGFloat = 8) -> some View {
        self.modifier(DynamicSpacingModifier(baseSpacing: baseSpacing))
    }
    
    // Apply consistent padding for the current dynamic type size
    func dynamicPadding(baseHorizontal: CGFloat = 16, baseVertical: CGFloat = 8) -> some View {
        self.modifier(DynamicPaddingModifier(baseHorizontal: baseHorizontal, baseVertical: baseVertical))
    }
    
    // Apply consistent corner radius for the current dynamic type size
    func dynamicCornerRadius(baseRadius: CGFloat = 8) -> some View {
        self.modifier(DynamicCornerRadiusModifier(baseRadius: baseRadius))
    }
    
    // Scale UI elements based on dynamic type setting
    func dynamicScale(property: DynamicScaleProperty = .all) -> some View {
        self.modifier(DynamicScaleModifier(property: property))
    }
}

// MARK: - Custom View Modifiers

// Dynamic spacing modifier
struct DynamicSpacingModifier: ViewModifier {
    @Environment(\.sizeCategory) var sizeCategory
    let baseSpacing: CGFloat
    
    func body(content: Content) -> some View {
        let scaleFactor = DynamicTypeHelper.scaleFactor(for: sizeCategory)
        return content.padding(baseSpacing * scaleFactor)
    }
}

// Dynamic padding modifier
struct DynamicPaddingModifier: ViewModifier {
    @Environment(\.sizeCategory) var sizeCategory
    let baseHorizontal: CGFloat
    let baseVertical: CGFloat
    
    func body(content: Content) -> some View {
        let scaleFactor = DynamicTypeHelper.scaleFactor(for: sizeCategory)
        return content.padding(
            EdgeInsets(
                top: baseVertical * scaleFactor,
                leading: baseHorizontal * scaleFactor,
                bottom: baseVertical * scaleFactor,
                trailing: baseHorizontal * scaleFactor
            )
        )
    }
}

// Dynamic corner radius modifier
struct DynamicCornerRadiusModifier: ViewModifier {
    @Environment(\.sizeCategory) var sizeCategory
    let baseRadius: CGFloat
    
    func body(content: Content) -> some View {
        let scaleFactor = DynamicTypeHelper.scaleFactor(for: sizeCategory)
        // Limit the maximum radius to maintain visual appearance
        let scaledRadius = min(baseRadius * scaleFactor, baseRadius * 1.5)
        return content.cornerRadius(scaledRadius)
    }
}

// Enum to specify which properties should be scaled
enum DynamicScaleProperty {
    case font
    case spacing
    case size
    case all
}

// Dynamic scale modifier for UI elements
struct DynamicScaleModifier: ViewModifier {
    @Environment(\.sizeCategory) var sizeCategory
    let property: DynamicScaleProperty
    
    func body(content: Content) -> some View {
        let scaleFactor = DynamicTypeHelper.scaleFactor(for: sizeCategory)
        
        var modifiedContent: some View {
            content
        }
        
        switch property {
        case .font:
            // Font scaling is handled by SwiftUI's dynamic type system
            return modifiedContent
        case .spacing:
            return modifiedContent
                .padding(8 * scaleFactor)
        case .size:
            return modifiedContent
                .scaleEffect(min(scaleFactor, 1.3), anchor: .center)
        case .all:
            return modifiedContent
                .padding(8 * scaleFactor)
                .scaleEffect(min(scaleFactor, 1.3), anchor: .center)
        }
    }
}

// MARK: - Example Usage

struct DynamicTypeSample: View {
    var body: some View {
        VStack(spacing: 20) {
            // Built-in dynamic type support
            Text("Standard Dynamic Type")
                .font(.headline)
            
            // Custom scaled font
            Text("Custom Scaled (16pt)")
                .font(DynamicTypeHelper.customScaledFont(size: 16))
            
            // Dynamic spacing
            HStack {
                Text("Dynamic")
                Text("Spacing")
            }
            .dynamicSpacing()
            .background(Color.gray.opacity(0.2))
            
            // Dynamic padding
            Text("Dynamic Padding")
                .dynamicPadding()
                .background(Color.blue.opacity(0.2))
            
            // Dynamic corner radius
            Text("Dynamic Corner Radius")
                .padding()
                .background(Color.green.opacity(0.2))
                .dynamicCornerRadius()
        }
        .padding()
    }
}