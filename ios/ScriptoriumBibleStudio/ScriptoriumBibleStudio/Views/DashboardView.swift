import CoreData
import SwiftUI

struct DashboardView: View {
    let books: [SBBook]
    let chapters: [SBChapter]
    let bookmarks: [SBBookmark]
    let openChapter: (SBChapter) -> Void
    let openLibrary: () -> Void

    private var completeCount: Int {
        chapters.filter { $0.statusValue == .final }.count
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                    MetricCard(title: "Books", value: "\(books.count)", systemImage: "books.vertical", tint: ScriptoriumPalette.indigo)
                    MetricCard(title: "Chapters", value: "\(chapters.count)", systemImage: "text.book.closed", tint: ScriptoriumPalette.teal)
                    MetricCard(title: "Words", value: totalWords.formatted(), systemImage: "pencil.and.outline", tint: ScriptoriumPalette.amber)
                    MetricCard(title: "Bookmarks", value: "\(bookmarks.count)", systemImage: "bookmark", tint: ScriptoriumPalette.rose)
                }

                progressPanel

                if let last = recent.first {
                    continuePanel(last)
                }

                recentPanel

                if !bookmarks.isEmpty {
                    bookmarksPanel
                }
            }
            .padding(24)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Author's Study")
                .font(.caption.weight(.semibold))
                .foregroundStyle(ScriptoriumPalette.rose)
                .textCase(.uppercase)
                .tracking(1.4)
            Text("The Scriptorium")
                .font(.system(size: 42, weight: .semibold, design: .serif))
                .foregroundStyle(ScriptoriumPalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("Write, annotate, read, and export your own Bible manuscript.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var progressPanel: some View {
        Panel {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Writing Progress", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.headline)
                    Spacer()
                    Text("\(completeCount)/\(chapters.count) complete")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: progress)
                    .tint(ScriptoriumPalette.teal)
                Text("\(Int(progress * 100))% of chapters are marked complete.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func continuePanel(_ chapter: SBChapter) -> some View {
        Panel {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "pencil.line")
                    .font(.title2)
                    .foregroundStyle(ScriptoriumPalette.indigo)
                    .frame(width: 36, height: 36)
                    .background(ScriptoriumPalette.indigo.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 7) {
                    Text("Continue Writing")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text("\(chapter.book?.name ?? "Book") \(chapter.number): \(chapter.title)")
                        .font(.title3.weight(.semibold))
                    HStack(spacing: 10) {
                        StatusPill(status: chapter.statusValue)
                        Text("\(wordCount(chapter)) words")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(chapter.updatedAt, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        openChapter(chapter)
                    } label: {
                        Label("Return to the page", systemImage: "arrow.right")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(ScriptoriumPalette.indigo)
                    .padding(.top, 4)
                }
                Spacer()
            }
        }
    }

    private var recentPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Recently Edited", systemImage: "clock")
                    .font(.headline)
                Spacer()
                Button("Browse Library", action: openLibrary)
                    .font(.callout.weight(.medium))
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 12)], spacing: 12) {
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
            Label("Bookmarks", systemImage: "bookmark")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 12)], spacing: 12) {
                ForEach(bookmarks.prefix(6), id: \.objectID) { bookmark in
                    Panel(padding: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(bookmark.label)
                                .font(.headline)
                                .lineLimit(1)
                            if let passage = bookmark.passage, !passage.isEmpty {
                                Text(passage)
                                    .font(.caption)
                                    .italic()
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            Text(bookmark.book?.name ?? "Book")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private func wordCount(_ chapter: SBChapter) -> Int {
        chapter.plainText.split { $0.isWhitespace || $0.isNewline }.count
    }
}

struct ChapterCard: View {
    let chapter: SBChapter
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Panel {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("CHAPTER \(chapter.number)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                            .tracking(0.8)
                        Spacer()
                        StatusPill(status: chapter.statusValue)
                    }
                    Text(chapter.title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    HStack {
                        Text("\(chapter.plainText.split { $0.isWhitespace || $0.isNewline }.count) words")
                        Spacer()
                        Text(chapter.updatedAt, style: .date)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }
}
