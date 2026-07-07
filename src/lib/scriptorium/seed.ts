import type { ScriptoriumState } from "./types";

const uid = () => Math.random().toString(36).slice(2, 10);

const genesis1 = `
<p class="no-indent"><span class="section-title">The Beginning</span></p>
<p><span class="verse-num">1</span>In the beginning, the Eternal spoke, and by the Word all things came to be — the heavens above and the earth beneath.</p>
<p><span class="verse-num">2</span>The earth was without shape, a deep silence upon the waters, and the Spirit of God moved gently over the face of the deep like a whisper over still glass.</p>
<p><span class="verse-num">3</span>Then God said, <em>Let there be light</em> — and light broke forth, warm and clean, dividing the darkness.</p>
<p><span class="verse-num">4</span>God saw the light, that it was good, and He set a boundary between the light and the darkness.</p>
<p><span class="verse-num">5</span>He named the light <span class="small-caps">Day</span>, and the darkness He named <span class="small-caps">Night</span>. And there was evening, and there was morning — the first day.</p>
`;

const psalms1 = `
<p class="no-indent"><span class="section-title">Psalm of the Two Paths</span></p>
<blockquote class="poetic"><span class="verse-num">1</span>Blessed is the one who does not walk in the counsel of the wicked, nor linger in the way of scoffers.</blockquote>
<blockquote class="poetic"><span class="verse-num">2</span>But in the law of the Lord is their delight, and on His word they meditate through the long hours of the night.</blockquote>
<blockquote class="poetic"><span class="verse-num">3</span>They shall be like a tree planted beside living streams — bearing fruit in its season, whose leaf shall not wither.</blockquote>
`;

const john1 = `
<p class="no-indent"><span class="section-title">The Word Made Flesh</span></p>
<p><span class="verse-num">1</span>In the beginning was the <span class="small-caps">Word</span>, and the Word was with God, and the Word was God.</p>
<p><span class="verse-num">2</span>He was in the beginning with God.</p>
<p><span class="verse-num">3</span>Through Him all things were made; without Him nothing was made that has been made.</p>
<p><span class="verse-num">4</span>In Him was life, and that life was the light of humankind.</p>
<p><span class="verse-num">5</span>The light shines in the darkness, and the darkness has not overcome it.</p>
`;

const revelation1 = `
<p class="no-indent"><span class="section-title">The Vision on Patmos</span></p>
<p><span class="verse-num">1</span>The revelation of Jesus, the Anointed, which God gave Him to show His servants — things which must soon come to pass.</p>
<p><span class="verse-num">2</span>I, John, your brother and companion in tribulation, was upon the isle called Patmos, for the Word of God and the testimony of Jesus.</p>
<p><span class="verse-num">3</span>I was in the Spirit on the Lord's day, and I heard behind me a great voice, as of a trumpet.</p>
`;

export function seedState(): ScriptoriumState {
  const ot = { id: uid(), name: "Old Testament Draft" };
  const nt = { id: uid(), name: "New Testament Draft" };
  const done = { id: uid(), name: "Completed Chapters" };
  const rev = { id: uid(), name: "Needs Revision" };
  const fav = { id: uid(), name: "Favourite Passages" };

  const genesis = { id: uid(), name: "Genesis", testament: "old" as const, collectionId: ot.id, order: 1 };
  const psalms = { id: uid(), name: "Psalms", testament: "old" as const, collectionId: ot.id, order: 2 };
  const john = { id: uid(), name: "John", testament: "new" as const, collectionId: nt.id, order: 3 };
  const revelation = { id: uid(), name: "Revelation", testament: "new" as const, collectionId: nt.id, order: 4 };

  const now = Date.now();

  return {
    version: 1,
    collections: [ot, nt, done, rev, fav],
    books: [genesis, psalms, john, revelation],
    bookmarks: [
      { id: uid(), bookId: john.id, label: "The Word Made Flesh", passage: "John 1:1–5", createdAt: now },
    ],
    chapters: [
      { id: uid(), bookId: genesis.id, number: 1, title: "The Beginning", html: genesis1, status: "drafting", tags: ["creation"], updatedAt: now, notes: [] },
      { id: uid(), bookId: psalms.id, number: 1, title: "The Two Paths", html: psalms1, status: "revised", tags: ["wisdom", "poetry"], updatedAt: now - 86400000, notes: [] },
      { id: uid(), bookId: john.id, number: 1, title: "The Word", html: john1, status: "complete", tags: ["christology"], updatedAt: now - 172800000, notes: [] },
      { id: uid(), bookId: revelation.id, number: 1, title: "Vision on Patmos", html: revelation1, status: "drafting", tags: ["apocalyptic"], updatedAt: now - 259200000, notes: [] },
    ],
  };
}
