// Add/verify ground proxy I1LP and selectable bundle nLTP. No map packaging.
// Usage: node cotlua/tools/update_loot_objects.js <unpacked-map-directory>
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const {repair} = require('./build_loot_model.js');
const int = n => {const b = Buffer.alloc(4); b.writeInt32LE(n); return b;};
const real = n => {const b = Buffer.alloc(4); b.writeFloatLE(n); return b;};
const str = s => Buffer.from(s + '\0');
const specs = {
    w3t: {base: 'gold', id: 'I1LP', fields: [
        ['unam', 3, 'Ground Loot'], ['ifil', 3, 'Objects\\InventoryItems\\TreasureChest\\treasurechest.mdl'],
        ['iico', 3, 'ReplaceableTextures\\CommandButtons\\BTNChestOfGold.blp'],
        ['iabi', 3, ''], ['icla', 3, 'PowerUp'], ['ipow', 0, 1], ['iper', 0, 1],
        ['iusa', 0, 1], ['iuse', 0, 1], ['igol', 0, 0], ['ilum', 0, 0], ['ipaw', 0, 0], ['idro', 0, 0],
    ]},
    w3u: {base: 'nshe', id: 'nLTP', fields: [
        // Map-local TreasurePile0 with repaired Stand/geoset animation bounds.
        ['unam', 3, 'Items dropped'], ['umdl', 3, 'loot_bundle.mdx'],
        ['uico', 3, 'ReplaceableTextures\\CommandButtons\\BTNChestOfGold.blp'],
        ['uabi', 3, 'Avul'], ['ubdg', 0, 1], ['utyp', 3, 'neutral'], ['upat', 3, ''],
        ['umvs', 0, 0], ['umvt', 3, ''], ['ucol', 2, 0], ['uaen', 0, 0],
        ['uhpm', 0, 1], ['uhpr', 2, 0], ['umpm', 0, 0], ['ubba', 0, 0], ['ubdi', 0, 0],
        ['ushh', 2, 0], ['ushw', 2, 0], ['ushu', 3, ''], ['usnd', 3, ''], ['usca', 2, 1], ['ussc', 2, .7],
    ]},
};
function transform(input, spec) {
    let offset = 0;
    const readInt = () => {const n = input.readInt32LE(offset); offset += 4; return n;};
    const raw = () => {const s = input.toString('latin1', offset, offset + 4); offset += 4; return s;};
    const version = readInt();
    if (version < 1 || version > 3) throw new Error('Unsupported object version');
    const output = [int(version)];
    let found = false;
    for (let table = 0; table < 2; table++) {
        const count = readInt(), records = [];
        for (let i = 0; i < count; i++) {
            const start = offset, base = raw(), id = raw();
            if (version >= 3) {const flags = readInt(); offset += flags * 4;}
            const mods = readInt();
            for (let m = 0; m < mods; m++) {
                raw(); const type = readInt();
                if (type === 3) {const end = input.indexOf(0, offset); if (end < 0) throw new Error('Unterminated string'); offset = end + 1;}
                else if (type >= 0 && type <= 2) offset += 4;
                else throw new Error('Unknown modification type');
                raw();
            }
            if (id === spec.id || base === spec.id) {
                if (found || table !== 1 || base !== spec.base) throw new Error('Rawcode collision: ' + spec.id);
                found = true;
            } else records.push(input.subarray(start, offset));
        }
        if (table === 1) {
            const mods = spec.fields.map(([field, type, value]) => Buffer.concat([
                Buffer.from(field), int(type), type === 3 ? str(value) : type === 0 ? int(value) : real(value), Buffer.alloc(4),
            ]));
            records.push(Buffer.concat([Buffer.from(spec.base + spec.id),
                ...(version >= 3 ? [int(1), int(0)] : []), int(mods.length), ...mods]));
        }
        output.push(int(records.length), ...records);
    }
    if (offset !== input.length) throw new Error('Object file length mismatch');
    return Buffer.concat(output);
}
function registerImport(input, name) {
    if (input.readUInt32LE(0) !== 1) throw new Error('Unsupported import manifest');
    const count = input.readUInt32LE(4);
    let offset = 8, found = false;
    for (let index = 0; index < count; index++) {
        const end = input.indexOf(0, offset + 1);
        if (end < 0) throw new Error('Truncated import manifest');
        if (input.toString('utf8', offset + 1, end).toLowerCase() === name.toLowerCase()) found = true;
        offset = end + 1;
    }
    if (offset !== input.length) throw new Error('Import manifest length mismatch');
    if (found) return input;
    return Buffer.concat([int(1), int(count + 1), input.subarray(8), Buffer.from([13]), str(name)]);
}
// Change only the building flag on existing merchants. Retain every other
// modification, including separate gameplay/skin data and v3 object flags.
function setBuildingFlags(input, ids = ['n01A', 'n01B']) {
    let offset = 0;
    const readInt = () => {const n = input.readInt32LE(offset); offset += 4; return n;};
    const raw = () => {const s = input.toString('latin1', offset, offset + 4); offset += 4; return s;};
    const version = readInt(), found = new Set(), output = [int(version)];
    if (version < 1 || version > 3) throw new Error('Unsupported object version');
    for (let table = 0; table < 2; table++) {
        const count = readInt(); output.push(int(count));
        for (let index = 0; index < count; index++) {
            const start = offset, base = raw(), id = raw();
            const target = ids.includes(id) ? id : id === '\0\0\0\0' && ids.includes(base) ? base : null;
            if (version >= 3) {const flags = readInt(); offset += flags * 4;}
            const countOffset = offset, modifications = readInt(), fields = [];
            let building = false;
            for (let mod = 0; mod < modifications; mod++) {
                const fieldStart = offset, field = raw(), type = readInt();
                if (type === 3) {
                    const end = input.indexOf(0, offset);
                    if (end < 0) throw new Error('Unterminated unit string');
                    offset = end + 1;
                } else if (type >= 0 && type <= 2) offset += 4;
                else throw new Error('Unknown unit modification type');
                raw();
                if (target && field === 'ubdg') {
                    if (building) throw new Error('Duplicate building flag');
                    building = true;
                    fields.push(Buffer.concat([Buffer.from('ubdg'), int(0), int(1), input.subarray(offset - 4, offset)]));
                } else fields.push(input.subarray(fieldStart, offset));
            }
            if (target) {
                if (found.has(target)) throw new Error('Duplicate merchant: ' + target);
                found.add(target);
                if (!building) fields.push(Buffer.concat([Buffer.from('ubdg'), int(0), int(1), Buffer.alloc(4)]));
                output.push(input.subarray(start, countOffset), int(fields.length), ...fields);
            } else output.push(input.subarray(start, offset));
        }
    }
    if (offset !== input.length) throw new Error('Unit file length mismatch');
    for (const id of ids) if (!found.has(id)) throw new Error('Missing merchant: ' + id);
    return Buffer.concat(output);
}
if (require.main === module) {
    const directory = process.argv[2];
    if (!directory) throw new Error('An unpacked map directory is required');
    const changes = [];
    for (const [extension, spec] of Object.entries(specs)) for (const stem of ['war3map', 'war3mapSkin']) {
        const file = path.join(directory, stem + '.' + extension);
        const input = fs.readFileSync(file);
        let output = transform(input, spec);
        if (extension === 'w3u') output = setBuildingFlags(output);
        changes.push({file, input, output});
    }
    const model = fs.readFileSync(path.join(__dirname, '../assets/loot_bundle.mdx'));
    if (!repair(model).equals(model)) throw new Error('Loot model animation bounds need rebuilding');
    const modelFile = path.join(directory, 'loot_bundle.mdx');
    changes.push({file: modelFile, input: fs.existsSync(modelFile) ? fs.readFileSync(modelFile) : Buffer.alloc(0), output: model});
    const importFile = path.join(directory, 'war3map.imp'), imports = fs.readFileSync(importFile);
    changes.push({file: importFile, input: imports, output: registerImport(imports, 'loot_bundle.mdx')});
    // Validate every file before any write; unrelated records remain byte-exact.
    for (const {file, input, output} of changes) if (!input.equals(output)) fs.writeFileSync(file, output);
    console.log('Loot objects verified: I1LP pickup proxy; nLTP bundle, n01A and n01B authored as buildings. No map packaged.');
}
module.exports = {transform, specs, registerImport, setBuildingFlags};
