// ============================================================================
// Conversion service — splits text into sentences, calls the ithuan API
// (proxied via /api/tau) to produce token-aligned 漢字 + Tâi-lô.
// ============================================================================

(function (global) {
  // Split into sentence-units by Chinese/Latin sentence punctuation.
  // We KEEP the punctuation as part of the preceding sentence.
  // Returns [{ text, paragraph }] — paragraph index increments on blank lines
  // (>=2 consecutive newlines) or on every \n if the input only uses single
  // line breaks to separate paragraphs.
  const SENT_PUNCT = '。！？，；：!?,;:';
  function splitSentences(text) {
    if (!text) return [];
    const hasBlankLines = /\n\s*\n/.test(text);
    const paraBlocks = hasBlankLines
      ? text.split(/\n\s*\n+/)
      : text.split(/\n+/);
    const out = [];
    paraBlocks.forEach((block, pIdx) => {
      let buf = '';
      for (const ch of block) {
        if (ch === '\n') { buf += ' '; continue; }
        buf += ch;
        if (SENT_PUNCT.includes(ch)) {
          const t = buf.trim();
          if (t) out.push({ text: t, paragraph: pIdx });
          buf = '';
        }
      }
      const tail = buf.trim();
      if (tail) out.push({ text: tail, paragraph: pIdx });
    });
    return out;
  }

  // ithuan returns 分詞 as space-separated "han｜tailo" tokens, where multi-
  // syllable words use "-" inside both halves (e.g. "想-袂-曉｜siūnn-bē-hiáu").
  // Neutral-tone particles use a "--" prefix (e.g. "--的｜--ê").
  // For display we strip dashes from the han side (tailo's hyphens are
  // meaningful and stay).
  function parseFenchi(fenchi) {
    if (!fenchi) return [];
    return fenchi.split(' ').filter(Boolean).map(piece => {
      const sep = piece.indexOf('｜');
      const rawHan = sep >= 0 ? piece.slice(0, sep) : piece;
      const tailo = sep >= 0 ? piece.slice(sep + 1) : '';
      const han = rawHan.replace(/-/g, '');
      return { han, tailo, gloss: '' };
    });
  }

  const cache = new Map();
  const inflight = new Map();

  async function convertSentence(sentence) {
    if (cache.has(sentence)) return cache.get(sentence);
    if (inflight.has(sentence)) return inflight.get(sentence);

    const promise = (async () => {
      const body = 'taibun=' + encodeURIComponent(sentence);
      const r = await fetch('/api/tau', {
        method: 'POST',
        headers: { 'content-type': 'application/x-www-form-urlencoded' },
        body,
      });
      if (!r.ok) throw new Error('Conversion failed (' + r.status + ')');
      const data = await r.json();
      const tokens = parseFenchi(data['分詞']);
      cache.set(sentence, tokens);
      return tokens;
    })();

    inflight.set(sentence, promise);
    try { return await promise; }
    finally { inflight.delete(sentence); }
  }

  // Stub: detailed per-word lookup is not implemented yet.
  async function lookupWord(han, tailo) {
    return { han, tailo: tailo || '', gloss: '', pos: '', examples: [], stub: true };
  }

  global.TaigiConvert = { splitSentences, convertSentence, lookupWord };
})(window);
