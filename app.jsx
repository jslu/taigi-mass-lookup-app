// ============================================================================
// App — Taigi Mass Lookup root component
// ============================================================================

const { useState, useMemo, useEffect } = React;

const SAMPLE = `街仔底總仔共仔兩間福州人開ê剃頭店，頭到hit間號做「明星」，是我一个查某同學ê老爸開--ê，另外一間khah遠--ê叫做「萬國」。Kám是囡仔人lóng小面神mā有淡薄仔pì-sù ê款，頭改阿母hiàm我出去外口剪頭鬃，明其知khah遠mā是行去「萬國」hia交關。差不多beh收尾ê時，剃頭師傅問我頂頭beh拍khah薄--無？Tùn-tenn兩、三秒我tsiah應好；論真我家己mā m̄知影啥mi̍h號做拍薄。`;

const TWEAK_DEFAULTS = { layout: 'ruby', toneMode: 'diacritic' };
const TWEAK_KEY = 'taigi-mass-lookup:tweaks';

function loadTweaks() {
  try {
    const raw = localStorage.getItem(TWEAK_KEY);
    if (raw) return { ...TWEAK_DEFAULTS, ...JSON.parse(raw) };
  } catch (_) { /* ignore */ }
  return TWEAK_DEFAULTS;
}

function SegToggle({ label, value, options, onChange }) {
  return (
    <div className="results-control">
      <span className="results-control-label">{label}</span>
      <div className="seg-toggle" role="radiogroup" aria-label={label}>
        {options.map(o => (
          <button
            key={o.value}
            role="radio"
            aria-checked={value === o.value}
            className={value === o.value ? 'is-active' : ''}
            onClick={() => onChange(o.value)}
          >
            {o.label}
          </button>
        ))}
      </div>
    </div>
  );
}

