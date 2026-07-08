import CoreData
import SwiftUI

struct DashboardView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let books: [SBBook]
    let chapters: [SBChapter]
    let bookmarks: [SBBookmark]
    let openChapter: (SBChapter) -> Void
    let openLibrary: () -> Void

    private var completeCount: Int {
        chapters.filter { $0.statusValue == .final }.count
    }

    private var draftCount: Int {
        chapters.filter { $0.statusValue == .drafting || $0.statusValue == .revising }.count
    }

    private var totalWords: Int {
        chapters.reduce(0) { $0 + $1.plainText.split { $0.isWhitespace || $0.isNewline }.count }
    }

    private var progress: Double {
        chapters.isEmpty ? 0 : Double(completeCount) / Double(chapters.count)
    }

    private var recent: [SBChapter] {
        chapters.sorted { $0.updatedAt > $1.updatedAt }.prefix(6).map { $0 }
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 150 : 190), spacing: 12)]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                hero

                if chapters.isEmpty {
                    ParchmentPanel {
                        EmptyStateView(
                            title: "Begin Your Manuscript",
                            message: "Create your first book and chapter, then the studio will track progress, drafts, bookmarks and recent pages here.",
                            systemImage: "text.book.closed"
                        )
                        .frame(minHeight: 300)
                    }
                } else {
                    metricGrid
                    quickDesk
                    progressPanel
                    recentPanel

                    if !bookmarks.isEmpty {
                        bookmarksPanel
                    }
                }
            }
            .padding(.horizontal, horizontalSizeClass == .compact ? 16 : 24)
            .padding(.top, 18)
            .padding(.bottom, 34)
        }
    }

    private var hero: some View {
        ParchmentPanel(padding: horizontalSizeClass == .compact ? 20 : 26) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Private Manuscript Studio")
                            .font(SBTheme.display(11, weight: .semibold))
                            .tracking(2.2)
                            .foregroundStyle(SBTheme.crimson)
                            .textCase(.uppercase)
                        Text("Scriptorium Bible Studio")
                            .font(SBTheme.body(horizontalSizeClass == .compact ? 34 : 44, weight: .semibold))
                            .foregroundStyle(SBTheme.primary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.72)
                        Text("Write, refine, annotate and prepare your own original Bible manuscript.")
                            .font(.callout)
                            .foregroundStyle(SBTheme.mutedForeground)
                            .lineSpacing(2)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "book.pages")
                        .font(.system(size: 27, weight: .semibold))
                        .foregroundStyle(SBTheme.gold)
                        .frame(width: 58, height: 58)
                        .background(SBTheme.goldSoft.opacity(0.24), in: Circle())
                }

                if let last = recent.first {
                    Button {
                        openChapter(last)
                    } label: {
                        Label("Continue \(last.book?.name ?? "Book") \(last.number)", systemImage: "pencil.line")
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(SBTheme.primary)
                } else {
                    Button(action: openLibrary) {
                        Label("Create First Chapter", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(SBTheme.primary)
                }
            }
        }
    }

    private var metricGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            MetricCard(title: "Books", value: "\(books.count)", systemImage: "books.vertical", tint: SBTheme.gold)
            MetricCard(title: "Chapters", value: "\(chapters.count)", systemImage: "text.book.closed", tint: SBTheme.crimson)
            MetricCard(title: "Words", value: totalWords.formatted(), systemImage: "text.word.spacing", tint: SBTheme.primary)
            MetricCard(title: "Bookmarks", value: "\(bookmarks.count)", systemImage: "bookmark", tint: SBTheme.gold)
        }
    }

    private var quickDesk: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            if let last = recent.first {
                StudioActionCard(
                    title: "Continue Writing",
                    subtitle: "\(last.book?.name ?? "Book") \(last.number): \(last.title)",
                    systemImage: "pencil.line",
                    tint: SBTheme.primary
                ) {
                    openChapter(last)
                }

                StudioActionCard(
                    title: "Reader Mode",
                    subtitle: "Open the latest chapter and listen through the draft.",
                    systemImage: "eye",
                    tint: SBTheme.gold
                ) {
                    openChapter(last)
                }
            }

            StudioActionCard(
                title: "Library",
                subtitle: "Create, reorder and organize books and chapters.",
                systemImage: "books.vertical",
                tint: SBTheme.crimson,
                action: openLibrary
            )
        }
    }

    private var progressPanel: some View {
        ParchmentPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Label("Writing Progress", systemImage: "chart.line.uptrend.xyaxis")
                        .font(SBTheme.body(24, weight: .semibold))
                        .foregroundStyle(SBTheme.primary)
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(SBTheme.display(24, weight: .semibold))
                        .foregroundStyle(SBTheme.gold)
                }

                ProgressView(value: progress)
                    .tint(SBTheme.gold)
                    .scaleEffect(x: 1, y: 1.4, anchor: .center)

                HStack {
                    Label("\(completeCount) final", systemImage: "checkmark.seal")
                    Spacer()
                    Label("\(draftCount) active drafts", systemImage: "pencil.and.outline")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(SBTheme.mutedForeground)
            }
        }
    }

    private var recentPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitleRow(title: "Recently Edited", systemImage: "clock", actionTitle: "Browse", action: openLibrary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 260 : 280), spacing: 12)], spacing: 12) {
                ForEach(recent, id: \.objectID) { chapter in
                    ChapterCard(chapter: chapter) {
                        openChapter(chapter)
                    }
                }
            }
        }
    }

    private var bookmarksPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitleRow(title: "Bookmarks", systemImage: "bookmark")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 12)], spacing: 12) {
                ForEach(bookmarks.prefix(6), id: \.objectID) { bookmark in
                    ParchmentPanel(padding: 14) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(bookmark.label)
                                .font(.headline)
                                .foregroundStyle(SBTheme.ink)
                                .lineLimit(1)
                            if let passage = bookmark.passage, !passage.isEmpty {
                                Text(passage)
                                    .font(.callout)
                                    .italic()
                                    .foregroundStyle(SBTheme.mutedForeground)
                                    .lineLimit(2)
                            }
                            Text(bookmark.book?.name ?? "Book")
                                .font(SBTheme.display(9, weight: .semibold))
                                .tracking(1.8)
                                .foregroundStyle(SBTheme.crimson)
                                .textCase(.uppercase)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }
}

