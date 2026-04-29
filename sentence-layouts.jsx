// ============================================================================
// Sentence components — different visual layouts (ruby / stacked / side / table)
// Each takes { tokens, layout, toneMode, onWordClick, selectedKey }
// ============================================================================

const PUNCT_RE = /^[\s。！？，；：、,.!?;:‧·…—\-—()（）「」『』""''《》]+$/;

function isPunct(t) {
  return PUNCT_RE.test(t.han || '');
}

function applyToneMode(tailo, mode) {
  if (!tailo) return tailo;
  return window.Tailo.toToneMode(tailo, mode);
}

// Token wrapper with selection / click handling
function Token({ token, layout, toneMode, isSelected, onClick, tokenKey }) {
  const punct = isPunct(token);
  const tailo = applyToneMode(token.tailo, toneMode);
  const handleClick = (e) => {
    if (punct) return;
    e.stopPropagation();
    onClick && onClick(token, tokenKey, e.currentTarget);
  };

  if (layout === 'ruby') {
    return (
      <span
        className={`ruby-token ${punct ? 'punct' : ''} ${isSelected ? 'is-selected' : ''}`}
        onClick={handleClick}
      >
        <span className="ruby-romaji">{tailo || (punct ? '' : '\u00A0')}</span>
        <span className="ruby-han taigi-text">{token.han}</span>
      </span>
    );
  }
  if (layout === 'stacked') {
    return null; // stacked rendered at line level, see below
  }
  return null;
}

function RubyLine({ tokens, toneMode, selectedKey, onWordClick, lineIdx }) {
  return (
    <div className="ruby-line taigi-text">
      {tokens.map((t, i) => {
        const key = `${lineIdx}-${i}`;
        return (
          <Token
            key={key}
            tokenKey={key}
            token={t}
            layout="ruby"
            toneMode={toneMode}
            isSelected={selectedKey === key}
            onClick={onWordClick}
          />
        );
      })}
    </div>
  );
}

function StackedLine({ tokens, toneMode, selectedKey, onWordClick, lineIdx }) {
  return (
    <div className="stacked-line">
      <div className="stacked-han taigi-text">
        {tokens.map((t, i) => {
          const key = `${lineIdx}-${i}`;
          const punct = isPunct(t);
          return (
            <span
              key={key}
              className={`stacked-token ${punct ? 'punct' : ''} ${selectedKey === key ? 'is-selected' : ''}`}
              onClick={(e) => {
                if (punct) return;
                e.stopPropagation();
                onWordClick(t, key, e.currentTarget);
              }}
            >
              {t.han}
            </span>
          );
        })}
      </div>
      <div className="stacked-romaji">
        {tokens.map((t, i) => {
          const key = `${lineIdx}-${i}`;
          const punct = isPunct(t);
          const tailo = applyToneMode(t.tailo, toneMode);
          if (punct) return <span key={key} className="stacked-token punct">{t.han}</span>;
          return (
            <span
              key={key}
              className={`stacked-token ${selectedKey === key ? 'is-selected' : ''}`}
              onClick={(e) => {
                e.stopPropagation();
                onWordClick(t, key, e.currentTarget);
              }}
            >
              {tailo || '·'}
              {i < tokens.length - 1 ? ' ' : ''}
            </span>
          );
        })}
      </div>
    </div>
  );
}

function SideBySideLine({ tokens, toneMode, selectedKey, onWordClick, lineIdx }) {
  return (
    <div className="side-line">
      <div className="side-col-han taigi-text">
        {tokens.map((t, i) => {
          const key = `${lineIdx}-${i}`;
          const punct = isPunct(t);
          return (
            <span
              key={key}
              className={`side-token ${punct ? 'punct' : ''} ${selectedKey === key ? 'is-selected' : ''}`}
              onClick={(e) => {
                if (punct) return;
                e.stopPropagation();
                onWordClick(t, key, e.currentTarget);
              }}
            >
              {t.han}
            </span>
          );
        })}
      </div>
      <div className="side-col-romaji">
        {tokens.map((t, i) => {
          const key = `${lineIdx}-${i}`;
          const punct = isPunct(t);
          const tailo = applyToneMode(t.tailo, toneMode);
          if (punct) return <span key={key} className="side-token punct">{t.han}</span>;
          return (
            <span
              key={key}
              className={`side-token ${selectedKey === key ? 'is-selected' : ''}`}
              onClick={(e) => {
                e.stopPropagation();
                onWordClick(t, key, e.currentTarget);
              }}
            >
              {tailo || '·'}
              {i < tokens.length - 1 ? ' ' : ''}
            </span>
          );
        })}
      </div>
    </div>
  );
}

function TableLine({ tokens, toneMode, selectedKey, onWordClick, lineIdx }) {
  const han = tokens.map(t => t.han).join('');
  const romaji = tokens.map(t => {
    if (isPunct(t)) return t.han;
    return applyToneMode(t.tailo, toneMode) || '·';
  }).join(' ').replace(/\s+([，。！？；：])/g, '$1');
  return (
    <div className="table-line">
      <div className="table-row">
        <div className="table-label">漢字</div>
        <div className="table-cell taigi-text">{han}</div>
      </div>
      <div className="table-row">
        <div className="table-label">Tâi-lô</div>
        <div className="table-cell romaji">{romaji}</div>
      </div>
    </div>
  );
}

window.SentenceLayouts = { RubyLine, StackedLine, SideBySideLine, TableLine, isPunct, applyToneMode };
