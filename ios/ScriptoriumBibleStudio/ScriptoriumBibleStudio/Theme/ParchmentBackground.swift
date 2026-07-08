import SwiftUI

struct ParchmentBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    SBTheme.parchment
                    LinearGradient(
                        colors: [
                            SBTheme.ivory.opacity(0.56),
                            SBTheme.parchment.opacity(0.18),
                            SBTheme.parchmentDeep.opacity(0.34),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Canvas { context, size in
                        for index in 0..<120 {
                            let x = Double((index * 37) % max(Int(size.width), 1))
                            let y = Double((index * 71) % max(Int(size.height), 1))
                            let rect = CGRect(x: x, y: y, width: 1, height: 1)
                            context.fill(Path(ellipseIn: rect), with: .color(SBTheme.primary.opacity(0.035)))
                        }
                    }
                    .allowsHitTesting(false)
                }
                .ignoresSafeArea()
            )
    }
}

extension View {
    func studioBackground() -> some View {
        modifier(ParchmentBackground())
    }
}
