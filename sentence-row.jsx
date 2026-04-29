// ============================================================================
// SentenceRow — one converted sentence with actions and word popover
// ============================================================================

const { useState, useEffect, useRef, useCallback } = React;

function SentenceRow({ sentence, idx, layout, toneMode, isActive, onActivate }) {
  const [tokens, setTokens] = useState(null);
  const [error, setError] = useState(null);
  const [copied, setCopied] = useState(false);
  const [selected, setSelected] = useState(null);
  const [retryCount, setRetryCount] = useState(0);
  const rowRef = useRef(null);

  useEffect(() => {
    let cancelled = false;
    setTokens(null);
    setError(null);
    window.TaigiConvert.convertSentence(sentence)
      .then((toks) => { if (!cancelled) setTokens(toks); })
      .catch((e) => { if (!cancelled) setError(e.message || 'Conversion failed'); });
    return () => { cancelled = true; };
  }, [sentence, retryCount]);

  const handleWordClick = useCallback((token, key, el) => {
    const rect = el.getBoundingClientRect();
    const rowRect = rowRef.current.getBoundingClientRect();
    setSelected({
      key,
      token,
      x: rect.left - rowRect.left + rect.width / 2,
      y: rect.bottom - rowRect.top + 8,
    });
  }, []);

  const closePopover = useCallback(() => setSelected(null), []);

  useEffect(() => {
    if (!selected) return;
    const onDoc = (e) => {
      if (!rowRef.current) return;
      if (!rowRef.current.contains(e.target)) closePopover();
    };
    document.addEventListener('mousedown', onDoc);
    return () => document.removeEventListener('mousedown', onDoc);
  }, [selected, closePopover]);

  const copyLine = () => {
    if (!tokens) return;
    const han = tokens.map(t => t.han).join('');
    const romaji = tokens.map(t => {
      if (window.SentenceLayouts.isPunct(t)) return t.han;
      return window.SentenceLayouts.applyToneMode(t.tailo, toneMode) || '';
    }).join(' ').replace(/\s+([，。！？；：])/g, '$1').trim();
    const text = `${han}\n${romaji}`;
    navigator.clipboard.writeText(text).then(() => {
      setCopied(true);
      setTimeout(() => setCopied(false), 1400);
    });
  };

  const Layout = {
    ruby: window.SentenceLayouts.RubyLine,
    stacked: window.SentenceLayouts.StackedLine,
    side: window.SentenceLayouts.SideBySideLine,
    table: window.SentenceLayouts.TableLine,
  }[layout] || window.SentenceLayouts.RubyLine;

  return (
    <div
      ref={rowRef}
      className={`sentence-row ${isActive ? 'is-active' : ''}`}
      onMouseEnter={() => onActivate(idx)}
    >
      <div className="row-index">{String(idx + 1).padStart(2, '0')}</div>

      {tokens === null && !error && (
        <div>
          <div className="row-status">
            <span className="pulse" />
            <span>Converting…</span>
          </div>
          <div className="taigi-text" style={{ fontSize: 19, lineHeight: '32px', color: 'var(--text-02)' }}>
            {sentence}
          </div>
        </div>
      )}

      {error && (
        <div>
          <div className="row-status error">
            <span className="pulse" />
            <span>Couldn't convert this sentence.</span>
            <button
              className="btn btn-ghost"
              style={{ height: 22, padding: '0 8px', fontSize: 11, marginLeft: 8 }}
              onClick={(e) => { e.stopPropagation(); setRetryCount(c => c + 1); }}
            >
              Retry
            </button>
          </div>
          <div className="taigi-text" style={{ fontSize: 19, lineHeight: '32px' }}>
            {sentence}
          </div>
        </div>
      )}

      {tokens && (
        <Layout
          tokens={tokens}
          toneMode={toneMode}
          selectedKey={selected?.key}
          onWordClick={handleWordClick}
          lineIdx={idx}
        />
      )}

      <div className="row-actions">
        <button className={`icon-btn ${copied ? 'copied' : ''}`} onClick={copyLine} title="Copy this line" aria-label="Copy">
          {copied ? (
            <svg width="14" height="14" viewBox="0 0 16 16" fill="none">
              <path d="M3 8.5L6.5 12L13 4" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
            </svg>
          ) : (
            <svg width="14" height="14" viewBox="0 0 16 16" fill="none">
              <rect x="4" y="4" width="9" height="9" rx="1.5" stroke="currentColor" strokeWidth="1.2"/>
              <path d="M3 11V3.5C3 2.67 3.67 2 4.5 2H11" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round"/>
            </svg>
          )}
        </button>
      </div>

      {selected && (
        <div
          className="word-popover"
          style={{ left: Math.max(8, selected.x - 110), top: selected.y }}
          onClick={(e) => e.stopPropagation()}
        >
          <div className="pop-han taigi-text">{selected.token.han}</div>
          <div className="pop-romaji">
            {selected.token.tailo
              ? window.SentenceLayouts.applyToneMode(selected.token.tailo, toneMode)
              : '—'}
          </div>
          <div className="pop-divider" />
          <div className="pop-gloss-label">Meaning</div>
          <div className="pop-gloss pop-stub">No detailed lookup yet.</div>
        </div>
      )}
    </div>
  );
}

window.SentenceRow = SentenceRow;
