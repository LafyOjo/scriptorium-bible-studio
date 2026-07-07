import { Plus } from "lucide-react";
import { STATUS_META } from "@/lib/scriptorium/types";
import type { Book, Chapter } from "@/lib/scriptorium/store";
import { countWords } from "@/lib/scriptorium/store";

type Props = {
  books: Book[];
  chapters: Chapter[];
  onOpenChapter: (id: string) => void;
  onAddChapter: (bookId: string) => void;
  onAddBook: () => void;
};

export function Library({ books, chapters, onOpenChapter, onAddChapter, onAddBook }: Props) {
  return (
    <div className="flex-1 overflow-auto">
      <div className="mx-auto max-w-6xl p-8 space-y-8">
        <header className="flex items-end justify-between">
          <div>
            <div className="font-display text-[10px] tracking-[0.5em] text-oxblood uppercase">Volume Index</div>
            <h1 className="mt-1 font-serif text-4xl text-primary">Bible Library</h1>
          </div>
          <button onClick={onAddBook}
            className="inline-flex items-center gap-1 rounded-md bg-primary px-3 py-2 text-xs text-primary-foreground">
            <Plus className="h-3.5 w-3.5" /> New book / section
          </button>
        </header>
        <div className="gold-divider" />

        {books.map((b) => {
          const list = chapters.filter((c) => c.bookId === b.id).sort((a, z) => a.number - z.number);
          return (
            <section key={b.id}>
              <div className="mb-3 flex items-baseline justify-between">
                <div>
                  <h2 className="font-serif text-2xl text-primary">{b.name}</h2>
                  <div className="text-xs text-muted-foreground uppercase tracking-widest">{b.testament} testament</div>
                </div>
                <button onClick={() => onAddChapter(b.id)}
                  className="inline-flex items-center gap-1 text-xs text-primary hover:text-oxblood">
                  <Plus className="h-3.5 w-3.5" /> Add chapter
                </button>
              </div>
              <div className="grid gap-3 md:grid-cols-2 lg:grid-cols-3">
                {list.length === 0 && (
                  <div className="rounded-lg border border-dashed border-border p-6 text-center text-sm italic text-muted-foreground">
                    No chapters yet. Begin the first.
                  </div>
                )}
                {list.map((c) => (
                  <button key={c.id} onClick={() => onOpenChapter(c.id)}
                    className="text-left rounded-xl p-4 parchment-panel hover:border-gold transition">
                    <div className="flex items-center justify-between">
                      <div className="font-display text-xs tracking-widest text-muted-foreground">CHAPTER {c.number}</div>
                      <span className="inline-flex items-center gap-1.5 rounded-full border border-border bg-ivory px-2 py-0.5 text-[10px]">
                        <span className="h-1.5 w-1.5 rounded-full" style={{ background: STATUS_META[c.status].color }} />
                        {STATUS_META[c.status].label}
                      </span>
                    </div>
                    <div className="mt-2 font-serif text-xl text-primary">{c.title}</div>
                    <div className="mt-2 text-[11px] text-muted-foreground">
                      {countWords(c.html)} words · edited {new Date(c.updatedAt).toLocaleDateString()}
                    </div>
                  </button>
                ))}
              </div>
            </section>
          );
        })}
      </div>
    </div>
  );
}
