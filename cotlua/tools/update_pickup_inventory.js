// RETIRED experiment, kept for inspecting older betas. Current ground loot uses
// update_loot_objects.js and never attaches A1GP. This tool only edits objects.
// Add a secondary six-slot native Inventory for the old pickup experiment.
// Usage: node cotlua/tools/update_pickup_inventory.js <unpacked-map-directory>
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const integer = n => {const b = Buffer.alloc(4); b.writeInt32LE(n); return b;};
const string = s => Buffer.from(s + '\0', 'utf8');
const modification = (field, type, level, data, value) => Buffer.concat([
    Buffer.from(field), integer(type), integer(level), integer(data),
    type === 3 ? string(value) : integer(value), Buffer.alloc(4),
]);
function update(file, skin) {
    const input = fs.readFileSync(file);
    let offset = 0;
    const int = () => {const n = input.readInt32LE(offset); offset += 4; return n;};
    const raw = () => {const s = input.toString('latin1', offset, offset + 4); offset += 4; return s;};
    const version = int(), chunks = [integer(version)];
    if (version < 1 || version > 3) throw new Error('Unsupported object version ' + version);
    let found = false;
    for (let table = 0; table < 2; table++) {
        const count = int(), records = [];
        for (let i = 0; i < count; i++) {
            const start = offset, base = raw(), id = raw();
            if (version >= 3) {int(); int();}
            const mods = int();
            for (let m = 0; m < mods; m++) {
                raw(); const type = int(); int(); int();
                if (type === 3) {
                    const end = input.indexOf(0, offset);
                    if (end < 0) throw new Error('Unterminated object field');
                    offset = end + 1;
                } else if (type >= 0 && type <= 2) offset += 4;
                else throw new Error('Unsupported object field type ' + type);
                raw();
            }
            if (id === 'A1GP') {
                if (found || table !== 1 || base !== 'AInv') throw new Error('A1GP collision');
                found = true;
            } else records.push(input.subarray(start, offset));
        }
        if (table === 1) {
            const mods = [modification('anam', 3, 0, 0, 'Managed Pickup Inventory')];
            if (!skin) {
                for (const [field, value] of [['aher', 0], ['aite', 0], ['alev', 1]]) {
                    mods.push(modification(field, 0, 0, 0, value));
                }
                // Standard Inventory data: capacity, drop on death, use/get/drop.
                for (const [index, value] of [[1, 6], [2, 0], [3, 1], [4, 1], [5, 1]]) {
                    mods.push(modification('inv' + index, 0, 1, index, value));
                }
            }
            records.push(Buffer.concat([Buffer.from('AInvA1GP'),
                ...(version >= 3 ? [integer(1), integer(0)] : []), integer(mods.length), ...mods]));
        }
        chunks.push(integer(records.length), ...records);
    }
    if (offset !== input.length) throw new Error('Unexpected object data size in ' + file);
    return {file, input, output: Buffer.concat(chunks)};
}
const changes = ['war3map.w3a', 'war3mapSkin.w3a'].map((name, i) =>
    update(path.join(process.argv[2], name), i === 1));
for (const {file, input, output} of changes) if (!input.equals(output)) fs.writeFileSync(file, output);
console.log('A1GP: secondary six-slot AInv added; all other ability records preserved.');
