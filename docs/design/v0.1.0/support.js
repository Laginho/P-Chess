// Minimal stand-in for the design canvas runtime, so each .dc.html renders on its own
// (served over http, e.g. `python -m http.server` from the repo root). Supports what the
// boards use: {{path}} bindings, <sc-for list as>, <sc-if value>, <dc-import name>, <helmet>.
(() => {
  // /_blob/ piece hashes from Board.dc.html -> the repo's own cburnett pieces.
  const PIECES = '../../../themes/pieces/cburnett/';
  const BLOBS = {
    '1a9bf889a878a310f7cc02e9fdd7433e': 'wK', 'd7684de562a136a5fb0a38e52f793157': 'wQ',
    '72ae5864d2289f171448dc8fec0802ba': 'wR', '661fe688dd91b2efa2731a3694191fe6': 'wB',
    '72f77df61a8746abccb0aaf0235ef853': 'wN', 'd7f1569a29b0aa1c670736667b664fd3': 'wP',
    '0fd7783fd87430dbb114f9801cec7c67': 'bK', 'd89cc683ccd6fbd1fbcf540ae2ef1245': 'bQ',
    '7062c368d4328e0e3a8ef04d28dc3cd7': 'bR', '3badc3ee9a10f59b9cda404696154f2c': 'bB',
    '096c3a05bb57e7619d98747bd00daa42': 'bN', '11782091e7cb35762a1f756c5a8b9ebd': 'bP',
  };
  class DCLogic { constructor(props) { this.props = props; } renderVals() { return {}; } }
  const comps = {};
  const helmets = new Set();

  function parse(src) {
    const doc = new DOMParser().parseFromString(src, 'text/html');
    const tpl = document.createElement('template');
    tpl.innerHTML = /<x-dc>([\s\S]*)<\/x-dc>/.exec(src)[1];
    const script = doc.querySelector('script[data-dc-script]');
    const decl = JSON.parse(script.dataset.props || '{}');
    const Cls = new Function('DCLogic', script.textContent + '\nreturn Component;')(DCLogic);
    const helmet = tpl.content.querySelector('helmet');
    if (helmet) helmet.remove();
    return { tpl, decl, Cls, helmet };
  }

  async function load(name) {
    if (comps[name]) return;
    comps[name] = parse(await (await fetch(name + '.dc.html')).text());
    for (const el of comps[name].tpl.content.querySelectorAll('dc-import')) await load(el.getAttribute('name'));
  }

  function lookup(expr, scope) {
    expr = expr.trim();
    if (/^(true|false|null|-?\d+(\.\d+)?)$/.test(expr)) return JSON.parse(expr);
    return expr.split('.').reduce((o, k) => (o == null ? undefined : o[k]), scope);
  }
  // A value that is exactly one {{x}} keeps its type (lists, booleans); anything else is text.
  function interp(text, scope) {
    const whole = /^\s*\{\{([^}]*)\}\}\s*$/.exec(text);
    if (whole) return lookup(whole[1], scope);
    return text.replace(/\{\{([^}]*)\}\}/g, (_, e) => { const v = lookup(e, scope); return v == null ? '' : v; });
  }
  const str = (v) => (v == null ? '' : String(v));

  function instantiate(name, props, out) {
    const c = comps[name];
    if (c.helmet && !helmets.has(name)) {
      helmets.add(name);
      for (const n of c.helmet.childNodes) document.head.appendChild(document.importNode(n, true));
    }
    const scope = new c.Cls(props).renderVals();
    for (const n of c.tpl.content.childNodes) render(n, scope, out);
  }

  function render(node, scope, out) {
    if (node.nodeType === Node.TEXT_NODE) { out.appendChild(document.createTextNode(str(interp(node.data, scope)))); return; }
    if (node.nodeType !== Node.ELEMENT_NODE) return;
    const tag = node.localName;
    if (tag === 'sc-for') {
      const as = node.getAttribute('as');
      for (const item of interp(node.getAttribute('list'), scope) || [])
        for (const n of node.childNodes) render(n, { ...scope, [as]: item }, out);
      return;
    }
    if (tag === 'sc-if') {
      if (interp(node.getAttribute('value'), scope)) for (const n of node.childNodes) render(n, scope, out);
      return;
    }
    if (tag === 'dc-import') {
      const name = node.getAttribute('name');
      const keys = Object.keys(comps[name].decl);
      const props = {};
      for (const a of node.attributes) {
        if (a.name === 'name' || a.name.startsWith('hint-')) continue;
        props[keys.find((k) => k.toLowerCase() === a.name) || a.name] = interp(a.value, scope);
      }
      instantiate(name, props, out);
      return;
    }
    const el = document.createElementNS(node.namespaceURI, tag);
    for (const a of node.attributes) {
      let v = str(interp(a.value, scope));
      if (a.name === 'src' && v.startsWith('/_blob/')) v = PIECES + BLOBS[v.slice(7)] + '.svg';
      el.setAttribute(a.name, v);
    }
    for (const n of node.childNodes) render(n, scope, el);
    out.appendChild(el);
  }

  window.addEventListener('DOMContentLoaded', async () => {
    const name = decodeURIComponent(location.pathname.split('/').pop()).replace(/\.dc\.html$/, '');
    document.querySelector('x-dc').remove();
    await load(name);
    instantiate(name, {}, document.body);
    await document.fonts.ready;
    document.body.dataset.rendered = '1';
  });
})();
