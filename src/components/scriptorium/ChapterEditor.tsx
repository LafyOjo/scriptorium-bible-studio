import { useEffect, useRef, useState } from "react";
import {
  Bold, Italic, Underline, Heading1, Hash, Indent, CaseUpper, Type,
  Highlighter, Palette, Quote, BookOpenText, Asterisk, Play, Pause, Square, Eye, PencilLine,
} from "lucide-react";
import { THEME_COLORS, STATUS_META, type HighlightTheme } from "@/lib/scriptorium/types";
import type { Chapter, Book } from "@/lib/scriptorium/store";
import { countWords, htmlToPlainText } from "@/lib/scriptorium/store";
import { cn } from "@/lib/utils";

type Props = {
  chapter: Chapter;
  book: Book;
  onChange: (patch: Partial<Chapter>) => void;
  onSelectionText: (text: string) => void;
};

function exec(cmd: string, value?: string) {
  // eslint-disable-next-line deprecation/deprecation
  document.execCommand(cmd, false, value);
}

function wrapSelection(className: string) {
  const sel = window.getSelection();
  if (!sel || sel.rangeCount === 0 || sel.isCollapsed) return;
  const range = sel.getRangeAt(0);
  const span = document.createElement("span");
  span.className = className;
  try {
    span.appendChild(range.extractContents());
    range.insertNode(span);
    sel.removeAllRanges();
  } catch {}
}

function insertHTML(html: string) {
  exec("insertHTML", html);
}

const TOOLS = [
  { icon: Bold, label: "Bold", run: () => exec("bold") },
  { icon: Italic, label: "Italic", run: () => exec("italic") },
  { icon: Underline, label: "Underline", run: () => exec("underline") },
  { icon: Heading1, label: "Heading", run: () => exec("formatBlock", "H2") },
  { icon: Indent, label: "Indent Paragraph", run: () => exec("indent") },
  { icon: CaseUpper, label: "Uppercase Selection", run: () => {
    const sel = window.getSelection();
    if (!sel || sel.isCollapsed) return;
    const text = sel.toString().toUpperCase();
    insertHTML(text);
  } },
  { icon: Type, label: "Small Caps", run: () => wrapSelection("small-caps") },
  { icon: Quote, label: "Poetic Blockquote", run: () => {
    exec("formatBlock", "BLOCKQUOTE");
    const sel = window.getSelection();
    const node = sel?.anchorNode?.parentElement?.closest("blockquote");
    if (node) node.classList.add("poetic");
  } },
  { icon: BookOpenText, label: "Section Title", run: () => insertHTML(`<p class="no-indent"><span class="section-title">Section Title</span></p>`) },
  { icon: Asterisk, label: "Footnote Marker", run: () => insertHTML(`<sup class="footnote-marker">*</sup>`) },
];

