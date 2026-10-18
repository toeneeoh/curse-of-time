// Repair the classic static TreasurePile0 model's missing animation bounds.
// Usage: node cotlua/tools/build_loot_model.js <TreasurePile0.mdx> <output.mdx>
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const uint = n => {const b = Buffer.alloc(4); b.writeUInt32LE(n); return b;};
function chunks(input) {
    if (input.toString('ascii', 0, 4) !== 'MDLX') throw new Error('Not an MDX');
    const result = [];
    for (let offset = 4; offset < input.length;) {
        if (offset + 8 > input.length) throw new Error('Truncated MDX header');
        const tag = input.toString('ascii', offset, offset + 4), end = offset + 8 + input.readUInt32LE(offset + 4);
        if (end > input.length) throw new Error('Truncated MDX chunk');
        result.push({tag, body: input.subarray(offset + 8, end)}); offset = end;
    }
    return result;
}
function validExtent(extent) {
    const values = Array.from({length: 7}, (_, i) => extent.readFloatLE(i * 4));
    return values.every(Number.isFinite) && values[0] > 0 &&
        [0, 1, 2].every(i => values[i + 1] < values[i + 4]);
}
function repair(input) {
    const parts = chunks(input), find = tag => parts.find(p => p.tag === tag)?.body;
    if (find('VERS')?.readUInt32LE(0) !== 800) throw new Error('Expected a classic MDX');
    const model = find('MODL'), sequences = find('SEQS');
    if (!model || model.length !== 372 || !sequences || sequences.length !== 132 ||
        sequences.toString('ascii', 0, 80).split('\0')[0].toLowerCase() !== 'stand' || find('GEOA')) {
        throw new Error('Expected the static, single-Stand treasure-pile model');
    }
    const extent = model.subarray(340, 368);
    if (!validExtent(extent)) throw new Error('Missing model bounds');
    return Buffer.concat([Buffer.from('MDLX'), ...parts.map(({tag, body}) => {
        if (tag === 'SEQS') {
            body = Buffer.from(body); extent.copy(body, 104);
        } else if (tag === 'GEOS') {
            const meshes = [];
            for (let start = 0; start < body.length;) {
                const end = start + body.readUInt32LE(start);
                if (end <= start || end > body.length) throw new Error('Invalid geoset size');
                let offset = start + 4;
                for (const [name, size] of [['VRTX', 12], ['NRMS', 12], ['PTYP', 4], ['PCNT', 4],
                    ['PVTX', 2], ['GNDX', 1], ['MTGC', 4], ['MATS', 4]]) {
                    if (body.toString('ascii', offset, offset + 4) !== name) throw new Error('Invalid static geoset');
                    offset += 8 + body.readUInt32LE(offset + 4) * size;
                }
                offset += 12; // material ID, selection group, selection flags
                const meshExtent = body.subarray(offset, offset + 28);
                if (!validExtent(meshExtent)) throw new Error('Missing geoset bounds');
                offset += 28;
                const count = body.readUInt32LE(offset);
                if (count > 1 || offset + 4 + count * 28 > end) throw new Error('Unexpected animation extents');
                // Preserve all geometry, UVs, textures and animation data. The
                // doodad has zero per-sequence extents; a unit needs one.
                const mesh = Buffer.concat([body.subarray(start, offset), uint(1), meshExtent,
                    body.subarray(offset + 4 + count * 28, end)]);
                mesh.writeUInt32LE(mesh.length, 0); meshes.push(mesh); start = end;
            }
            body = Buffer.concat(meshes);
        }
        return Buffer.concat([Buffer.from(tag), uint(body.length), body]);
    })]);
}
if (require.main === module) {
    const [, , source, destination] = process.argv;
    if (!source || !destination) throw new Error('Source and destination MDX paths are required');
    const output = repair(fs.readFileSync(source));
    fs.mkdirSync(path.dirname(destination), {recursive: true}); fs.writeFileSync(destination, output);
    console.log('Loot model: opaque original geometry with valid Stand and geoset animation bounds.');
}
module.exports = {repair, chunks};
