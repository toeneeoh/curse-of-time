'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {chunks} = require('./build_loot_model');
const {build, ROTATION} = require('./build_hero_sprite');
const {modelField, imports, MODEL, ASSETS} = require('./update_high_priestess');
const {parse} = require('./update_npc_hover');
const directory = path.resolve(__dirname, '../assets/high_priestess');
const source = fs.readFileSync(path.join(directory, 'HighPriestess.mdx'));
const sprite = fs.readFileSync(path.join(directory, 'HighPriestessSprite.mdx'));
const src = new Map(chunks(source).map(c => [c.tag, c.body]));
const out = new Map(chunks(sprite).map(c => [c.tag, c.body]));
assert.deepEqual(build(source), sprite, 'Committed sprite is not reproducible');
assert(sprite.length < source.length * .65, 'Unused animation data was retained');
for (const tag of ['PREM', 'PRE2', 'RIBB', 'LITE', 'CAMS', 'EVTS', 'CLID', 'ATCH']) {
    assert(!out.has(tag), 'Sprite retains emitter/sound/attachment data: ' + tag);
}
for (const tag of ['VERS', 'TEXS', 'GLBS']) assert.deepEqual(out.get(tag), src.get(tag));
const intervals = [], names = [];
for (let p = 0; p < out.get('SEQS').length; p += 132) {
    const seq = out.get('SEQS');
    names.push(seq.toString('utf8', p, p + 80).split('\0')[0]);
    intervals.push([seq.readUInt32LE(p + 80), seq.readUInt32LE(p + 84)]);
}
assert.deepEqual(names, ['Stand -1', 'Stand Second']);
function checkTracks(body) {
    for (let p = 0; p < body.length;) {
        const tag = body.toString('ascii', p, p + 4), count = body.readUInt32LE(p + 4);
        const interpolation = body.readUInt32LE(p + 8), global = body.readInt32LE(p + 12);
        const dimension = ({KGTR: 3, KGRT: 4, KGSC: 3, KMTA: 1, KMTF: 1})[tag];
        assert(dimension, 'Unknown animation track');
        const stride = 4 + dimension * 4 * (interpolation > 1 ? 3 : 1);
        for (let i = 0; i < count; i++) {
            const time = body.readUInt32LE(p + 16 + i * stride);
            assert(global >= 0 || intervals.some(([start, end]) => time >= start && time <= end),
                'Non-Stand keyframe survived trimming');
        }
        p += 16 + stride * count;
        assert(p <= body.length);
    }
}
const nodes = [];
for (const tag of ['BONE', 'HELP']) {
    const body = out.get(tag);
    for (let p = 0; p < body.length;) {
        const size = body.readUInt32LE(p), node = body.subarray(p, p + size);
        nodes.push({id: node.readInt32LE(84), parent: node.readInt32LE(88),
            name: node.toString('utf8', 4, 84).split('\0')[0], body: node});
        checkTracks(node.subarray(96)); p += size + (tag === 'BONE' ? 8 : 0);
    }
}
assert.equal(nodes.length, 22);
assert.deepEqual(nodes.map(n => n.id), Array.from({length: nodes.length}, (_, i) => i), 'Node IDs contain gaps');
assert.equal(out.get('PIVT').length, nodes.length * 12, 'Pivots do not match compacted IDs');
const roots = nodes.filter(n => n.parent === -1);
assert.equal(roots.length, 1); assert.equal(roots[0].name, 'root_bind');
assert.deepEqual(Array.from({length: 4}, (_, i) => roots[0].body.readFloatLE(116 + i * 4)), ROTATION);
for (const node of nodes) {
    let current = node, visited = new Set();
    while (current.parent !== -1) {
        assert(!visited.has(current.id), 'Cyclic hierarchy'); visited.add(current.id);
        current = nodes[current.parent]; assert(current, 'Dangling parent');
    }
    assert.equal(current, roots[0], 'Bone is outside the rotation root');
}
const materials = out.get('MTLS');
for (let p = 0; p < materials.length;) {
    const end = p + materials.readUInt32LE(p);
    for (let q = p + 20; q < end;) {
        assert(materials.readUInt32LE(q + 8) & 1, 'A sprite layer is still shaded');
        const finish = q + materials.readUInt32LE(q);
        checkTracks(materials.subarray(q + 28, finish)); q = finish;
    }
    p = end;
}
for (const name of ['calia.blp', 'calia1.blp']) {
    assert.equal(fs.readFileSync(path.join(directory, name)).toString('ascii', 0, 4), 'BLP1');
}
// Unit patch preserves unrelated objects, fields, versions and record counts.
const uint = n => {const b = Buffer.alloc(4); b.writeUInt32LE(n); return b;};
const record = (id, model) => Buffer.concat([Buffer.from('Ewar' + id), uint(1), Buffer.from('umdl'), uint(3),
    Buffer.from(model + '\0'), Buffer.alloc(4)]);
const fixture = Buffer.concat([uint(2), uint(0), uint(2), record('E012', 'old.mdx'), record('E011', 'other.mdx')]);
const changed = modelField(fixture);
assert(changed.found);
const records = parse(changed.output).tables[1];
assert.equal(records[0].fields[0].value, MODEL);
assert.deepEqual(records[1].bytes, parse(fixture).tables[1][1].bytes);
assert.deepEqual(modelField(changed.output).output, changed.output);
const oldImport = Buffer.concat([Buffer.from([29]), Buffer.from('HighPriestessSprite.mdx\0')]);
const imp = Buffer.concat([uint(1), uint(1), oldImport]), imported = imports(imp);
assert.equal(imported.readUInt32LE(4), ASSETS.size);
assert.deepEqual(imported.subarray(8, 8 + oldImport.length), oldImport);
assert.deepEqual(imports(imported), imported);
assert.throws(() => build(source.subarray(0, source.length - 1)));
console.log('PASS: reproducible trimmed sprite, Stand-only tracks, unshaded layers, compact bone/pivot IDs, shared rotation root, BLP textures, and isolated/idempotent unit/import updates.');
