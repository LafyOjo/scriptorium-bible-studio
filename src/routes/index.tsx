import { createFileRoute } from "@tanstack/react-router";
import { useEffect, useMemo, useState } from "react";
import { useScriptorium } from "@/lib/scriptorium/store";
import { LeftPanel } from "@/components/scriptorium/LeftPanel";
import { RightPanel } from "@/components/scriptorium/RightPanel";
import { Dashboard } from "@/components/scriptorium/Dashboard";
import { Library } from "@/components/scriptorium/Library";
import { ChapterEditor } from "@/components/scriptorium/ChapterEditor";

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "Scriptorium Bible Studio — Author your own scripture" },
      { name: "description", content: "A premium authoring, annotation and reading studio for writing your own version of the Bible." },
      { property: "og:title", content: "Scriptorium Bible Studio" },
      { property: "og:description", content: "A private manuscript studio for writing, annotating and publishing your own Bible." },
    ],
  }),
  component: Studio,
});

type View = "dashboard" | "library" | "editor";

function Studio() {
  const s = useScriptorium();
  const [view, setView] = useState<View>("dashboard");
  const [activeChapterId, setActiveChapterId] = useState<string | null>(null);
  const [selectionText, setSelectionText] = useState("");
  const [mounted, setMounted] = useState(false);
  useEffect(() => { setMounted(true); }, []);


  useEffect(() => {
    if (!activeChapterId && s.state.chapters[0]) {
      setActiveChapterId(s.state.chapters[0].id);
    }
  }, [s.state.chapters, activeChapterId]);

  const activeChapter = useMemo(
    () => s.state.chapters.find((c) => c.id === activeChapterId) ?? null,
    [s.state.chapters, activeChapterId],
  );
  const activeBook = useMemo(
    () => (activeChapter ? s.state.books.find((b) => b.id === activeChapter.bookId) ?? null : null),
    [s.state.books, activeChapter],
  );

  const openChapter = (id: string) => {
    setActiveChapterId(id);
    setView("editor");
  };

  return (
    <div className="min-h-screen w-full p-3 lg:p-4">
      {!mounted ? (
        <div className="h-[calc(100vh-1.5rem)] lg:h-[calc(100vh-2rem)] parchment-panel rounded-2xl grid place-items-center">
          <div className="text-center">
            <div className="font-display text-xs tracking-widest text-muted-foreground uppercase">Scriptorium</div>
            <div className="gold-divider my-3 mx-auto w-24" />
            <p className="font-serif text-lg text-primary">Opening the manuscript…</p>
          </div>
        </div>
      ) : (
      <div className="flex h-[calc(100vh-1.5rem)] lg:h-[calc(100vh-2rem)] gap-3 lg:gap-4">

        <LeftPanel
          view={view}
          onView={setView}
          books={s.state.books}
          chapters={s.state.chapters}
          collections={s.state.collections}
          activeChapterId={activeChapterId}
          onSelectChapter={openChapter}
          onAddBook={(name, collectionId) => { s.addBook(name, "custom", collectionId); }}
          onAddChapter={(bookId) => { const id = s.addChapter(bookId); openChapter(id); }}
          onAddCollection={(name) => { s.addCollection(name); }}
        />

        <main className="flex-1 min-w-0 flex">
          {view === "dashboard" && (
            <div className="flex-1 parchment-panel rounded-2xl overflow-hidden flex flex-col">
              <Dashboard
                state={s.state}
                onContinue={openChapter}
                onReader={openChapter}
                onOpenLibrary={() => setView("library")}
              />
            </div>
          )}
          {view === "library" && (
            <div className="flex-1 parchment-panel rounded-2xl overflow-hidden flex flex-col">
              <Library
                books={s.state.books}
                chapters={s.state.chapters}
                onOpenChapter={openChapter}
                onAddChapter={(bookId) => { const id = s.addChapter(bookId); openChapter(id); }}
                onAddBook={() => {
                  const name = window.prompt("Name of the new book or section?");
                  if (name?.trim()) s.addBook(name.trim(), "custom");
                }}
              />
            </div>
          )}
          {view === "editor" && activeChapter && activeBook && (
            <div className="flex-1 min-w-0">
              <ChapterEditor
                chapter={activeChapter}
                book={activeBook}
                onChange={(patch) => s.updateChapter(activeChapter.id, patch)}
                onSelectionText={setSelectionText}
              />
            </div>
          )}
          {view === "editor" && !activeChapter && (
            <div className="flex-1 parchment-panel rounded-2xl grid place-items-center">
              <div className="text-center max-w-sm p-8">
                <div className="font-display text-xs tracking-widest text-muted-foreground uppercase">Empty Page</div>
                <div className="gold-divider my-3" />
                <p className="font-serif text-lg text-primary">Select or create a chapter to begin.</p>
              </div>
            </div>
          )}
        </main>

        <RightPanel
          state={s.state}
          activeChapter={activeChapter}
          activeBook={activeBook}
          selectionText={selectionText}
          onAddBookmark={s.addBookmark}
          onRemoveBookmark={s.removeBookmark}
          onAddNote={s.addNote}
          onRemoveNote={s.removeNote}
          onSelectChapter={openChapter}
        />
      </div>
      )}
    </div>
  );
}

