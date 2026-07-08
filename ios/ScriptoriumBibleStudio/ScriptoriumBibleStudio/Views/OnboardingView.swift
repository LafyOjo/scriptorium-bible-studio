import SwiftUI

struct OnboardingView: View {
    let finish: () -> Void

    @State private var page = 0

    private let pages = OnboardingPage.pages

    var body: some View {
        ZStack {
            SBTheme.parchment
                .ignoresSafeArea()
                .studioBackground()

            VStack(spacing: 0) {
                header

                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, item in
                        OnboardingPageView(page: item)
                            .tag(index)
                            .padding(.horizontal, 24)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                footer
            }
        }
        .foregroundStyle(SBTheme.ink)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Scriptorium")
                    .font(SBTheme.display(14, weight: .semibold))
                    .tracking(2.4)
                    .foregroundStyle(SBTheme.crimson)
                Text("Bible Studio")
                    .font(SBTheme.body(32, weight: .semibold))
                    .foregroundStyle(SBTheme.primary)
            }

            Spacer()

            Button("Skip", action: finish)
                .font(.callout.weight(.semibold))
                .foregroundStyle(SBTheme.primary)
                .frame(minHeight: 44)
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 8)
    }

    private var footer: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                ForEach(pages.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? SBTheme.gold : SBTheme.border)
                        .frame(width: index == page ? 28 : 8, height: 8)
                        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: page)
                }
            }

            Button {
                if page == pages.count - 1 {
                    finish()
                } else {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        page += 1
                    }
                }
            } label: {
                Label(page == pages.count - 1 ? "Begin Writing" : "Continue", systemImage: page == pages.count - 1 ? "pencil.line" : "arrow.right")
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 52)
            }
            .buttonStyle(.borderedProminent)
            .tint(SBTheme.primary)
            .font(.headline)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .background(.ultraThinMaterial)
    }
}

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 26) {
            Spacer(minLength: 10)

            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(SBTheme.ivory)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(SBTheme.border, lineWidth: 1)
                    )
                    .shadow(color: SBTheme.primary.opacity(0.12), radius: 28, x: 0, y: 14)

                VStack(spacing: 22) {
                    Image(systemName: page.systemImage)
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(SBTheme.gold)
                        .frame(width: 92, height: 92)
                        .background(SBTheme.goldSoft.opacity(0.24), in: Circle())

                    GoldDivider()

                    VStack(spacing: 10) {
                        Text(page.title)
                            .font(SBTheme.body(34, weight: .semibold))
                            .foregroundStyle(SBTheme.primary)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.72)

                        Text(page.message)
                            .font(SBTheme.body(20))
                            .foregroundStyle(SBTheme.mutedForeground)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(page.points, id: \.self) { point in
                            Label(point, systemImage: "checkmark.seal")
                                .font(.callout.weight(.medium))
                                .foregroundStyle(SBTheme.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(28)
            }
            .frame(maxWidth: 520)
            .frame(maxHeight: 560)

            Spacer(minLength: 6)
        }
    }
}

private struct OnboardingPage: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let systemImage: String
    let points: [String]

    static let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Write Your Own Manuscript",
            message: "Compose books, chapters, sections, verses and paragraph blocks in a private Bible writing studio.",
            systemImage: "text.book.closed",
            points: ["Create custom books and chapters", "Format headings, verses and paragraphs", "Autosave your writing locally"]
        ),
        OnboardingPage(
            title: "Highlight And Annotate",
            message: "Mark themes, colour selected text and keep study notes tied to the exact passage you are shaping.",
            systemImage: "highlighter",
            points: ["Apply colour themes", "Add notes to selected text", "Track important motifs"]
        ),
        OnboardingPage(
            title: "Bookmark Sacred Passages",
            message: "Return quickly to key sections, favorite phrases and chapters that need revision.",
            systemImage: "bookmark",
            points: ["Bookmark books, chapters and passages", "Review saved places", "Remove bookmarks when finished"]
        ),
        OnboardingPage(
            title: "Read Aloud With Control",
            message: "Listen to your draft as a reader would hear it, then tune voice and speed from settings.",
            systemImage: "speaker.wave.2",
            points: ["Play, pause and stop narration", "Adjust voice speed", "Preview in reader mode"]
        ),
        OnboardingPage(
            title: "Search The Whole Work",
            message: "Find chapters, phrases, tags, bookmarks, notes and highlight themes across the entire manuscript.",
            systemImage: "magnifyingglass",
            points: ["Search by phrase or book", "Filter by highlight", "Open results directly"]
        ),
        OnboardingPage(
            title: "Export And Share",
            message: "Share a chapter as plain text and keep JSON backups while the project grows toward publishing.",
            systemImage: "square.and.arrow.up",
            points: ["Share a clean TXT chapter", "Export HTML, RTF, PDF or JSON", "Back up your local library"]
        ),
    ]
}

#Preview("Onboarding") {
    OnboardingView {}
}
