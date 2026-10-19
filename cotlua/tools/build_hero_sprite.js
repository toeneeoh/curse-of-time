// Classic MDX -> trimmed, unshaded hero-select sprite. No external dependencies.
// Usage: node cotlua/tools/build_hero_sprite.js <source.mdx> <sprite.mdx>
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const {chunks} = require('./build_loot_model');
const uint = n => {const b = Buffer.alloc(4); b.writeUInt32LE(n); return b;};
const pack = (tag, body) => Buffer.concat([Buffer.from(tag), uint(body.length), body]);
const text = b => b.toString('utf8').split('\0')[0];
// Same axis permutation as the owner's root_bind in HighPriestessSprite,
// ArcanistSprite and DarkSaviorSprite: model (X,Y,Z) -> sprite (Y,Z,X).
const ROTATION = [-.5, -.5, -.5, .5];
const dimensions = {KGTR: 3, KGRT: 4, KGSC: 3, KMTA: 1, KMTF: 1};
function tracks(body, intervals) {
    const output = [];
    for (let p = 0; p < body.length;) {
        const tag = body.toString('ascii', p, p + 4), dimension = dimensions[tag];
        if (!dimension || p + 16 > body.length) throw new Error('Unsupported sprite track: ' + tag);
        const count = body.readUInt32LE(p + 4), interpolation = body.readUInt32LE(p + 8);
        const global = body.readInt32LE(p + 12);
        if (interpolation > 3) throw new Error('Invalid interpolation');
        const size = 4 + dimension * 4 * (interpolation > 1 ? 3 : 1), end = p + 16 + count * size;
        if (end > body.length) throw new Error('Truncated track');
        const keys = [];
        for (let q = p + 16; q < end; q += size) {
            const time = body.readUInt32LE(q);
            if (global >= 0 || intervals.some(([start, finish]) => time >= start && time <= finish)) {
                keys.push(body.subarray(q, q + size));
            }
        }
        if (keys.length) output.push(Buffer.concat([body.subarray(p, p + 4), uint(keys.length),
            body.subarray(p + 8, p + 16), ...keys]));
        p = end;
    }
    return Buffer.concat(output);
}
function rotateExtent(input) {
    const out = Buffer.from(input);
    // Extent layout: radius, minimum XYZ, maximum XYZ.
    for (const base of [4, 16]) for (let axis = 0; axis < 3; axis++) {
        out.writeFloatLE(input.readFloatLE(base + ((axis + 1) % 3) * 4), base + axis * 4);
    }
    return out;
}
function build(input) {
    const parts = chunks(input), byTag = new Map(parts.map(c => [c.tag, c.body]));
    if (byTag.get('VERS')?.readUInt32LE(0) !== 800) throw new Error('Only classic v800 MDX is supported');
    for (const tag of parts.map(c => c.tag)) {
        if (!['VERS', 'MODL', 'SEQS', 'GLBS', 'MTLS', 'TEXS', 'GEOS', 'BONE', 'HELP',
            'ATCH', 'PIVT', 'PREM', 'PRE2', 'RIBB', 'LITE', 'CAMS', 'EVTS', 'CLID'].includes(tag)) {
            throw new Error('Unsupported model chunk: ' + tag);
        }
    }
    const sequences = byTag.get('SEQS'), keep = [], intervals = [];
    if (!sequences || sequences.length % 132) throw new Error('Invalid sequences');
    for (let p = 0; p < sequences.length; p += 132) {
        const name = text(sequences.subarray(p, p + 80));
        // Ordinary idle variants only; victory is an action pose, not an idle.
        if (/^Stand(?:\s+-?\d+|\s+Second)?$/i.test(name)) {
            keep.push(p / 132);
            intervals.push([sequences.readUInt32LE(p + 80), sequences.readUInt32LE(p + 84)]);
        }
    }
    if (!keep.length) throw new Error('No idle Stand animation');
    const pivots = byTag.get('PIVT');
    if (!pivots || pivots.length % 12) throw new Error('Invalid pivots');
    const nodeOrder = [];
    for (const tag of ['BONE', 'HELP']) {
        const body = byTag.get(tag);
        if (!body) continue;
        for (let p = 0; p < body.length;) {
            const size = body.readUInt32LE(p), id = body.readInt32LE(p + 84);
            if (size < 96 || p + size > body.length || id < 0 || id * 12 >= pivots.length || nodeOrder.includes(id)) {
                throw new Error('Invalid original node');
            }
            nodeOrder.push(id); p += size + (tag === 'BONE' ? 8 : 0);
        }
    }
    const nodeIds = new Map(nodeOrder.map((id, i) => [id, i])), rootId = nodeOrder.length;
    const rootHeader = Buffer.alloc(96);
    rootHeader.write('root_bind', 4); rootHeader.writeInt32LE(rootId, 84);
    rootHeader.writeInt32LE(-1, 88);
    const keyframes = intervals.flatMap(([start, end]) => [start, end]).map(time => {
        const key = Buffer.alloc(20); key.writeUInt32LE(time);
        ROTATION.forEach((value, i) => key.writeFloatLE(value, 4 + i * 4)); return key;
    });
    const root = Buffer.concat([rootHeader, Buffer.from('KGRT'), uint(keyframes.length), uint(1),
        uint(0xFFFFFFFF), ...keyframes]);
    root.writeUInt32LE(root.length, 0);
    if (!byTag.has('HELP')) parts.push({tag: 'HELP', body: Buffer.alloc(0)});
    const output = [];
    for (let {tag, body} of parts) {
        if (['ATCH', 'PREM', 'PRE2', 'RIBB', 'LITE', 'CAMS', 'EVTS', 'CLID'].includes(tag)) continue;
        if (tag === 'SEQS') {
            body = Buffer.concat(keep.map(index => {
                const seq = Buffer.from(sequences.subarray(index * 132, (index + 1) * 132));
                rotateExtent(seq.subarray(104, 132)).copy(seq, 104); return seq;
            }));
        } else if (tag === 'MODL') {
            body = Buffer.from(body); rotateExtent(body.subarray(340, 368)).copy(body, 340);
        } else if (tag === 'MTLS') {
            const materials = [];
            for (let p = 0; p < body.length;) {
                const end = p + body.readUInt32LE(p), layers = [];
                if (body.toString('ascii', p + 12, p + 16) !== 'LAYS') throw new Error('Invalid material');
                let q = p + 20;
                for (let i = 0; i < body.readUInt32LE(p + 16); i++) {
                    const finish = q + body.readUInt32LE(q), header = Buffer.from(body.subarray(q, q + 28));
                    const layer = Buffer.concat([header, tracks(body.subarray(q + 28, finish), intervals)]);
                    layer.writeUInt32LE(layer.length, 0);
                    layer.writeUInt32LE(layer.readUInt32LE(8) | 1, 8); // Unshaded
                    layers.push(layer); q = finish;
                }
                if (q !== end) throw new Error('Unexpected material fields');
                const material = Buffer.concat([body.subarray(p, p + 20), ...layers]);
                material.writeUInt32LE(material.length, 0); materials.push(material); p = end;
            }
            body = Buffer.concat(materials);
        } else if (tag === 'BONE' || tag === 'HELP') {
            const nodes = [];
            for (let p = 0; p < body.length;) {
                const end = p + body.readUInt32LE(p), suffix = tag === 'BONE' ? 8 : 0;
                if (end < p + 96 || end + suffix > body.length) throw new Error('Invalid node');
                const header = Buffer.from(body.subarray(p, p + 96));
                const id = header.readInt32LE(84), parent = header.readInt32LE(88);
                if (parent !== -1 && !nodeIds.has(parent)) throw new Error('A retained node depends on a removed node');
                header.writeInt32LE(nodeIds.get(id), 84);
                header.writeInt32LE(parent === -1 ? rootId : nodeIds.get(parent), 88);
                const node = Buffer.concat([header, tracks(body.subarray(p + 96, end), intervals)]);
                node.writeUInt32LE(node.length, 0);
                nodes.push(node, body.subarray(end, end + suffix)); p = end + suffix;
            }
            if (tag === 'HELP') nodes.push(root);
            body = Buffer.concat(nodes);
        } else if (tag === 'PIVT') body = Buffer.concat([
            ...nodeOrder.map(id => body.subarray(id * 12, id * 12 + 12)), Buffer.alloc(12)]);
        else if (tag === 'GEOS') {
            const geosets = [];
            for (let p = 0; p < body.length;) {
                const end = p + body.readUInt32LE(p); let q = p + 4;
                const geometry = Buffer.from(body.subarray(p, end));
                for (const [name, stride] of [['VRTX', 12], ['NRMS', 12], ['PTYP', 4], ['PCNT', 4],
                    ['PVTX', 2], ['GNDX', 1], ['MTGC', 4], ['MATS', 4]]) {
                    if (body.toString('ascii', q, q + 4) !== name) throw new Error('Unsupported geoset');
                    if (name === 'MATS') for (let i = 0; i < body.readUInt32LE(q + 4); i++) {
                        const offset = q + 8 + i * 4, id = body.readUInt32LE(offset);
                        if (!nodeIds.has(id)) throw new Error('Mesh depends on removed node');
                        geometry.writeUInt32LE(nodeIds.get(id), offset - p);
                    }
                    q += 8 + body.readUInt32LE(q + 4) * stride;
                }
                q += 12; // material, selection group and flags
                const count = body.readUInt32LE(q + 28);
                if (![0, 1, sequences.length / 132].includes(count) || q + 32 + count * 28 > end) {
                    throw new Error('Geoset animation bounds do not match sequences');
                }
                const mesh = Buffer.concat([geometry.subarray(0, q - p), rotateExtent(body.subarray(q, q + 28)),
                    uint(keep.length), ...keep.map(i => {
                        const start = count === 0 ? q : q + 32 + (count === 1 ? 0 : i) * 28;
                        return rotateExtent(body.subarray(start, start + 28));
                    }),
                    body.subarray(q + 32 + count * 28, end)]);
                mesh.writeUInt32LE(mesh.length, 0); geosets.push(mesh); p = end;
            }
            body = Buffer.concat(geosets);
        }
        output.push(pack(tag, body));
    }
    return Buffer.concat([Buffer.from('MDLX'), ...output]);
}
if (require.main === module) {
    const [, , source, destination] = process.argv;
    if (!source || !destination) throw new Error('Source and destination paths are required');
    const output = build(fs.readFileSync(source));
    fs.mkdirSync(path.dirname(destination), {recursive: true}); fs.writeFileSync(destination, output);
    console.log(`Hero sprite: ${output.length} bytes, idle Stand variants, unshaded, shared root rotation, no emitters/events.`);
}
module.exports = {build, tracks, ROTATION};
