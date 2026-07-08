import CoreData
import SwiftUI

struct LibraryView: View {
    @Environment(\.managedObjectContext) private var viewContext

    let books: [SBBook]
    let chapters: [SBChapter]
    let settings: SBAppSettings?
    let openChapter: (SBChapter) -> Void

    @State private var addBookPresented = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .bottom) {
                        libraryTitle
                        Spacer(minLength: 16)
                        newBookButton
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        libraryTitle
                        newBookButton
                    }
                }

                ForEach(books, id: \.objectID) { book in
                    bookSection(book)
                }
            }
            .padding(24)
        }
        .sheet(isPresented: $addBookPresented) {
            LibraryAddBookSheet(books: books, onCreate: { name, testament in
                let book = ScriptoriumActions.createBook(
                    name: name,
                    testament: testament,
                    collection: nil,
                    existingBooks: books,
                    context: viewContext
                )
                let chapter = ScriptoriumActions.createChapter(book: book, settings: settings, context: viewContext)
                openChapter(chapter)
            })
        }
    }

    private var libraryTitle: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Volume Index")
                .font(.caption.weight(.semibold))
                .foregroundStyle(ScriptoriumPalette.rose)
                .textCase(.uppercase)
                .tracking(1.4)
            Text("Bible Library")
                .font(.system(size: 36, weight: .semibold, design: .serif))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private var newBookButton: some View {
        Button {
            addBookPresented = true
        } label: {
            Label("New Book", systemImage: "plus")
        }
        .buttonStyle(.borderedProminent)
        .tint(ScriptoriumPalette.indigo)
    }

    private func bookSection(_ book: SBBook) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    bookTitle(book)
                    Spacer(minLength: 12)
                    addChapterButton(book)
                }

                VStack(alignment: .leading, spacing: 8) {
                    bookTitle(book)
                    addChapterButton(book)
                }
            }

            let bookChapters = book.chapterArray
            if bookChapters.isEmpty {
                Panel {
                    EmptyStateView(
                        title: "No Chapters",
                        message: "Begin the first chapter in \(book.name).",
                        systemImage: "doc.badge.plus"
                    )
                    .frame(minHeight: 120)
                }
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 12)], spacing: 12) {
                    ForEach(bookChapters, id: \.objectID) { chapter in
                        ChapterCard(chapter: chapter) {
                            openChapter(chapter)
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                ScriptoriumActions.deleteChapter(chapter, context: viewContext)
                            } label: {
                                Label("Delete Chapter", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    private func bookTitle(_ book: SBBook) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(book.name)
                .font(.title2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(book.testamentValue.label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
    }

    private func addChapterButton(_ book: SBBook) -> some View {
        Button {
            let chapter = ScriptoriumActions.createChapter(book: book, settings: settings, context: viewContext)
            openChapter(chapter)
        } label: {
            Label("Add Chapter", systemImage: "plus")
        }
        .buttonStyle(.bordered)
    }
}

private struct LibraryAddBookSheet: View {
    @Environment(\.dismiss) private var dismiss

    let books: [SBBook]
    let onCreate: (String, Testament) -> Void

    @State private var name = ""
    @State private var testament: Testament = .custom

    var body: some View {
        NavigationStack {
            Form {
                TextField("Book or section name", text: $name)
                Picker("Testament", selection: $testament) {
                    ForEach(Testament.allCases) { item in
                        Text(item.label).tag(item)
                    }
                }
            }
            .navigationTitle("New Book")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate(name, testament)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
