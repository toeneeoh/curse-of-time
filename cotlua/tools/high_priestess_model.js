// Restore the supplied model's accidentally miniaturized team-color hero glow.
// Its three glow quads were divided by 100; their authored bounds were not.
'use strict';
const {chunks} = require('./build_loot_model');
function gameplayModel(input) {
    const parts = chunks(input), byTag = new Map(parts.map(c => [c.tag, c.body]));
    if (byTag.get('VERS')?.readUInt32LE(0) !== 800) throw new Error('Expected classic High Priestess model');
    const textures = byTag.get('TEXS'), glowTextures = new Set();
    for (let p = 0; p < textures.length; p += 268) {
        if (textures.readUInt32LE(p) === 2) glowTextures.add(p / 268);
    }
    const materials = byTag.get('MTLS'), glowMaterials = new Set();
    for (let p = 0, index = 0; p < materials.length; index++) {
        const end = p + materials.readUInt32LE(p);
        for (let q = p + 20; q < end;) {
            if (glowTextures.has(materials.readUInt32LE(q + 12))) glowMaterials.add(index);
            q += materials.readUInt32LE(q);
        }
        p = end;
    }
    let found = 0;
    const output = [Buffer.from('MDLX')];
    for (const {tag, body} of parts) {
        const edited = Buffer.from(body);
        if (tag === 'GEOS') for (let p = 0; p < body.length;) {
            const end = p + body.readUInt32LE(p); let q = p + 4;
            if (body.toString('ascii', q, q + 4) !== 'VRTX') throw new Error('Invalid mesh vertices');
            const count = body.readUInt32LE(q + 4), vertices = q + 8;
            for (const [name, stride] of [['VRTX', 12], ['NRMS', 12], ['PTYP', 4], ['PCNT', 4],
                ['PVTX', 2], ['GNDX', 1], ['MTGC', 4], ['MATS', 4]]) {
                if (body.toString('ascii', q, q + 4) !== name) throw new Error('Unsupported mesh');
                q += 8 + body.readUInt32LE(q + 4) * stride;
            }
            if (glowMaterials.has(body.readUInt32LE(q))) {
                found++;
                if (count !== 12) throw new Error('Expected the original three glow quads');
                const minimum = [Infinity, Infinity, Infinity], maximum = [-Infinity, -Infinity, -Infinity];
                for (let i = 0; i < count; i++) for (let axis = 0; axis < 3; axis++) {
                    const value = body.readFloatLE(vertices + i * 12 + axis * 4);
                    minimum[axis] = Math.min(minimum[axis], value); maximum[axis] = Math.max(maximum[axis], value);
                }
                const matchesBounds = scale => [minimum, maximum].every((values, bound) =>
                    values.every((value, axis) => Math.abs(value * scale - body.readFloatLE(q + 16 + bound * 12 + axis * 4)) < .01));
                if (!matchesBounds(1)) {
                    if (!matchesBounds(100)) throw new Error('Unexpected hero glow size; refusing to rescale');
                    for (let i = 0; i < count * 3; i++) {
                        edited.writeFloatLE(body.readFloatLE(vertices + i * 4) * 100, vertices + i * 4);
                    }
                }
            }
            p = end;
        }
        const header = Buffer.alloc(8); header.write(tag); header.writeUInt32LE(edited.length, 4);
        output.push(header, edited);
    }
    if (found !== 1) throw new Error('Expected one team-color hero-glow mesh');
    return Buffer.concat(output);
}
module.exports = {gameplayModel};
