import { useEffect, useRef, useState } from "react";
import {
  Bold, Italic, Underline, Strikethrough, Heading1, Heading2, Hash, Indent, Outdent,
  CaseUpper, Type, Highlighter, Palette, Quote, BookOpenText, Asterisk,
  Play, Pause, Square, Eye, PencilLine, AlignLeft, AlignCenter, AlignRight, AlignJustify,
  List, ListOrdered, Undo2, Redo2, Link2, Link2Off, Eraser, Superscript, Subscript,
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
  try {
    document.execCommand("styleWithCSS", false, "true");
  } catch {}
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

const FONT_SIZES = [
  { label: "XS", px: "13px" },
  { label: "S",  px: "15px" },
  { label: "M",  px: "18px" },
  { label: "L",  px: "22px" },
  { label: "XL", px: "28px" },
  { label: "2XL", px: "34px" },
];

const BLOCKS: Array<{ label: string; tag: string; note?: string }> = [
  { label: "Paragraph", tag: "P" },
  { label: "Heading 1", tag: "H1" },
  { label: "Heading 2", tag: "H2" },
  { label: "Heading 3", tag: "H3" },
  { label: "Blockquote", tag: "BLOCKQUOTE" },
  { label: "Preformatted", tag: "PRE" },
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
  const [fontSize, setFontSize] = useState("M");

  useEffect(() => {
    if (editorRef.current && editorRef.current.innerHTML !== chapter.html) {
      editorRef.current.innerHTML = chapter.html;
    }
    const nums = Array.from(chapter.html.matchAll(/verse-num[^>]*>(\d+)</g)).map((m) => Number(m[1]));
    setNextVerse((nums.length ? Math.max(...nums) : 0) + 1);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [chapter.id]);

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

  const focusEditor = () => editorRef.current?.focus();

  const runCmd = (cmd: string, value?: string) => {
    focusEditor();
    exec(cmd, value);
    handleInput();
  };

  const handleSelection = () => {
    const sel = window.getSelection();
    if (sel && !sel.isCollapsed) onSelectionText(sel.toString());
  };

  const insertVerseNumber = () => {
    focusEditor();
    insertHTML(`<span class="verse-num">${nextVerse}</span>&nbsp;`);
    setNextVerse((n) => n + 1);
    handleInput();
  };

  const applyHighlight = (theme: HighlightTheme) => {
    focusEditor();
    wrapSelection(THEME_COLORS[theme].className);
    handleInput();
  };

  const applyColor = (color: string) => runCmd("foreColor", color);

  const applyFontSize = (label: string) => {
    setFontSize(label);
    const size = FONT_SIZES.find((f) => f.label === label);
    if (!size) return;
    const sel = window.getSelection();
    if (!sel || sel.isCollapsed) return;
    const range = sel.getRangeAt(0);
    const span = document.createElement("span");
    span.style.fontSize = size.px;
    try {
      span.appendChild(range.extractContents());
      range.insertNode(span);
      sel.removeAllRanges();
    } catch {}
    handleInput();
  };

  const applyBlock = (tag: string) => {
    focusEditor();
    exec("formatBlock", tag);
    if (tag === "BLOCKQUOTE") {
      const sel = window.getSelection();
      const node = sel?.anchorNode?.parentElement?.closest("blockquote");
      if (node) node.classList.add("poetic");
    }
    handleInput();
  };

  const insertLink = () => {
    const url = window.prompt("Link URL", "https://");
    if (!url) return;
    runCmd("createLink", url);
  };

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

  // Keyboard shortcuts
  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (!(e.metaKey || e.ctrlKey)) return;
    const k = e.key.toLowerCase();
    if (k === "b") { e.preventDefault(); runCmd("bold"); }
    else if (k === "i") { e.preventDefault(); runCmd("italic"); }
    else if (k === "u") { e.preventDefault(); runCmd("underline"); }
    else if (k === "k") { e.preventDefault(); insertLink(); }
    else if (k === "z" && !e.shiftKey) { e.preventDefault(); runCmd("undo"); }
    else if ((k === "z" && e.shiftKey) || k === "y") { e.preventDefault(); runCmd("redo"); }
  };

  const words = countWords(chapter.html);
  const status = STATUS_META[chapter.status];

  const IconBtn = ({ icon: Icon, label, onClick }: { icon: any; label: string; onClick: () => void }) => (
    <button
      title={label}
      aria-label={label}
      onClick={onClick}
      className="h-8 w-8 grid place-items-center rounded-md text-primary hover:bg-gold-soft/40 transition"
    >
      <Icon className="h-4 w-4" />
    </button>
  );

  const Divider = () => <div className="mx-1.5 h-6 w-px bg-border" />;

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
            {/* Block style */}
            <select
              onChange={(e) => { applyBlock(e.target.value); e.currentTarget.selectedIndex = 0; }}
              className="h-8 rounded-md border border-border bg-ivory px-2 text-xs font-display"
              defaultValue=""
              title="Paragraph style"
            >
              <option value="" disabled>Style</option>
              {BLOCKS.map((b) => <option key={b.tag} value={b.tag}>{b.label}</option>)}
            </select>

            {/* Font size */}
            <select
              value={fontSize}
              onChange={(e) => applyFontSize(e.target.value)}
              className="h-8 rounded-md border border-border bg-ivory px-2 text-xs font-display"
              title="Font size"
            >
              {FONT_SIZES.map((f) => <option key={f.label} value={f.label}>{f.label}</option>)}
            </select>

            <Divider />

            <IconBtn icon={Undo2} label="Undo (⌘Z)" onClick={() => runCmd("undo")} />
            <IconBtn icon={Redo2} label="Redo (⇧⌘Z)" onClick={() => runCmd("redo")} />

            <Divider />

            <IconBtn icon={Bold} label="Bold (⌘B)" onClick={() => runCmd("bold")} />
            <IconBtn icon={Italic} label="Italic (⌘I)" onClick={() => runCmd("italic")} />
            <IconBtn icon={Underline} label="Underline (⌘U)" onClick={() => runCmd("underline")} />
            <IconBtn icon={Strikethrough} label="Strikethrough" onClick={() => runCmd("strikeThrough")} />
            <IconBtn icon={Superscript} label="Superscript" onClick={() => runCmd("superscript")} />
            <IconBtn icon={Subscript} label="Subscript" onClick={() => runCmd("subscript")} />
            <IconBtn icon={Type} label="Small Caps" onClick={() => { focusEditor(); wrapSelection("small-caps"); handleInput(); }} />
            <IconBtn icon={CaseUpper} label="Uppercase Selection" onClick={() => {
              focusEditor();
              const sel = window.getSelection();
              if (!sel || sel.isCollapsed) return;
              insertHTML(sel.toString().toUpperCase());
              handleInput();
            }} />

            <Divider />

            <IconBtn icon={Heading1} label="Heading 1" onClick={() => runCmd("formatBlock", "H1")} />
            <IconBtn icon={Heading2} label="Heading 2" onClick={() => runCmd("formatBlock", "H2")} />
            <IconBtn icon={Quote} label="Poetic Blockquote" onClick={() => applyBlock("BLOCKQUOTE")} />
            <IconBtn icon={BookOpenText} label="Section Title" onClick={() => { focusEditor(); insertHTML(`<p class="no-indent"><span class="section-title">Section Title</span></p>`); handleInput(); }} />

            <Divider />

            <IconBtn icon={List} label="Bulleted list" onClick={() => runCmd("insertUnorderedList")} />
            <IconBtn icon={ListOrdered} label="Numbered list" onClick={() => runCmd("insertOrderedList")} />
            <IconBtn icon={Indent} label="Indent" onClick={() => runCmd("indent")} />
            <IconBtn icon={Outdent} label="Outdent" onClick={() => runCmd("outdent")} />

            <Divider />

            <IconBtn icon={AlignLeft} label="Align left" onClick={() => runCmd("justifyLeft")} />
            <IconBtn icon={AlignCenter} label="Align center" onClick={() => runCmd("justifyCenter")} />
            <IconBtn icon={AlignRight} label="Align right" onClick={() => runCmd("justifyRight")} />
            <IconBtn icon={AlignJustify} label="Justify" onClick={() => runCmd("justifyFull")} />

            <Divider />

            <button
              title="Insert verse number"
              onClick={insertVerseNumber}
              className="h-8 px-2 grid place-items-center rounded-md text-primary hover:bg-gold-soft/40 text-xs font-display inline-flex gap-1"
            >
              <Hash className="h-3.5 w-3.5" /> v{nextVerse}
            </button>
            <IconBtn icon={Asterisk} label="Footnote marker" onClick={() => { focusEditor(); insertHTML(`<sup class="footnote-marker">*</sup>`); handleInput(); }} />
            <IconBtn icon={Link2} label="Insert link (⌘K)" onClick={insertLink} />
            <IconBtn icon={Link2Off} label="Remove link" onClick={() => runCmd("unlink")} />
            <IconBtn icon={Eraser} label="Clear formatting" onClick={() => runCmd("removeFormat")} />

            <Divider />

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
              onKeyDown={handleKeyDown}
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
