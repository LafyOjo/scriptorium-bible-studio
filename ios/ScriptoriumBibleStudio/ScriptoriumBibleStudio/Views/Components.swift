import SwiftUI

struct Panel<Content: View>: View {
    let padding: CGFloat
    @ViewBuilder var content: Content

    init(padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
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
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Text(value)
                    .font(.system(.title, design: .rounded).weight(.semibold))
                    .foregroundStyle(ScriptoriumPalette.ink)
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
        .foregroundStyle(.primary)
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
        .background(Color.primary.opacity(0.07), in: Capsule())
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        }
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

extension View {
    func studioBackground() -> some View {
        background(
            LinearGradient(
                colors: [
                    ScriptoriumPalette.background,
                    Color(red: 0.94, green: 0.97, blue: 0.96),
                    Color(red: 0.97, green: 0.95, blue: 0.98),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }
}
