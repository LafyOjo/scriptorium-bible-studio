import SwiftUI

struct Panel<Content: View>: View {
    let padding: CGFloat
    @ViewBuilder var content: Content

    init(padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        ParchmentPanel(padding: padding) {
            content
        }
    }
}

struct ParchmentPanel<Content: View>: View {
    let padding: CGFloat
    @ViewBuilder var content: Content

    init(padding: CGFloat = 24, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(SBTheme.ivory)
                    .overlay(
                        LinearGradient(
                            colors: [
                                SBTheme.ivory.opacity(0.8),
                                SBTheme.parchmentDeep.opacity(0.18),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(SBTheme.border, lineWidth: 1)
            )
            .shadow(color: SBTheme.primary.opacity(0.06), radius: 24, x: 0, y: 8)
    }
}

struct GoldDivider: View {
    var body: some View {
        LinearGradient(
            colors: [
                SBTheme.gold.opacity(0),
                SBTheme.gold,
                SBTheme.gold.opacity(0),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: 96, height: 1)
        .frame(maxWidth: .infinity)
    }
}

struct VerseNumberBadge: View {
    let number: Int

    var body: some View {
        Text("\(number)")
            .font(SBTheme.display(11, weight: .semibold))
            .foregroundStyle(SBTheme.gold)
            .baselineOffset(6)
            .textCase(.uppercase)
            .allowsHitTesting(false)
    }
}

struct SectionTitleView: View {
    let title: String

    var body: some View {
        VStack(spacing: 8) {
            GoldDivider()
            Text(title.uppercased())
                .font(SBTheme.display(14, weight: .semibold))
                .foregroundStyle(SBTheme.crimson)
                .tracking(3.5)
                .multilineTextAlignment(.center)
            GoldDivider()
        }
    }
}

struct DropCap: View {
    let character: Character

    var body: some View {
        Text(String(character))
            .font(SBTheme.body(56, weight: .semibold))
            .foregroundStyle(SBTheme.crimson)
            .padding(.trailing, 6)
            .alignmentGuide(.firstTextBaseline) { dimension in
                dimension[.bottom] - 14
            }
    }
}

struct HighlightSpan<Content: View>: View {
    let theme: HighlightTheme
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, 2)
            .background(theme.color, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

struct FootnoteMarker: View {
    var body: some View {
        Text("*")
            .font(SBTheme.display(12, weight: .bold))
            .foregroundStyle(SBTheme.crimson)
            .baselineOffset(7)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: systemImage)
                        .foregroundStyle(tint)
                    Text(title.uppercased())
                        .font(SBTheme.display(10, weight: .semibold))
                        .tracking(2.4)
                        .foregroundStyle(SBTheme.mutedForeground)
                }
                Text(value)
                    .font(SBTheme.display(28, weight: .semibold))
                    .foregroundStyle(SBTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct StatusPill: View {
    let status: ChapterStatus

    var body: some View {
        Label {
            Text(status.label)
        } icon: {
            Circle()
                .fill(status.tint)
                .frame(width: 7, height: 7)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(SBTheme.primary)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(status.tint.opacity(0.12), in: Capsule())
    }
}

struct TagChip: View {
    let label: String
    var onRemove: (() -> Void)?

    var body: some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.caption.weight(.medium))
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.caption2.weight(.bold))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .foregroundStyle(SBTheme.primary)
        .background(SBTheme.goldSoft.opacity(0.26), in: Capsule())
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(SBTheme.gold)
            GoldDivider()
            Text(title)
                .font(SBTheme.display(18, weight: .semibold))
                .foregroundStyle(SBTheme.primary)
                .multilineTextAlignment(.center)
            Text(message)
                .font(SBTheme.body(18))
                .foregroundStyle(SBTheme.mutedForeground)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }
}

struct AttributedPreview: UIViewRepresentable {
    let text: NSAttributedString
    var isScrollEnabled = true

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.isEditable = false
        view.isSelectable = true
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.isScrollEnabled = isScrollEnabled
        view.adjustsFontForContentSizeCategory = true
        return view
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if !uiView.attributedText.isEqual(to: text) {
            uiView.attributedText = text
        }
        uiView.isScrollEnabled = isScrollEnabled
    }
}

struct ExportMenuButton: View {
    let chapter: SBChapter
    let book: SBBook?

    @State private var shareItem: ShareItem?
    @State private var exportError: String?

    var body: some View {
        Menu {
            ForEach(ExportKind.allCases) { kind in
                Button {
                    export(kind)
                } label: {
                    Label(kind.label, systemImage: kind.systemImage)
                }
            }
        } label: {
            Label("Export", systemImage: "square.and.arrow.up")
        }
        .sheet(item: $shareItem) { item in
            ActivityView(activityItems: [item.url])
        }
        .alert("Export failed", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("OK", role: .cancel) { exportError = nil }
        } message: {
            Text(exportError ?? "")
        }
    }

    private func export(_ kind: ExportKind) {
        do {
            shareItem = ShareItem(url: try ExportService.chapterURL(chapter: chapter, book: book, kind: kind))
        } catch {
            exportError = error.localizedDescription
        }
    }
}

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}
