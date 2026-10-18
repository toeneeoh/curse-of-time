// Use Berserk's instant alternate order queue for Smoke Bomb, separate from
// Phantom Slash (immolation) and manual Blade Spin (manashieldon).
// Usage: node cotlua/tools/update_assassin_smoke.js <unpacked-map-directory>
// Preserves other abilities, cooldowns, presentation fields and tooltip strings.
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const encodeInt = v => {const b = Buffer.alloc(4); b.writeInt32LE(v); return b;};
const encodeReal = v => {const b = Buffer.alloc(4); b.writeFloatLE(v); return b;};
const fields = new Map([
    ['bsk1', [2, 1, 0]], ['bsk2', [2, 2, 0]], ['bsk3', [2, 3, 0]],
    ['adur', [2, 0, .001]], ['ahdu', [2, 0, .001]],
    ['abuf', [3, 0, '']], ['acas', [2, 0, 0]], ['amcs', [0, 0, 0]],
]);

function update(file, skin) {
    const input = fs.readFileSync(file);
    let offset = 0;
    const int = () => {const v = input.readInt32LE(offset); offset += 4; return v;};
    const raw = () => {const v = input.toString('latin1', offset, offset + 4); offset += 4; return v;};
    const string = () => {const end = input.indexOf(0, offset); if (end < 0) throw new Error('Unterminated string'); offset = end + 1;};
    const version = int(), output = [encodeInt(version)];
    let changed = 0;
    for (let table = 0; table < 2; table++) {
        const count = int(); output.push(encodeInt(count));
        for (let index = 0; index < count; index++) {
            const start = offset, base = raw(), newId = raw();
            if (version >= 3) {int(); int();}
            const header = Buffer.from(input.subarray(start, offset));
            const total = int(), mods = [];
            for (let i = 0; i < total; i++) {
                const begin = offset, field = raw(), type = int();
                int(); int();
                if (type === 3) string();
                else if (type >= 0 && type <= 2) offset += 4;
                else throw new Error('Unsupported field type ' + type);
                raw();
                if (newId !== 'A01E' || skin ||
                    (!field.startsWith('Ncl') && !fields.has(field) && field !== 'aher')) {
                    mods.push(input.subarray(begin, offset));
                }
            }
            if (newId === 'A01E') {
                if (!['ANcl', 'Absk'].includes(base)) throw new Error('Unexpected Smoke Bomb base: ' + base);
                changed++;
                header.write('Absk', 0, 'latin1');
                if (!skin) {
                    mods.push(Buffer.concat([Buffer.from('aher'), encodeInt(0), encodeInt(0),
                        encodeInt(0), encodeInt(1), Buffer.alloc(4)]));
                    for (let level = 1; level <= 6; level++) {
                        for (const [field, [type, data, value]] of fields) {
                            const encoded = type === 3 ? Buffer.from(value + '\0') :
                                type === 0 ? encodeInt(value) : encodeReal(value);
                            mods.push(Buffer.concat([Buffer.from(field, 'latin1'), encodeInt(type),
                                encodeInt(level), encodeInt(data), encoded, Buffer.alloc(4)]));
                        }
                    }
                }
            }
            output.push(header, encodeInt(mods.length), ...mods);
        }
    }
    if (offset !== input.length || changed !== 1) throw new Error('Unexpected object data or missing/duplicate Smoke Bomb in ' + file);
    return {file, input, result: Buffer.concat(output)};
}

// Validate both files before writing either one. Never modify war3map.wts:
// the map author owns all Assassin tooltip text and formatting.
const updates = ['war3map.w3a', 'war3mapSkin.w3a'].map((name, index) =>
    update(path.join(process.argv[2], name), index === 1));
for (const {file, input, result} of updates) if (!result.equals(input)) fs.writeFileSync(file, result);
console.log('Smoke Bomb verified: Absk/berserk, native bonuses disabled, six hero levels, cooldowns and tooltips preserved.');
