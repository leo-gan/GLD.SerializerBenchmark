/**
 * Dashboard section hashes.
 *
 * Compliance:
 *   #compliance
 *   #compliance/{lang}
 *   #compliance/{lang}/{serializer}            → that row, All standards
 *   #compliance/{lang}/{serializer}/{format}   → JSON / YAML / no-spec / …
 *
 * Experiments already had #experiments/{id}. Language is optional:
 *   #experiments/{id}/{lang}
 *
 * Overview / Details / Compare keep query params (?lang=&data=&mode=&ser=).
 */

export function parseComplianceHash(raw) {
  const hash = String(raw || '').replace(/^#/, '');
  if (hash !== 'compliance' && !hash.startsWith('compliance/')) {
    return { active: false, lang: '', serializer: '', format: undefined };
  }
  const rest = hash === 'compliance' ? '' : hash.slice('compliance/'.length);
  const parts = rest.split('/').filter((p) => p !== '');
  const lang = parts[0] ? safeDecode(parts[0]) : '';
  const serializer = parts[1] ? safeDecode(parts[1]) : '';
  let format;
  if (parts.length >= 3) {
    const rawFmt = safeDecode(parts.slice(2).join('/'));
    format = rawFmt === 'all' ? '' : rawFmt;
  }
  return { active: true, lang, serializer, format };
}

export function formatComplianceHash({ lang = '', serializer = '', format } = {}) {
  const segs = ['compliance'];
  if (lang) segs.push(encodeURIComponent(lang));
  if (lang && serializer) segs.push(encodeURIComponent(serializer));
  if (lang && serializer && format !== undefined && format !== '') {
    segs.push(encodeURIComponent(format));
  }
  return `#${segs.join('/')}`;
}

export function parseExperimentsHash(raw) {
  const hash = String(raw || '').replace(/^#/, '');
  if (hash === 'experiments') return { view: 'list', id: null, lang: '' };
  if (hash.startsWith('experiments/')) {
    const rest = hash.slice('experiments/'.length).replace(/\/+$/, '');
    const parts = rest.split('/').filter((p) => p !== '');
    const id = parts[0] ? safeDecode(parts[0]) : '';
    const lang = parts[1] ? safeDecode(parts[1]) : '';
    return { view: id ? 'detail' : 'list', id: id || null, lang };
  }
  return { view: 'suite', id: null, lang: '' };
}

export function formatExperimentsHash({ id = '', lang = '' } = {}) {
  if (!id) return '#experiments';
  if (lang) return `#experiments/${encodeURIComponent(id)}/${encodeURIComponent(lang)}`;
  return `#experiments/${encodeURIComponent(id)}`;
}

function safeDecode(value) {
  try {
    return decodeURIComponent(value);
  } catch {
    return value;
  }
}
