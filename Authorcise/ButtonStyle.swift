//
//  ButtonStyle.swift
//  Authorcise
//
//  Created by Colin Wright on 5/6/25.
//

import Foundation
import SwiftUI


// Custom Button Style for a rectangular look with hover and pressed states
struct CustomRectangularButtonStyle: ButtonStyle {
    var normalBackgroundColor: Color
    var hoverBackgroundColor: Color
    var pressedBackgroundColor: Color
    var textColor: Color
    var cornerRadius: CGFloat = 0 // Explicitly 0 for rectangular

    // Private inner view to manage hover state for each button instance
    private struct HoverableView: View {
        let configuration: ButtonStyle.Configuration
        let normalBackgroundColor: Color
        let hoverBackgroundColor: Color
        let pressedBackgroundColor: Color
        let textColor: Color
        let cornerRadius: CGFloat

        @State private var isHovered = false // Local state for hover

        var body: some View {
            configuration.label
                .font(.system(size: 14, weight: .medium))
                .frame(minHeight: 24) // Consistent height
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    // Determine background color: pressed takes precedence, then hovered, then normal
                    configuration.isPressed ? pressedBackgroundColor : (isHovered ? hoverBackgroundColor : normalBackgroundColor)
                )
                .foregroundColor(textColor)
                .cornerRadius(cornerRadius) // Apply corner radius
                .onHover { hovering in // Update local hover state
                    isHovered = hovering
                }
                // Animate changes based on isPressed and isHovered states
                .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
                .animation(.easeOut(duration: 0.1), value: isHovered)
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        // Use the HoverableView, passing all necessary parameters
        HoverableView(
            configuration: configuration,
            normalBackgroundColor: normalBackgroundColor,
            hoverBackgroundColor: hoverBackgroundColor,
            pressedBackgroundColor: pressedBackgroundColor,
            textColor: textColor,
            cornerRadius: cornerRadius
        )
    }
}
