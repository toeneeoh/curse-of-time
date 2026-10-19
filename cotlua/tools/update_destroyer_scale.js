// Reduce Dark Summoner's Destroyer to 1 / 2.2 of its previous visual size.
// Usage: node cotlua/tools/update_destroyer_scale.js <editable-map-directory> [--check]
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const {parse} = require('./update_npc_hover');
const uint = n => {const b = Buffer.alloc(4); b.writeUInt32LE(n); return b;};
function transform(input) {
    const {version, tables} = parse(input), output = [uint(version)]; let found = false;
    for (const records of tables) {
        output.push(uint(records.length));
        for (const record of records) {
            const scale = record.fields.filter(f => f.field === 'usca');
            if (record.id !== 'E014' || !scale.length) {output.push(record.bytes); continue;}
            if (found || scale.length !== 1 || ![1, 2].includes(scale[0].type)) {
                throw new Error('Invalid Destroyer model scale');
            }
            found = true;
            output.push(record.header, uint(record.fields.length), ...record.fields.map(f => {
                if (f.field !== 'usca') return f.bytes;
                const bytes = Buffer.from(f.bytes);
                bytes.writeFloatLE(.5, 8); // Previous authored scale: 1.1.
                return bytes;
            }));
        }
    }
    return {output: Buffer.concat(output), found};
}
if (require.main === module) {
    const directory = process.argv[2], check = process.argv.includes('--check');
    if (!directory) throw new Error('Editable map directory is required');
    const changes = ['war3map', 'war3mapSkin'].map(stem => {
        const file = path.join(directory, stem + '.w3u'), input = fs.readFileSync(file);
        return {file, input, ...transform(input)};
    });
    if (!changes.some(c => c.found)) throw new Error('Missing Destroyer scale field');
    const pending = changes.filter(c => !c.input.equals(c.output));
    if (check && pending.length) throw new Error('Destroyer scale needs updating');
    if (!check) {
        for (const c of changes) if (!fs.readFileSync(c.file).equals(c.input)) throw new Error('Unit data changed during preparation');
        for (const c of pending) fs.writeFileSync(c.file, c.output);
    }
    for (const c of changes) if (!fs.readFileSync(c.file).equals(c.output)) throw new Error('Scale verification failed');
    console.log(`Destroyer (E014): model scale 0.5, down from 1.1 (45.45% of previous size); ${pending.length} files updated.`);
}
module.exports = {transform};
