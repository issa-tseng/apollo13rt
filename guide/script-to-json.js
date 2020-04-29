const { basename } = require('path');
const { readFileSync, writeFileSync } = require('fs');

const atoi = (x => parseInt(x, 10));

const filename = process.argv[2];
const base = basename(filename, '.txt');

const text = readFileSync(`./${filename}`, 'utf8');

const out = { LAYOUT: [], NARRATION: [], STATUS: [], DIAGRAM: [], METERS: [] };
let epoch, state, target;
for (const line of text.split('\n')) {
  const header = /^\[(\d\d) (\d\d) (\d\d)\] ([a-z]+)$/i.exec(line);
  if (header) {
    [ , hh, mm, ss, type ] = header;
    epoch = atoi(hh) * 3600 + atoi(mm) * 60 + atoi(ss);
    state = type;
    out[state].push(target = { epoch });
  } else if (line.startsWith('# ')) {
    state = line.slice(2);
    out[state].push(target = { epoch });
  } else if (line === '') {
    // skip
  } else if (state === 'LAYOUT') {
    target.panels = [];
    const tokens = line.split(' ');
    let panel;
    for (const token of tokens) {
      if (/\d/.test(token)) panel.weight = atoi(token);
      else target.panels.push(panel = { name: token.toLowerCase() });
    }
  } else if (state === 'NARRATION') {
    if (!target.text) target.text = '';
    const html = line.replace(/\{\{([^}]+)\}\}/g, '<span class="glossary-term" data-term="$1">$1</span>');
    target.text += `<p>${html}</p>`;
  } else if (state === 'STATUS') {
    target.name = line;
  } else if (state === 'DIAGRAM') {
    if (line.startsWith('panel')) {
      target.name = 'panel';
      target.panel = line.split(' ')[1];
    } else if (/\d/.test(line)) {
      if (!target.bounds) target.bounds = [];
      target.bounds.push(line.split(' ').map(atoi));
    } else {
      target.name = line;
    }
  }
}

// lowercase everything and move things around
for (const key of Object.keys(out)) {
  out[key.toLowerCase()] = { events: out[key] };
  delete out[key];
}
out.events = out.layout.events;
delete out.layout;

writeFileSync(`${base}.json`, JSON.stringify(out), 'utf8');

