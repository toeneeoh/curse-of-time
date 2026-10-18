'use strict';
const assert = require('node:assert/strict');
const {parse, transform, TARGETS} = require('./update_npc_hover.js');
const int = n => {const b = Buffer.alloc(4); b.writeInt32LE(n); return b;};
function mod(field, value, endToken = 'END!') {
    const type = typeof value === 'string' ? 3 : 0;
    return Buffer.concat([Buffer.from(field), int(type), type === 3 ? Buffer.from(value + '\0') : int(value), Buffer.from(endToken)]);
}
function record(version, base, id, fields) {
    return Buffer.concat([Buffer.from(base + id), ...(version === 3 ? [int(2), int(123), int(456)] : []),
        int(fields.length), ...fields]);
}
function fixture(version, classes) {
    const fields = [mod('unam', 'Editor name'), mod('umdl', 'UserChosenModel.mdl'), mod('ussc', 7)];
    if (classes !== undefined) fields.push(mod('utyp', classes));
    if (classes === 'mechanical') fields.push(mod('ubdg', 0));
    return Buffer.concat([int(version), int(0), int(7), record(version, 'hfoo', 'h059', fields),
        record(version, 'nshe', 'nLTP', [mod('umdl', 'NativeTreasurePile0.mdl'), mod('ushh', 120)]),
        ...['h036', 'h03A', 'h009'].map(id => record(version, 'hfoo', id, [mod('unam', id + ' NPC')])),
        record(version, 'ngme', 'n01A', [mod('utyp', 'neutral'), mod('unam', 'Unchanged vendor')]),
        record(version, 'ewsp', 'e000', [mod('utyp', '_'), mod('unam', 'Shared Chaos Knight')])]);
}
for (const version of [1, 2, 3]) for (const classes of [undefined, '', '-', 'mechanical', 'mechanical,neutral']) {
    const input = fixture(version, classes), output = transform(input);
    const before = parse(input).tables.flat(), after = parse(output).tables.flat();
    assert.equal(after.length, before.length);
    for (let index = 0; index < before.length; index++) {
        const a = before[index], b = after[index];
        assert.equal(a.id, b.id); assert.equal(a.base, b.base); assert.deepEqual(a.header, b.header);
        const unchanged = f => f.field !== 'utyp' && f.field !== 'ubdg';
        assert.deepEqual(a.fields.filter(unchanged).map(f => f.bytes),
            b.fields.filter(unchanged).map(f => f.bytes), 'Artwork or unrelated field changed');
        if (!TARGETS.includes(a.id)) assert.deepEqual(b.bytes, a.bytes);
        else {
            const field = b.fields.find(f => f.field === 'utyp');
            assert(field.value.split(',').includes('neutral'));
            assert.equal(b.fields.find(f => f.field === 'ubdg').value, 1);
            if (a.id === 'h059' && classes?.includes('mechanical')) assert(field.value.includes('mechanical'));
            const original = a.fields.find(f => f.field === 'utyp');
            if (original) assert.deepEqual(field.endToken, original.endToken);
        }
    }
    assert.deepEqual(transform(output), output, 'Repeated apply must be byte-idempotent');
    const skin = transform(input, false), skinRecords = parse(skin).tables.flat();
    assert(!skinRecords[1].fields.some(f => f.field === 'utyp'), 'Added gameplay field to artwork-only skin');
    if (classes === undefined) assert.deepEqual(skin, input);
    else assert(skinRecords[0].fields.find(f => f.field === 'utyp').value.includes('neutral'));
    if (classes === 'mechanical') assert.equal(skinRecords[0].fields.find(f => f.field === 'ubdg').value, 1);
    assert.throws(() => transform(input.subarray(0, input.length - 1)));
}
assert.deepEqual(TARGETS, ['h059', 'nLTP', 'h036', 'h03A', 'h009']);
assert.throws(() => transform(Buffer.concat([int(3), int(0), int(0)])), /Missing target/);
assert.throws(() => transform(Buffer.concat([int(4), int(0), int(0)])), /Unsupported/);
console.log('PASS: v1/v2/v3 NPC building/Neutral flags, existing tags/artwork preservation, untouched vendors/shared Chaos Knight/skin-only records, idempotence, and invalid-input rejection.');
