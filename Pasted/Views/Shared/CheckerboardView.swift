import SwiftUI

/// Renders a checkerboard pattern — the standard visual convention for indicating
/// image transparency. Used behind transparent PNG/TIFF images in clipboard cards.
struct CheckerboardView: View {
    var cellSize: CGFloat = DesignTokens.Layout.checkerboardCellSize

    @Environment(\.colorScheme) private var colorScheme

    private var colorA: Color { colorScheme == .dark ? DesignTokens.Colors.checkerDarkA : DesignTokens.Colors.checkerLightA }
    private var colorB: Color { colorScheme == .dark ? DesignTokens.Colors.checkerDarkB : DesignTokens.Colors.checkerLightB }

    var body: some View {
        Canvas { context, size in
            let cols = Int(ceil(size.width  / cellSize))
            let rows = Int(ceil(size.height / cellSize))

            for row in 0..<rows {
                for col in 0..<cols {
                    let color = (row + col) % 2 == 0 ? colorA : colorB
                    let rect = CGRect(
                        x: CGFloat(col) * cellSize,
                        y: CGFloat(row) * cellSize,
                        width: cellSize,
                        height: cellSize
                    )
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
    }
}
