// Offline integrity checks for generated static scenery. No WC3 rendering claims.
const fs = require('fs'), path = require('path'), assert = require('assert');
const {readChunks,geosets,split,bounds} = require('./build_scarab_render_chunks');
const directory = process.argv[2];
assert(directory,'Usage: node test_scarab_render_chunks.js <import directory>');
function area(g) {
    let result = 0;
    for(let i=0;i<g.faces.length;i+=3) {
        const [a,b,c] = g.faces.slice(i,i+3).map(j=>g.vertices[j]);
        const u=b.slice(0,3).map((v,j)=>v-a[j]),v=c.slice(0,3).map((n,j)=>n-a[j]);
        result += Math.hypot(u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0])/2;
    }
    return result;
}
let count=0;
for(const name of ['a','b','c','D','f','g','h']) {
    const original = fs.readFileSync(path.join(directory,`Cave01_${name}.mdx`));
    const source = readChunks(original), sourceGeo = geosets(source.find(c=>c.tag==='GEOS').data);
    const pieces = split(original), generatedArea = sourceGeo.map(()=>0);
    for(let i=0;i<pieces.length;i++) {
        const p=pieces[i], target=fs.readFileSync(path.join(directory,'ScarabKit',`Cave01_${name}_${i}.mdx`));
        assert(target.equals(p.buffer),'Generated asset differs from source conversion');
        const output=readChunks(target), outputGeo=geosets(output.find(c=>c.tag==='GEOS').data);
        assert(outputGeo.length===sourceGeo.length,'Bone/geoset indexing changed');
        outputGeo.forEach((g,j)=>{
            assert(g.header.equals(sourceGeo[j].header),'Material/selection fields changed');
            assert(g.fields.MATS.equals(sourceGeo[j].fields.MATS),'Bone references changed');
            for(const v of g.vertices) {
                assert(v.every(Number.isFinite),'Non-finite output vertex/UV');
                assert(Math.abs(v[0])<=32.001 && Math.abs(v[1])<=32.001,'Chunk too large for local fog sampling');
            }
            generatedArea[j]+=area(g);
        });
        for(const tag of ['VERS','MTLS','TEXS','BONE']) {
            assert(output.find(c=>c.tag===tag).data.equals(source.find(c=>c.tag===tag).data),`Changed ${tag}`);
        }
        const ext=bounds(outputGeo.flatMap(g=>g.vertices));
        const model=output.find(c=>c.tag==='MODL').data;
        ext.forEach((n,j)=>assert(Math.abs(model.readFloatLE(340+j*4)-n)<.001,'Incorrect model extent'));
        count++;
    }
    sourceGeo.forEach((g,j)=>{
        const expected=area(g);
        assert(Math.abs(generatedArea[j]-expected)<Math.max(.02,expected*.00001),`Surface area lost/duplicated for ${name}:${j}`);
    });
}
console.log(`PASS: ${count} render chunks retain mesh surface area, materials, textures, bone indices, valid bounds and <=64-unit sections.`);
