const { basename } = require('path');
const { readFileSync, writeFileSync } = require('fs');

const filename = process.argv[2];
const base = basename(filename, '.csv');

const text = readFileSync(`./${filename}`, 'utf8');

const [ header, ...rows ] = text.split('\r');
const vals = header.split(',').map(name => ({ name, points: [] }));

for (const row of rows) {
  const cols = row.split(',');
  if (cols.length === 1) continue;

  const [ , hh, mm, ss ] = /(..):(..):(..)/.exec(cols[0]);
  const epoch = 3600 * hh + 60 * mm + ss;

  for (let i = 0; i < cols.length; i++) {
    const val = cols[i];
    if (val) vals[i].points.push([ epoch, val ]);
  }
}

const out = {};
for (const stream of vals.slice(1))
  out[stream.name] = stream.points;
writeFileSync(`${base}.json`, JSON.stringify(out), 'utf8');