struct ChapterCard: View {
    let chapter: SBChapter
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ParchmentPanel(padding: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("\(chapter.book?.name ?? "Book") \(chapter.number)")
                            .font(SBTheme.display(10, weight: .semibold))
                            .foregroundStyle(SBTheme.crimson)
                            .tracking(1.8)
                        Spacer()
                        StatusPill(status: chapter.statusValue)
                    }
                    Text(chapter.title)
                        .font(SBTheme.body(24, weight: .semibold))
                        .foregroundStyle(SBTheme.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    HStack {
                        Text("\(wordCount(chapter)) words")
                        Spacer()
                        Text(chapter.updatedAt, style: .date)
                    }
                    .font(.caption)
                    .foregroundStyle(SBTheme.mutedForeground)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }

    private func wordCount(_ chapter: SBChapter) -> Int {
        chapter.plainText.split { $0.isWhitespace || $0.isNewline }.count
    }
}

private struct StudioActionCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ParchmentPanel(padding: 16) {
                HStack(spacing: 13) {
                    Image(systemName: systemImage)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(width: 42, height: 42)
                        .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(SBTheme.ink)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(SBTheme.mutedForeground)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 4)
                }
                .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct SectionTitleRow: View {
    let title: String
    let systemImage: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack {
            Label(title, systemImage: systemImage)
                .font(SBTheme.body(23, weight: .semibold))
                .foregroundStyle(SBTheme.primary)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(SBTheme.primary)
                    .frame(minHeight: 44)
            }
        }
    }
}

#Preview("Dashboard") {
    let controller = PersistenceController.preview
    let context = controller.container.viewContext
    let books = (try? context.fetch(SBBook.fetchRequest())) ?? []
    let chapters = (try? context.fetch(SBChapter.fetchRequest())) ?? []
    let bookmarks = (try? context.fetch(SBBookmark.fetchRequest())) ?? []

    return NavigationStack {
        DashboardView(
            books: books,
            chapters: chapters,
            bookmarks: bookmarks,
            openChapter: { _ in },
            openLibrary: {}
        )
        .studioBackground()
    }
    .environment(\.managedObjectContext, context)
}
