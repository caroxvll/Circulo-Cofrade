/** Markdown compatible con el editor de la app Flutter (Quill → MD). */

export function makePlainExcerpt(raw: string, max = 180): string {
  let text = stripMarkdownForExcerpt(raw).replace(/\s+/g, ' ').trim();
  if (text.length <= max) return text;
  return `${text.slice(0, max - 1).trimEnd()}…`;
}

export function stripMarkdownForExcerpt(raw: string): string {
  let text = raw.replace(/\r\n/g, '\n');
  text = text.replace(/```[\s\S]*?```/g, ' ');
  text = text.replace(/`[^`\n]+`/g, ' ');
  text = text.replace(/\[([^\]]+)\]\([^)]+\)/g, '$1');
  text = text.replace(/\*\*(.+?)\*\*/g, '$1');
  text = text.replace(/_(.+?)_/g, '$1');
  text = text.replace(/^>\s?/gm, '');
  text = text.replace(/^#+\s*/gm, '');
  text = text.replace(/^[-*+]\s+/gm, '');
  text = text.replace(/^\d+\.\s+/gm, '');
  return text;
}

export type MdWrapKind = 'bold' | 'italic' | 'bullet' | 'quote' | 'link';

export function wrapMarkdownSelection(
  value: string,
  start: number,
  end: number,
  kind: MdWrapKind,
): { text: string; selectionStart: number; selectionEnd: number } {
  const selected = value.slice(start, end);
  const before = value.slice(0, start);
  const after = value.slice(end);

  if (kind === 'bold') {
    const inner = selected || 'texto';
    const wrapped = `**${inner}**`;
    return {
      text: before + wrapped + after,
      selectionStart: before.length + 2,
      selectionEnd: before.length + 2 + inner.length,
    };
  }

  if (kind === 'italic') {
    const inner = selected || 'texto';
    const wrapped = `_${inner}_`;
    return {
      text: before + wrapped + after,
      selectionStart: before.length + 1,
      selectionEnd: before.length + 1 + inner.length,
    };
  }

  if (kind === 'link') {
    const label = selected || 'enlace';
    const wrapped = `[${label}](https://)`;
    return {
      text: before + wrapped + after,
      selectionStart: before.length + label.length + 3,
      selectionEnd: before.length + wrapped.length - 1,
    };
  }

  const block = selected || (kind === 'quote' ? 'Cita' : 'Elemento');
  const lines = block.split('\n');
  const prefixed =
    kind === 'quote'
      ? lines.map((l) => (l.trim() ? `> ${l}` : '>')).join('\n')
      : lines.map((l) => (l.trim() ? `- ${l.replace(/^[-*+]\s+/, '')}` : '- ')).join('\n');

  const needsNlBefore = before.length > 0 && !before.endsWith('\n');
  const needsNlAfter = after.length > 0 && !after.startsWith('\n');
  const insert =
    (needsNlBefore ? '\n' : '') + prefixed + (needsNlAfter ? '\n' : '');
  const selStart = before.length + (needsNlBefore ? 1 : 0);
  return {
    text: before + insert + after,
    selectionStart: selStart,
    selectionEnd: selStart + prefixed.length,
  };
}

/** Convierte markdown del foro a HTML seguro (escapa primero). */
export function forumMarkdownToSafeHtml(raw: string): string {
  const text = raw.replace(/\r\n/g, '\n').trim();
  if (!text) {
    return '<p class="md-empty">Empieza a escribir para ver la vista previa…</p>';
  }

  const lines = text.split('\n');
  const parts: string[] = [];
  let i = 0;

  while (i < lines.length) {
    const line = lines[i];
    if (!line.trim()) {
      i++;
      continue;
    }

    if (/^\s*[-*+]\s+/.test(line)) {
      const items: string[] = [];
      while (i < lines.length && /^\s*[-*+]\s+/.test(lines[i])) {
        items.push(inlineMd(lines[i].replace(/^\s*[-*+]\s+/, '')));
        i++;
      }
      parts.push(`<ul>${items.map((it) => `<li>${it}</li>`).join('')}</ul>`);
      continue;
    }

    if (/^\s*\d+\.\s+/.test(line)) {
      const items: string[] = [];
      while (i < lines.length && /^\s*\d+\.\s+/.test(lines[i])) {
        items.push(inlineMd(lines[i].replace(/^\s*\d+\.\s+/, '')));
        i++;
      }
      parts.push(`<ol>${items.map((it) => `<li>${it}</li>`).join('')}</ol>`);
      continue;
    }

    if (/^>\s?/.test(line)) {
      const quoteLines: string[] = [];
      while (i < lines.length && /^>\s?/.test(lines[i])) {
        quoteLines.push(inlineMd(lines[i].replace(/^>\s?/, '')));
        i++;
      }
      parts.push(`<blockquote>${quoteLines.join('<br>')}</blockquote>`);
      continue;
    }

    const para: string[] = [];
    while (
      i < lines.length &&
      lines[i].trim() &&
      !/^\s*[-*+]\s+/.test(lines[i]) &&
      !/^\s*\d+\.\s+/.test(lines[i]) &&
      !/^>\s?/.test(lines[i])
    ) {
      para.push(inlineMd(lines[i]));
      i++;
    }
    parts.push(`<p>${para.join('<br>')}</p>`);
  }

  return parts.join('');
}

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function inlineMd(raw: string): string {
  let s = escapeHtml(raw);
  s = s.replace(
    /\[([^\]]+)\]\((https?:\/\/[^)\s]+)\)/g,
    '<a href="$2" target="_blank" rel="noopener noreferrer">$1</a>',
  );
  s = s.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
  s = s.replace(/_(.+?)_/g, '<em>$1</em>');
  s = s.replace(
    /(https?:\/\/[^\s<]+)/g,
    '<a href="$1" target="_blank" rel="noopener noreferrer">$1</a>',
  );
  return s;
}