export function ChapterEditor({ chapter, book, onChange, onSelectionText }: Props) {
  const editorRef = useRef<HTMLDivElement>(null);
  const [mode, setMode] = useState<"edit" | "reader">("edit");
  const [saveState, setSaveState] = useState<"saved" | "saving">("saved");
  const [nextVerse, setNextVerse] = useState(() => {
    const nums = Array.from(chapter.html.matchAll(/verse-num[^>]*>(\d+)</g)).map((m) => Number(m[1]));
    return (nums.length ? Math.max(...nums) : 0) + 1;
  });
  const [speaking, setSpeaking] = useState(false);
  const [paused, setPaused] = useState(false);

  // Load content on chapter change
  useEffect(() => {
    if (editorRef.current && editorRef.current.innerHTML !== chapter.html) {
      editorRef.current.innerHTML = chapter.html;
    }
    const nums = Array.from(chapter.html.matchAll(/verse-num[^>]*>(\d+)</g)).map((m) => Number(m[1]));
    setNextVerse((nums.length ? Math.max(...nums) : 0) + 1);
  }, [chapter.id]);

  // Autosave (debounced)
  const timer = useRef<number | null>(null);
  const handleInput = () => {
    if (!editorRef.current) return;
    setSaveState("saving");
    if (timer.current) window.clearTimeout(timer.current);
    timer.current = window.setTimeout(() => {
      onChange({ html: editorRef.current!.innerHTML });
      setSaveState("saved");
    }, 500);
  };

  const handleSelection = () => {
    const sel = window.getSelection();
    if (sel && !sel.isCollapsed) onSelectionText(sel.toString());
  };

  const insertVerseNumber = () => {
    insertHTML(`<span class="verse-num">${nextVerse}</span>`);
    setNextVerse((n) => n + 1);
    handleInput();
  };

  const applyHighlight = (theme: HighlightTheme) => {
    wrapSelection(THEME_COLORS[theme].className);
    handleInput();
  };

  const applyColor = (color: string) => {
    exec("foreColor", color);
    handleInput();
  };

  // Read aloud
  const utteranceRef = useRef<SpeechSynthesisUtterance | null>(null);
  const startReading = () => {
    if (typeof window === "undefined" || !("speechSynthesis" in window)) return;
    window.speechSynthesis.cancel();
    const text = htmlToPlainText(chapter.html);
    const u = new SpeechSynthesisUtterance(text);
    u.rate = 0.95;
    u.pitch = 1;
    u.onend = () => { setSpeaking(false); setPaused(false); };
    utteranceRef.current = u;
    window.speechSynthesis.speak(u);
    setSpeaking(true);
    setPaused(false);
  };
  const pauseReading = () => { window.speechSynthesis.pause(); setPaused(true); };
  const resumeReading = () => { window.speechSynthesis.resume(); setPaused(false); };
  const stopReading = () => { window.speechSynthesis.cancel(); setSpeaking(false); setPaused(false); };
  useEffect(() => () => { if (typeof window !== "undefined") window.speechSynthesis?.cancel(); }, []);

  const words = countWords(chapter.html);
  const status = STATUS_META[chapter.status];

  return (
    <div className="flex h-full flex-col parchment-panel rounded-2xl overflow-hidden">
      {/* Header */}
      <div className="flex flex-col gap-3 px-6 pt-5 pb-3 border-b border-border/60">
        <div className="grid grid-cols-[minmax(0,1fr)_auto] items-center gap-4 sm:flex sm:flex-wrap sm:justify-between">
          <div className="min-w-0">
            <div className="text-xs uppercase tracking-[0.3em] text-muted-foreground font-display">
              {book.name} · Chapter {chapter.number}
            </div>
            <input
              className="mt-1 w-full bg-transparent font-serif text-3xl font-semibold text-primary outline-none placeholder:text-muted-foreground/50"
              value={chapter.title}
              onChange={(e) => onChange({ title: e.target.value })}
              placeholder="Chapter title"
            />
          </div>
          <div className="flex shrink-0 items-center gap-2">
            <span className="inline-flex items-center gap-2 rounded-full border border-border/60 bg-ivory/60 px-3 py-1 text-xs">
              <span className="h-2 w-2 rounded-full" style={{ background: status.color }} />
              {status.label}
            </span>
            <select
              value={chapter.status}
              onChange={(e) => onChange({ status: e.target.value as Chapter["status"] })}
              className="rounded-md border border-border bg-ivory px-2 py-1 text-xs"
            >
              {Object.entries(STATUS_META).map(([k, v]) => (
                <option key={k} value={k}>{v.label}</option>
              ))}
            </select>
            <div className="flex overflow-hidden rounded-md border border-border">
              <button
                onClick={() => setMode("edit")}
                className={cn("px-2.5 py-1 text-xs inline-flex items-center gap-1", mode === "edit" ? "bg-primary text-primary-foreground" : "bg-ivory text-foreground")}
              >
                <PencilLine className="h-3.5 w-3.5" /> Editor
              </button>
              <button
                onClick={() => setMode("reader")}
                className={cn("px-2.5 py-1 text-xs inline-flex items-center gap-1", mode === "reader" ? "bg-primary text-primary-foreground" : "bg-ivory text-foreground")}
              >
                <Eye className="h-3.5 w-3.5" /> Reader
              </button>
            </div>
          </div>
        </div>

        {/* Toolbar */}
        {mode === "edit" && (
          <div className="flex flex-wrap items-center gap-1 border-t border-border/50 pt-3">
            {TOOLS.map((t) => (
              <button
                key={t.label}
                title={t.label}
                onClick={() => { t.run(); handleInput(); }}
                className="h-8 w-8 grid place-items-center rounded-md text-primary hover:bg-gold-soft/40"
              >
                <t.icon className="h-4 w-4" />
              </button>
            ))}
            <button
              title="Insert verse number"
              onClick={insertVerseNumber}
              className="h-8 px-2 grid place-items-center rounded-md text-primary hover:bg-gold-soft/40 text-xs font-display inline-flex gap-1"
            >
              <Hash className="h-3.5 w-3.5" /> v{nextVerse}
            </button>

            <div className="mx-2 h-6 w-px bg-border" />

            <div className="group relative">
              <button className="h-8 px-2 inline-flex items-center gap-1 rounded-md hover:bg-gold-soft/40 text-xs">
                <Highlighter className="h-4 w-4" /> Highlight
              </button>
              <div className="absolute left-0 top-full z-20 mt-1 hidden group-hover:grid grid-cols-3 gap-1 rounded-lg border border-border bg-popover p-2 shadow-lg">
                {(Object.keys(THEME_COLORS) as HighlightTheme[]).map((k) => (
                  <button
                    key={k}
                    onClick={() => applyHighlight(k)}
                    title={THEME_COLORS[k].label}
                    className="flex items-center gap-1.5 rounded px-1.5 py-1 text-xs hover:bg-muted whitespace-nowrap"
                  >
                    <span className="h-3 w-3 rounded-sm border border-border" style={{ background: THEME_COLORS[k].swatch }} />
                    {THEME_COLORS[k].label}
                  </button>
                ))}
              </div>
            </div>

            <div className="group relative">
              <button className="h-8 px-2 inline-flex items-center gap-1 rounded-md hover:bg-gold-soft/40 text-xs">
                <Palette className="h-4 w-4" /> Colour
              </button>
              <div className="absolute left-0 top-full z-20 mt-1 hidden group-hover:flex gap-1 rounded-lg border border-border bg-popover p-2 shadow-lg">
                {["#3b2a1a", "#7a1f13", "#8a6a1e", "#2f5230", "#1f3b6b", "#5c2a72", "#111111"].map((c) => (
                  <button key={c} onClick={() => applyColor(c)} className="h-5 w-5 rounded-full border border-border" style={{ background: c }} />
                ))}
              </div>
            </div>

            <div className="ml-auto flex items-center gap-3 text-xs text-muted-foreground">
              <span>{words} words</span>
              <span>· {saveState === "saved" ? "Saved" : "Saving…"}</span>
            </div>
          </div>
        )}

        {/* Read aloud row */}
        <div className="flex items-center gap-2 pt-1">
          {!speaking ? (
            <button onClick={startReading} className="inline-flex items-center gap-1.5 rounded-full border border-gold bg-gold-soft/40 px-3 py-1 text-xs text-primary hover:bg-gold-soft/70">
              <Play className="h-3.5 w-3.5" /> Read aloud
            </button>
          ) : (
            <>
              {paused ? (
                <button onClick={resumeReading} className="inline-flex items-center gap-1.5 rounded-full border border-gold bg-gold-soft/60 px-3 py-1 text-xs">
                  <Play className="h-3.5 w-3.5" /> Resume
                </button>
              ) : (
                <button onClick={pauseReading} className="inline-flex items-center gap-1.5 rounded-full border border-gold bg-gold-soft/60 px-3 py-1 text-xs">
                  <Pause className="h-3.5 w-3.5" /> Pause
                </button>
              )}
              <button onClick={stopReading} className="inline-flex items-center gap-1.5 rounded-full border border-border bg-ivory px-3 py-1 text-xs">
                <Square className="h-3.5 w-3.5" /> Stop
              </button>
              <span className="text-xs text-muted-foreground">Reading with browser voice…</span>
            </>
          )}
        </div>
      </div>

      {/* Content */}
      <div className="flex-1 overflow-auto">
        <div className="mx-auto max-w-3xl px-8 py-8">
          {mode === "edit" ? (
            <div
              ref={editorRef}
              contentEditable
              suppressContentEditableWarning
              onInput={handleInput}
              onMouseUp={handleSelection}
              onKeyUp={handleSelection}
              className="reader-prose font-serif text-lg leading-relaxed text-ink outline-none min-h-[60vh]"
              spellCheck
            />
          ) : (
            <div
              className="reader-prose font-serif text-lg leading-relaxed text-ink"
              dangerouslySetInnerHTML={{ __html: chapter.html }}
            />
          )}
        </div>
      </div>
    </div>
  );
}