function App() {
  const [text, setText] = useState('');
  const [submitted, setSubmitted] = useState('');
  const [activeIdx, setActiveIdx] = useState(-1);
  const [tweaks, setTweaks] = useState(loadTweaks);
  const [copiedAll, setCopiedAll] = useState(false);

  useEffect(() => {
    localStorage.setItem(TWEAK_KEY, JSON.stringify(tweaks));
  }, [tweaks]);

  const setTweak = (key, value) => setTweaks(t => ({ ...t, [key]: value }));

  const sentences = useMemo(
    () => window.TaigiConvert.splitSentences(submitted),
    [submitted]
  );

  const submit = () => {
    setSubmitted(text);
    setActiveIdx(-1);
  };
  const loadSample = () => setText(SAMPLE);
  const clear = () => { setText(''); setSubmitted(''); setActiveIdx(-1); };

  const charCount = text.length;
  const sentenceCount = sentences.length;

  const copyAll = async () => {
    const lines = [];
    let prevPara = sentences[0]?.paragraph ?? 0;
    for (const s of sentences) {
      if (s.paragraph !== prevPara) {
        lines.push('');
        prevPara = s.paragraph;
      }
      const toks = await window.TaigiConvert.convertSentence(s.text).catch(() => null);
      if (!toks) { lines.push(s.text); continue; }
      const han = toks.map(t => t.han).join('');
      const rom = toks
        .map(t => window.SentenceLayouts.isPunct(t)
          ? t.han
          : (window.SentenceLayouts.applyToneMode(t.tailo, tweaks.toneMode) || ''))
        .join(' ').replace(/\s+([，。！？；：])/g, '$1').trim();
      lines.push(han + '\n' + rom);
    }
    navigator.clipboard.writeText(lines.join('\n\n'));
    setCopiedAll(true);
    setTimeout(() => setCopiedAll(false), 1600);
  };

  return (
    <div className="app-shell">
      {/* Header */}
      <header className="app-header">
        <div>
          <h1 className="app-title">
            <span>Taigi</span> <span className="accent">Mass Lookup</span>
          </h1>
          <div className="app-subtitle">
            Paste any 台語文 passage — get sentence-by-sentence 漢字 ↔ Tâi-lô.
          </div>
        </div>
        <div className="brand-mark">台羅 · Hàn-lô</div>
      </header>

      {/* Input */}
      <div className="input-card">
        <div className="input-toolbar">
          <div className="input-toolbar-left">
            <span className="dot" />
            <span>Source text</span>
          </div>
          <div className="input-toolbar-right">
            <button className="btn btn-ghost" onClick={loadSample} disabled={!!text}>
              Load sample
            </button>
            <button className="btn btn-ghost" onClick={clear} disabled={!text && !submitted}>
              Clear
            </button>
          </div>
        </div>
        <textarea
          className="taigi-input taigi-text"
          placeholder="貼一篇台語文（漢字、Tâi-lô，抑是 Hàn-lô 攏會使）⋯"
          value={text}
          onChange={(e) => setText(e.target.value)}
          onKeyDown={(e) => {
            if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') submit();
          }}
        />
        <div className="input-footer">
          <div>
            {charCount > 0
              ? <>{charCount.toLocaleString()} characters</>
              : <>Tip: ⌘/Ctrl + Enter to convert</>}
          </div>
          <div style={{ display: 'flex', gap: 8 }}>
            <button
              className="btn btn-primary btn-large"
              onClick={submit}
              disabled={!text.trim() || text === submitted}
            >
              Convert
              <svg width="14" height="14" viewBox="0 0 16 16" fill="none" style={{ marginLeft: 4 }}>
                <path d="M3 8H13M13 8L9 4M13 8L9 12" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
            </button>
          </div>
        </div>
      </div>

      {/* Results */}
      {sentenceCount > 0 && (
        <>
          <div className="results-meta">
            <span><span className="count">{sentenceCount}</span> sentence{sentenceCount > 1 ? 's' : ''}</span>
            <span className="divider" />
            <button className="btn btn-secondary" onClick={copyAll}>
              {copiedAll ? 'Copied!' : 'Copy all'}
            </button>
          </div>

          <div className="results-controls">
            <SegToggle
              label="Layout"
              value={tweaks.layout}
              options={[
                { value: 'ruby', label: 'Ruby' },
                { value: 'stacked', label: 'Stacked' },
                { value: 'side', label: 'Side' },
                { value: 'table', label: 'Table' },
              ]}
              onChange={(v) => setTweak('layout', v)}
            />
            <SegToggle
              label="Tone"
              value={tweaks.toneMode}
              options={[
                { value: 'diacritic', label: 'â ē í' },
                { value: 'numeric', label: 'a5 e7 i2' },
              ]}
              onChange={(v) => setTweak('toneMode', v)}
            />
          </div>

          <div className="results-list" onMouseLeave={() => setActiveIdx(-1)}>
            {sentences.map((s, i) => {
              const prev = sentences[i - 1];
              const isParaBreak = prev && prev.paragraph !== s.paragraph;
              return (
                <React.Fragment key={i + ':' + (s.text || '').slice(0, 12)}>
                  {isParaBreak && (
                    <div className="paragraph-break" aria-hidden="true">
                      <span className="pb-line" />
                      <span className="pb-mark">
                        <span className="pb-pilcrow">¶</span>
                        <span>New paragraph</span>
                      </span>
                      <span className="pb-line" />
                    </div>
                  )}
                  <window.SentenceRow
                    sentence={s.text}
                    idx={i}
                    layout={tweaks.layout}
                    toneMode={tweaks.toneMode}
                    isActive={activeIdx === i}
                    onActivate={setActiveIdx}
                  />
                </React.Fragment>
              );
            })}
          </div>
        </>
      )}

      {sentenceCount === 0 && submitted === '' && (
        <div className="empty-state">
          <div className="es-icon">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none">
              <path d="M4 6h16M4 12h10M4 18h16" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/>
            </svg>
          </div>
          <h3>No text yet</h3>
          <p>Paste a Taigi passage above and press Convert. Each sentence will appear below with aligned 漢字 and Tâi-lô. Click any word to see its 漢字 and Tâi-lô.</p>
        </div>
      )}

      <div className="foot-note">
        Tâi-lô (台羅) is the Ministry of Education's romanization system for Taiwanese Hokkien.
        Conversions are provided by the <a href="https://suisiann.ithuan.tw/" target="_blank" rel="noreferrer">意傳科技 ithuan</a> 「台文音讀網」 service — verify with a dictionary for important uses.
      </div>
    </div>
  );
}

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(<App />);
