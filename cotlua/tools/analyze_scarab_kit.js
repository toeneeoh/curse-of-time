// Read-only MDX floor inspection. Usage: node analyze_scarab_kit.js <import directory>
const fs = require('fs');
const path = require('path');
const result = {};
for (const name of ['a', 'b', 'c', 'D', 'f', 'g', 'h']) {
    const b = fs.readFileSync(path.join(process.argv[2], `Cave01_${name}.mdx`));
    const triangles = [], bounds = [Infinity, Infinity, -Infinity, -Infinity];
    for (let o = 4; o + 8 <= b.length;) {
        const tag = b.toString('ascii', o, o + 4), length = b.readUInt32LE(o + 4);
        if (tag === 'GEOS') for (let q = o + 8; q < o + 8 + length;) {
            let r = q + 4, vertices, indices;
            for (const field of ['VRTX', 'NRMS', 'PTYP', 'PCNT', 'PVTX', 'GNDX', 'MTGC', 'MATS']) {
                if (b.toString('ascii', r, r + 4) !== field) throw Error(`Unexpected ${field}`);
                const count = b.readUInt32LE(r + 4);
                const stride = ['VRTX', 'NRMS'].includes(field) ? 12 : field === 'PVTX' ? 2 : field === 'GNDX' ? 1 : 4;
                if (field === 'VRTX') vertices = Array.from({length: count}, (_, i) => [b.readFloatLE(r + 8 + i * 12), b.readFloatLE(r + 12 + i * 12)]);
                if (field === 'PVTX') indices = Array.from({length: count}, (_, i) => b.readUInt16LE(r + 8 + i * 2));
                r += 8 + count * stride;
            }
            for (const [x, y] of vertices) {
                bounds[0] = Math.min(bounds[0], x); bounds[1] = Math.min(bounds[1], y);
                bounds[2] = Math.max(bounds[2], x); bounds[3] = Math.max(bounds[3], y);
            }
            if (b.readUInt32LE(r) === 2) for (let i = 0; i < indices.length; i += 3) {
                triangles.push(indices.slice(i, i + 3).flatMap(index => vertices[index]).map(value => Math.round(value * 1000) / 1000));
            }
            q += b.readUInt32LE(q);
        }
        o += 8 + length;
    }
    result[name] = {bounds, triangles};
}
process.stdout.write(JSON.stringify(result));
