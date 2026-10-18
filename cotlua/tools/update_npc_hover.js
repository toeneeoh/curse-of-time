// Author NPC building/Neutral hover settings without replacing unit definitions.
// Usage: node cotlua/tools/update_npc_hover.js <editable-map-directory> [--check]
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const TARGETS = ['h059', 'nLTP', 'h036', 'h03A', 'h009'];
const EDITED_FIELDS = new Set(['utyp', 'ubdg']);
const int = n => {const b = Buffer.alloc(4); b.writeInt32LE(n); return b;};
function parse(input) {
    let offset = 0;
    const integer = () => {const value = input.readInt32LE(offset); offset += 4; return value;};
    const raw = () => {
        if (offset + 4 > input.length) throw new Error('Truncated rawcode');
        const value = input.toString('latin1', offset, offset + 4); offset += 4; return value;
    };
    const version = integer(), tables = [];
    if (version < 1 || version > 3) throw new Error('Unsupported unit object version');
    for (let table = 0; table < 2; table++) {
        const count = integer(), records = [];
        if (count < 0) throw new Error('Invalid unit count');
        for (let index = 0; index < count; index++) {
            const start = offset, base = raw(), custom = raw();
            if (version >= 3) {
                const flags = integer();
                if (flags < 0 || offset + flags * 4 > input.length) throw new Error('Invalid unit flags');
                offset += flags * 4;
            }
            const header = input.subarray(start, offset), mods = integer(), fields = [];
            if (mods < 0) throw new Error('Invalid modification count');
            for (let mod = 0; mod < mods; mod++) {
                const fieldStart = offset, field = raw(), type = integer();
                let value;
                if (type === 3) {
                    const end = input.indexOf(0, offset);
                    if (end < 0) throw new Error('Unterminated unit string');
                    value = input.toString('utf8', offset, end); offset = end + 1;
                } else if (type === 0) value = integer();
                else if (type === 1 || type === 2) {value = input.readFloatLE(offset); offset += 4;}
                else throw new Error('Invalid unit modification type');
                const endToken = input.subarray(offset, offset + 4); raw();
                fields.push({field, type, value, endToken, bytes: input.subarray(fieldStart, offset)});
            }
            records.push({id: custom === '\0\0\0\0' ? base : custom, base, header, fields,
                bytes: input.subarray(start, offset)});
        }
        tables.push(records);
    }
    if (offset !== input.length) throw new Error('Unit file length mismatch');
    return {version, tables};
}
function transform(input, addIfMissing = true) {
    const {version, tables} = parse(input), found = new Set();
    const output = [int(version)];
    for (const records of tables) {
        output.push(int(records.length));
        for (const record of records) {
            if (!TARGETS.includes(record.id)) {output.push(record.bytes); continue;}
            if (found.has(record.id)) throw new Error('Duplicate target unit: ' + record.id);
            found.add(record.id);
            const fields = record.fields.map(f => f.bytes);
            let changed = false;
            for (const [name, type] of [['utyp', 3], ['ubdg', 0]]) {
                const matches = record.fields.filter(f => f.field === name), existing = matches[0];
                if (matches.length > 1 || (existing && existing.type !== type)) throw new Error('Invalid hover field: ' + name);
                if (!existing && !addIfMissing) continue;
                let value = 1;
                if (name === 'utyp') {
                    const tags = (existing?.value || '').split(',').map(s => s.trim()).filter(s => s && s !== '-' && s !== '_');
                    if (tags.some(tag => tag.toLowerCase() === 'neutral')) continue;
                    tags.push('neutral'); value = tags.join(',');
                } else if (existing?.value === 1) continue;
                const replacement = Buffer.concat([Buffer.from(name), int(type),
                    type === 3 ? Buffer.from(value + '\0') : int(value), existing?.endToken || Buffer.alloc(4)]);
                if (existing) fields[record.fields.indexOf(existing)] = replacement;
                else fields.push(replacement);
                changed = true;
            }
            if (!changed) {output.push(record.bytes); continue;}
            output.push(record.header, int(fields.length), ...fields);
        }
    }
    for (const id of TARGETS) if (!found.has(id)) throw new Error('Missing target unit: ' + id);
    return Buffer.concat(output);
}
if (require.main === module) {
    const directory = process.argv[2], check = process.argv.includes('--check');
    if (!directory) throw new Error('Editable map directory is required');
    // Hover settings belong in gameplay data. Only update a skin override
    // when it already exists, so artwork-only skin records remain byte-exact.
    const changes = ['war3map', 'war3mapSkin'].map(stem => {
        const file = path.join(directory, stem + '.w3u'), input = fs.readFileSync(file);
        return {file, input, output: transform(input, stem === 'war3map')};
    });
    for (const {input, output} of changes) {
        const before = parse(input).tables.flat(), after = parse(output).tables.flat();
        if (before.length !== after.length) throw new Error('Unexpected record count change');
        for (let index = 0; index < before.length; index++) {
            const a = before[index], b = after[index];
            const unchanged = TARGETS.includes(a.id) ?
                a.header.equals(b.header) && Buffer.concat(a.fields.filter(f => !EDITED_FIELDS.has(f.field)).map(f => f.bytes)).equals(
                    Buffer.concat(b.fields.filter(f => !EDITED_FIELDS.has(f.field)).map(f => f.bytes))) : a.bytes.equals(b.bytes);
            if (!unchanged) throw new Error('Unexpected change outside target hover settings: ' + a.id);
        }
        if (!transform(output, false).equals(output)) throw new Error('Hover settings verification failed');
    }
    if (!check) {
        for (const {file, input} of changes) if (!fs.readFileSync(file).equals(input)) throw new Error('Unit data changed while preparing patch');
        for (const {file, input, output} of changes) if (!input.equals(output)) fs.writeFileSync(file, output);
        for (const {file, output} of changes) if (!fs.readFileSync(file).equals(output)) throw new Error('Written unit data verification failed');
    }
    for (const {file, input, output} of changes) console.log(`${check ? 'Preview' : 'Verified'} ${path.basename(file)}: ${input.equals(output) ? 'unchanged' : 'Building/Neutral hover settings updated'}; artwork and other fields preserved.`);
    console.log('Targets: Director (h059, including Chaos), Bundle (nLTP), Huntsman (h036), Headhunter (h03A), Chaotic Huntsman (h009). No map packaged.');
}
module.exports = {parse, transform, TARGETS};
