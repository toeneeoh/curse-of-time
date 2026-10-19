// Install the supplied High Priestess model, its textures and trimmed UI sprite.
// Usage: node cotlua/tools/update_high_priestess.js <editable-map-directory> [--check]
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const {parse} = require('./update_npc_hover');
const {build} = require('./build_hero_sprite');
const {gameplayModel} = require('./high_priestess_model');
const uint = n => {const b = Buffer.alloc(4); b.writeUInt32LE(n); return b;};
const MODEL = 'war3mapImported\\HighPriestess.mdx';
const ASSETS = new Map([
    [MODEL, 'HighPriestess.mdx'], ['HighPriestessSprite.mdx', 'HighPriestessSprite.mdx'],
    ['calia.blp', 'calia.blp'], ['calia1.blp', 'calia1.blp'],
]);
function modelField(input) {
    const {version, tables} = parse(input), output = [uint(version)]; let found = false;
    for (const records of tables) {
        output.push(uint(records.length));
        for (const record of records) {
            const fields = record.fields.filter(f => f.field === 'umdl');
            if (record.id !== 'E012' || !fields.length) {output.push(record.bytes); continue;}
            if (found || fields.length !== 1 || fields[0].type !== 3) throw new Error('Invalid High Priestess model field');
            found = true;
            output.push(record.header, uint(record.fields.length), ...record.fields.map(f =>
                f.field === 'umdl' ? Buffer.concat([Buffer.from('umdl'), uint(3), Buffer.from(MODEL + '\0'), f.endToken]) : f.bytes));
        }
    }
    return {output: Buffer.concat(output), found};
}
function imports(input) {
    if (input.readUInt32LE(0) !== 1) throw new Error('Unsupported import table version');
    let offset = 8; const entries = [], names = new Set();
    for (let i = 0; i < input.readUInt32LE(4); i++) {
        const start = offset++, end = input.indexOf(0, offset);
        if (end < 0) throw new Error('Unterminated import');
        const name = input.toString('utf8', offset, end).replaceAll('/', '\\').toLowerCase();
        names.add(name); offset = end + 1; entries.push(input.subarray(start, offset));
    }
    if (offset !== input.length) throw new Error('Unexpected import data');
    for (const name of ASSETS.keys()) if (!names.has(name.toLowerCase())) {
        // 13 denotes a custom full path. Preserve the existing editor's flags
        // and entries byte-for-byte, including the existing sprite import.
        entries.push(Buffer.concat([Buffer.from([13]), Buffer.from(name + '\0')]));
    }
    return Buffer.concat([uint(1), uint(entries.length), ...entries]);
}
function prepare(directory) {
    const assets = path.resolve(__dirname, '../assets/high_priestess');
    const source = fs.readFileSync(path.join(assets, 'HighPriestess.mdx'));
    if (!build(source).equals(fs.readFileSync(path.join(assets, 'HighPriestessSprite.mdx')))) {
        throw new Error('Rebuild the hero-select sprite before installing');
    }
    const changes = []; let found = false;
    for (const stem of ['war3map', 'war3mapSkin']) {
        const file = path.join(directory, stem + '.w3u'), input = fs.readFileSync(file);
        const result = modelField(input); found ||= result.found;
        changes.push({file, input, output: result.output});
    }
    if (!found) throw new Error('Missing High Priestess model field');
    const imp = path.join(directory, 'war3map.imp'), input = fs.readFileSync(imp);
    changes.push({file: imp, input, output: imports(input)});
    for (const [name, asset] of ASSETS) {
        const file = path.join(directory, ...name.split('\\'));
        changes.push({file, input: fs.existsSync(file) ? fs.readFileSync(file) : null,
            output: name === MODEL ? gameplayModel(source) : fs.readFileSync(path.join(assets, asset))});
    }
    return changes;
}
if (require.main === module) {
    const directory = process.argv[2], check = process.argv.includes('--check');
    if (!directory) throw new Error('Editable map directory is required');
    const changes = prepare(directory), pending = changes.filter(c => !c.input?.equals(c.output));
    if (check && pending.length) throw new Error('High Priestess assets need installing: ' + pending.map(c => c.file).join(', '));
    if (!check) {
        for (const change of changes) {
            const current = fs.existsSync(change.file) ? fs.readFileSync(change.file) : null;
            if (current === null ? change.input !== null : !current.equals(change.input || Buffer.alloc(0))) {
                throw new Error('Map changed while preparing import: ' + change.file);
            }
        }
        for (const {file, output} of pending) {
            fs.mkdirSync(path.dirname(file), {recursive: true}); fs.writeFileSync(file, output);
        }
    }
    if (prepare(directory).some(c => !c.input?.equals(c.output))) throw new Error('Import verification failed');
    console.log(`High Priestess verified: E012 model, idle/unshaded selection sprite, two custom textures; ${pending.length} files updated.`);
}
module.exports = {modelField, imports, MODEL, ASSETS};
