// ============================================================================
// Tâi-lô helpers — convert between diacritic and numeric tone notation.
// Tâi-lô tones 1–9 (and 0 for neutral). Tone marks go on the syllable nucleus.
// ============================================================================

(function (global) {
  // Vowel priority for placing the tone mark in Tâi-lô (TL):
  // 1) "oo" → on first 'o'
  // 2) a > e > o > u > i > m > n > ng
  const VOWEL_PRIORITY = ['a', 'e', 'o', 'u', 'i'];

  // tone -> diacritic char map by base vowel
  // 1 = unmarked, 2 = ́ (acute), 3 = ̀ (grave), 4 = unmarked (entering, ends p/t/k/h),
  // 5 = ̂ (circumflex), 6 = (rare in TL, treat as 7), 7 = ̄ (macron),
  // 8 =  ̍ (vertical line above) — TL uses combining diacritic
  // We use precomposed where possible.
  const TONE_MARKS = {
    a: { 1: 'a', 2: 'á', 3: 'à', 4: 'a', 5: 'â', 6: 'ǎ', 7: 'ā', 8: 'a̍', 9: 'a̋', 0: 'a' },
    e: { 1: 'e', 2: 'é', 3: 'è', 4: 'e', 5: 'ê', 6: 'ě', 7: 'ē', 8: 'e̍', 9: 'e̋', 0: 'e' },
    i: { 1: 'i', 2: 'í', 3: 'ì', 4: 'i', 5: 'î', 6: 'ǐ', 7: 'ī', 8: 'i̍', 9: 'i̋', 0: 'i' },
    o: { 1: 'o', 2: 'ó', 3: 'ò', 4: 'o', 5: 'ô', 6: 'ǒ', 7: 'ō', 8: 'o̍', 9: 'ő', 0: 'o' },
    u: { 1: 'u', 2: 'ú', 3: 'ù', 4: 'u', 5: 'û', 6: 'ǔ', 7: 'ū', 8: 'u̍', 9: 'ű', 0: 'u' },
    m: { 1: 'm', 2: 'ḿ', 3: 'm̀', 4: 'm', 5: 'm̂', 6: 'm̌', 7: 'm̄', 8: 'm̍', 9: 'm̋', 0: 'm' },
    n: { 1: 'n', 2: 'ń', 3: 'ǹ', 4: 'n', 5: 'n̂', 6: 'ň', 7: 'n̄', 8: 'n̍', 9: 'n̋', 0: 'n' },
  };

  // Reverse map: any vowel-with-diacritic -> { base, tone }
  const REVERSE = {};
  Object.entries(TONE_MARKS).forEach(([base, byTone]) => {
    Object.entries(byTone).forEach(([tone, ch]) => {
      if (!REVERSE[ch]) REVERSE[ch] = { base, tone: parseInt(tone, 10) };
    });
  });

  // Place tone mark in a syllable (returns diacritic form).
  function applyTone(syllable, tone) {
    if (!tone || tone === '0') tone = 1;
    tone = parseInt(tone, 10);
    if (isNaN(tone)) tone = 1;

    let lower = syllable.toLowerCase();
    let target = -1;

    // "oo" rule -> first o
    const ooIdx = lower.indexOf('oo');
    if (ooIdx >= 0) {
      target = ooIdx;
    } else {
      // priority a/e/o/u/i; for diphthongs find the first matching priority vowel
      for (const v of VOWEL_PRIORITY) {
        const idx = lower.indexOf(v);
        if (idx >= 0) { target = idx; break; }
      }
      // syllabic m / ng / n
      if (target < 0) {
        if (lower.startsWith('ng')) target = -2; // mark on 'n' of ng
        else if (lower === 'm' || lower === 'mh') target = 0;
        else if (lower === 'n' || lower === 'nh') target = 0;
      }
    }

    if (target < 0) return syllable; // give up — return as-is

    let idx = target === -2 ? 0 : target;
    const ch = syllable[idx];
    const base = ch.toLowerCase();
    const map = TONE_MARKS[base];
    if (!map) return syllable;
    let marked = map[tone] || ch;
    // preserve case
    if (ch === ch.toUpperCase() && ch !== ch.toLowerCase()) {
      marked = marked.charAt(0).toUpperCase() + marked.slice(1);
    }
    return syllable.slice(0, idx) + marked + syllable.slice(idx + 1);
  }

  // Convert a numeric-tailo syllable like "thau5" → "thâu"
  function numericSyllableToDiacritic(syl) {
    const m = syl.match(/^([A-Za-z'-]+?)([0-9])$/);
    if (!m) return syl;
    return applyTone(m[1], m[2]);
  }

  // Convert a numeric-tailo word with hyphens, e.g. "lo2-pe7" → "ló-pē"
  function numericWordToDiacritic(word) {
    return word
      .split(/(-|·|‧)/)
      .map(part => /^[A-Za-z'-]+\d$/.test(part) ? numericSyllableToDiacritic(part) : part)
      .join('');
  }

  // Strip diacritic from a syllable, return { base, tone }
  function diacriticSyllableToNumeric(syl) {
    let base = '';
    let tone = 1;
    for (const ch of syl.normalize('NFC')) {
      if (REVERSE[ch]) {
        base += REVERSE[ch].base;
        tone = REVERSE[ch].tone;
      } else {
        // decompose and check
        const dec = ch.normalize('NFD');
        const stripped = dec.replace(/[\u0300-\u036f]/g, '');
        const combos = dec.match(/[\u0300-\u036f]/g) || [];
        base += stripped;
        // Try combinations
        const test = stripped + combos.join('');
        if (REVERSE[test.normalize('NFC')]) tone = REVERSE[test.normalize('NFC')].tone;
        else if (combos.length) {
          // common combining chars
          if (combos.includes('\u0301')) tone = 2;       // ́
          else if (combos.includes('\u0300')) tone = 3;  // ̀
          else if (combos.includes('\u0302')) tone = 5;  // ̂
          else if (combos.includes('\u0304')) tone = 7;  // ̄
          else if (combos.includes('\u030d')) tone = 8;  // ̍
          else if (combos.includes('\u030b')) tone = 9;  // ̋
        }
      }
    }
    // Tone 4/8 detection: ends in p/t/k/h → it's an entering tone.
    // Tone 1 with stop coda → 4. Tone 8 stays.
    const endsInStop = /[ptkh]$/i.test(base);
    if (endsInStop && tone === 1) tone = 4;
    return { base, tone };
  }

  // Convert a diacritic word to numeric: "thâu-mn̂g" → "thau5-mng5"
  function diacriticWordToNumeric(word) {
    return word
      .split(/(-|·|‧)/)
      .map(part => {
        if (/[A-Za-zàáâāǎèéêēěìíîīǐòóôōǒùúûūǔńňǹḿ\u0300-\u036f]/i.test(part) && part.length >= 1 && !/^[-·‧]$/.test(part)) {
          const { base, tone } = diacriticSyllableToNumeric(part);
          return base + tone;
        }
        return part;
      })
      .join('');
  }

  // Apply tone mode to a tâi-lô string (whole sentence or word).
  // mode: 'diacritic' | 'numeric'
  function toToneMode(tailo, mode) {
    if (!tailo) return tailo;
    if (mode === 'numeric') {
      // convert any diacritic syllable to numeric
      return tailo.replace(/[A-Za-zàáâāǎèéêēěìíîīǐòóôōǒùúûūǔńňǹḿ\u0300-\u036f'-]+/g, w => {
        // if already numeric (ends in digit on every syllable) leave it
        if (/^[A-Za-z'-]+\d(?:-[A-Za-z'-]+\d)*$/.test(w)) return w;
        return diacriticWordToNumeric(w);
      });
    } else {
      // diacritic — convert any numeric syllable to diacritic
      return tailo.replace(/[A-Za-z'-]+\d(?:-[A-Za-z'-]+\d)*/g, w => numericWordToDiacritic(w));
    }
  }

  global.Tailo = { toToneMode, numericWordToDiacritic, diacriticWordToNumeric, applyTone };
})(window);
