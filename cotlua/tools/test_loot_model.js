'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {repair, chunks} = require('./build_loot_model.js');
const model = fs.readFileSync(path.join(__dirname, '../assets/loot_bundle.mdx'));
assert.deepEqual(repair(model), model, 'Imported asset has incomplete animation bounds');
const parts = new Map(chunks(model).map(({tag, body}) => [tag, body]));
const sequence = parts.get('SEQS');
assert.equal(sequence.toString('ascii', 0, 5), 'Stand');
const bounds = Array.from({length: 7}, (_, i) => sequence.readFloatLE(104 + i * 4));
assert(bounds[0] > 100 && bounds[0] < 200, 'Model is not at its original world size');
const mesh = parts.get('GEOS'), count = mesh.readUInt32LE(8);
for (let vertex = 0; vertex < count; vertex++) for (let axis = 0; axis < 3; axis++) {
    const value = mesh.readFloatLE(12 + vertex * 12 + axis * 4);
    assert(value >= bounds[axis + 1] - .001 && value <= bounds[axis + 4] + .001,
        'Stand culling bounds exclude visible geometry');
}
assert.equal(parts.get('MTLS').readFloatLE(44), 1, 'Treasure material must be opaque');
assert.throws(() => repair(Buffer.from('invalid model')));
assert.throws(() => repair(model.subarray(0, model.length - 1)));
console.log('PASS: real loot MDX has opaque material, original world dimensions, Stand bounds containing all vertices, complete animation extents, and idempotent repair.');
