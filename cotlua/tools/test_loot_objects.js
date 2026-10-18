'use strict';
const assert = require('node:assert/strict');
const {transform, specs, registerImport, setBuildingFlags} = require('./update_loot_objects.js');
const int = n => {const b = Buffer.alloc(4); b.writeInt32LE(n); return b;};
function record(version, base, id, text) {
    return Buffer.concat([Buffer.from(base + id), ...(version >= 3 ? [int(1), int(0)] : []), int(1),
        Buffer.from('unam'), int(3), Buffer.from(text + '\0'), Buffer.alloc(4)]);
}
for (const version of [1, 2, 3]) for (const spec of Object.values(specs)) {
    const original = record(version, 'gold', '\0\0\0\0', 'Original untouched'),
        custom = record(version, 'gold', 'Z999', 'Custom untouched');
    const input = Buffer.concat([int(version), int(1), original, int(1), custom]);
    const output = transform(input, spec);
    assert(output.includes(original) && output.includes(custom), 'Unrelated object record changed');
    assert.deepEqual(transform(output, spec), output, 'Repeated apply changed data');
    const collision = Buffer.concat([int(version), int(0), int(1), record(version, 'xxxx', spec.id, 'collision')]);
    assert.throws(() => transform(collision, spec), /collision/);
    assert.throws(() => transform(input.subarray(0, input.length - 1), spec));
}
const proxy = new Map(specs.w3t.fields.map(([field, type, value]) => [field, {type, value}]));
assert.equal(proxy.get('iabi').value, '');
assert.equal(proxy.get('ipow').value, 1);
assert.equal(proxy.get('iper').value, 1);
assert.equal(proxy.get('iuse').value, 1);
const unit = new Map(specs.w3u.fields.map(([field, type, value]) => [field, {type, value}]));
assert.equal(unit.get('uabi').value, 'Avul');
assert.equal(unit.get('uaen').value, 0);
assert.equal(unit.get('ucol').value, 0);
assert.equal(unit.get('ubdg').value, 1);
assert.equal(unit.get('utyp').value, 'neutral');
assert.equal(unit.get('upat').value, '');
assert.equal(unit.get('umdl').value, 'loot_bundle.mdx');
assert.equal(unit.get('ussc').value, .7);
const imports = Buffer.concat([int(1), int(1), Buffer.from([13]), Buffer.from('existing.mdx\0')]);
const registered = registerImport(imports, 'loot_bundle.mdx');
assert.equal(registered.readUInt32LE(4), 2);
assert(registered.subarray(8).includes(imports.subarray(8)));
assert.deepEqual(registerImport(registered, 'loot_bundle.mdx'), registered);
for (const version of [1, 2, 3]) {
    const unrelated = record(version, 'ngme', 'Z999', 'Unrelated object');
    const general = record(version, 'ngme', 'n01A', 'General visual fields');
    const magic = record(version, 'ngme', 'n01B', 'Magic visual fields');
    // Cover both adding a missing flag (skin objects) and replacing a false
    // one (gameplay objects), while retaining the other modifications exactly.
    const flag = Buffer.concat([Buffer.from('ubdg'), int(0), int(0), Buffer.alloc(4)]);
    const countOffset = version >= 3 ? 16 : 8;
    const generalWithFlag = Buffer.concat([general, flag]);
    generalWithFlag.writeInt32LE(2, countOffset);
    const input = Buffer.concat([int(version), int(0), int(3), unrelated, generalWithFlag, magic]);
    const output = setBuildingFlags(input);
    assert(output.includes(unrelated));
    assert(output.includes(general.subarray(countOffset + 4)) && output.includes(magic.subarray(countOffset + 4)));
    assert.deepEqual(setBuildingFlags(output), output);
    const enabledFlag = Buffer.concat([Buffer.from('ubdg'), int(0), int(1), Buffer.alloc(4)]);
    const first = output.indexOf(enabledFlag);
    assert(first >= 0 && output.indexOf(enabledFlag, first + enabledFlag.length) >= 0);
    assert.throws(() => setBuildingFlags(input, ['missing']), /Missing merchant/);
}
console.log('PASS: v1/v2/v3 item/unit data preservation, idempotence, collision/truncation rejection, harmless powerup fields and selectable noncombat bundle configuration.');
