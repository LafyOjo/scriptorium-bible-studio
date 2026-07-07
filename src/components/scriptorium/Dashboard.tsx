import { useMemo } from "react";
import { BookOpen, Bookmark, Clock, Feather, PenLine, ScrollText } from "lucide-react";
import type { ScriptoriumState } from "@/lib/scriptorium/store";
import { countWords } from "@/lib/scriptorium/store";
import { STATUS_META } from "@/lib/scriptorium/types";

type Props = {
  state: ScriptoriumState;
  onContinue: (chapterId: string) => void;
  onReader: (chapterId: string) => void;
  onOpenLibrary: () => void;
};

export function Dashboard({ state, onContinue, onReader, onOpenLibrary }: Props) {
  const totalBooks = state.books.length;
  const totalChapters = state.chapters.length;
  const totalWords = useMemo(() => state.chapters.reduce((a, c) => a + countWords(c.html), 0), [state.chapters]);
  const complete = state.chapters.filter((c) => c.status === "complete").length;
  const progress = totalChapters ? Math.round((complete / totalChapters) * 100) : 0;
  const recent = [...state.chapters].sort((a, b) => b.updatedAt - a.updatedAt).slice(0, 5);
  const last = recent[0];
  const book = last ? state.books.find((b) => b.id === last.bookId) : null;

  return (
    <div className="flex-1 overflow-auto">
      <div className="mx-auto max-w-6xl p-8 space-y-8">
        <header className="text-center">
          <div className="font-display text-[10px] tracking-[0.5em] text-oxblood uppercase">Author's Study</div>
          <h1 className="mt-2 font-serif text-5xl text-primary">The Scriptorium</h1>
          <div className="gold-divider mt-4 mx-auto max-w-md" />
          <p className="mt-4 text-sm italic text-muted-foreground">
            A private atelier for writing your own version of the sacred text.
          </p>
        </header>

        <section className="grid gap-4 md:grid-cols-4">
          <Stat icon={BookOpen} label="Books" value={totalBooks} />
          <Stat icon={ScrollText} label="Chapters written" value={totalChapters} />
          <Stat icon={Feather} label="Words penned" value={totalWords.toLocaleString()} />
          <Stat icon={Bookmark} label="Bookmarks" value={state.bookmarks.length} />
        </section>

        <section className="grid gap-4 md:grid-cols-2">
          <Card>
            <div className="flex items-center gap-2">
              <PenLine className="h-4 w-4 text-oxblood" />
              <div className="font-display text-xs tracking-widest uppercase">Continue Writing</div>
            </div>
            {last && book ? (
              <>
                <div className="mt-3 font-serif text-2xl text-primary">{book.name} · {last.number}. {last.title}</div>
                <div className="mt-1 text-xs text-muted-foreground">
                  {countWords(last.html)} words · {STATUS_META[last.status].label} · edited {new Date(last.updatedAt).toLocaleDateString()}
                </div>
                <button
                  onClick={() => onContinue(last.id)}
                  className="mt-4 inline-flex items-center gap-2 rounded-md bg-primary px-4 py-2 text-sm text-primary-foreground hover:bg-oxblood"
                >
                  Return to the page
                </button>
              </>
            ) : (
              <div className="mt-3 text-sm italic text-muted-foreground">Begin your first chapter.</div>
            )}
          </Card>

          <Card>
            <div className="flex items-center gap-2">
              <BookOpen className="h-4 w-4 text-oxblood" />
              <div className="font-display text-xs tracking-widest uppercase">Reader Mode</div>
            </div>
            <div className="mt-3 font-serif text-2xl text-primary">Read your Bible</div>
            <p className="mt-1 text-xs text-muted-foreground">Preview your work as a finished manuscript, with read-aloud.</p>
            <button
              onClick={() => last && onReader(last.id)}
              className="mt-4 inline-flex items-center gap-2 rounded-md border border-gold bg-gold-soft/40 px-4 py-2 text-sm text-primary hover:bg-gold-soft/70"
            >
              Enter reader mode
            </button>
          </Card>
        </section>

        <section>
          <div className="mb-2 flex items-center justify-between">
            <div className="font-display text-xs tracking-widest uppercase text-muted-foreground">Writing Progress</div>
            <div className="text-xs text-muted-foreground">{complete}/{totalChapters} complete</div>
          </div>
          <div className="h-2 w-full rounded-full bg-secondary overflow-hidden">
            <div className="h-full bg-gradient-to-r from-gold-soft to-gold" style={{ width: `${progress}%` }} />
          </div>
        </section>

        <section>
          <div className="mb-3 flex items-center gap-2">
            <Clock className="h-4 w-4 text-oxblood" />
            <div className="font-display text-xs tracking-widest uppercase">Recently Edited</div>
          </div>
          <div className="grid gap-3 md:grid-cols-2 lg:grid-cols-3">
            {recent.map((c) => {
              const b = state.books.find((x) => x.id === c.bookId);
              return (
                <button
                  key={c.id}
                  onClick={() => onContinue(c.id)}
                  className="text-left rounded-xl p-4 parchment-panel hover:border-gold transition"
                >
                  <div className="text-[10px] uppercase tracking-widest text-muted-foreground font-display">
                    {b?.name} · Chapter {c.number}
                  </div>
                  <div className="mt-1 font-serif text-lg text-primary">{c.title}</div>
                  <div className="mt-2 flex items-center gap-2 text-[11px]">
                    <span className="h-1.5 w-1.5 rounded-full" style={{ background: STATUS_META[c.status].color }} />
                    <span className="text-muted-foreground">{STATUS_META[c.status].label}</span>
                    <span className="ml-auto text-muted-foreground">{countWords(c.html)}w</span>
                  </div>
                </button>
              );
            })}
          </div>
        </section>

        {state.bookmarks.length > 0 && (
          <section>
            <div className="mb-3 flex items-center gap-2">
              <Bookmark className="h-4 w-4 text-oxblood" />
              <div className="font-display text-xs tracking-widest uppercase">Bookmarks</div>
            </div>
            <ul className="grid gap-2 md:grid-cols-2">
              {state.bookmarks.slice(0, 6).map((b) => (
                <li key={b.id} className="rounded-md border border-border bg-ivory p-3 text-sm">
                  <div className="font-serif text-primary">{b.label}</div>
                  {b.passage && <div className="text-xs italic text-ink/70 mt-0.5 line-clamp-2">“{b.passage}”</div>}
                </li>
              ))}
            </ul>
          </section>
        )}

        <div className="text-center">
          <button onClick={onOpenLibrary} className="text-xs text-muted-foreground hover:text-primary underline underline-offset-4">
            Browse the full library →
          </button>
        </div>
      </div>
    </div>
  );
}

function Stat({ icon: Icon, label, value }: { icon: any; label: string; value: number | string }) {
  return (
    <div className="rounded-xl p-4 parchment-panel">
      <div className="flex items-center gap-2">
        <Icon className="h-4 w-4 text-gold" />
        <div className="text-[10px] uppercase tracking-widest text-muted-foreground">{label}</div>
      </div>
      <div className="mt-2 font-serif text-3xl text-primary">{value}</div>
    </div>
  );
}

function Card({ children }: { children: React.ReactNode }) {
  return <div className="rounded-2xl p-5 parchment-panel">{children}</div>;
}
