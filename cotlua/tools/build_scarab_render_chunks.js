// Generated scenery assets, not object-editor data. Original models are untouched.
// node build_scarab_render_chunks.js <map/import directory> <catalog lua> <D00H source MDX>
const fs = require('fs'), path = require('path');
const [directory, catalogFile, blockerFile] = process.argv.slice(2);
const size = 64, output = path.join(directory, 'ScarabKit');
function u32(n) { const b = Buffer.alloc(4); b.writeUInt32LE(n); return b; }
function floats(values) { const b = Buffer.alloc(values.length*4); values.forEach((v,i)=>b.writeFloatLE(v,i*4)); return b; }
function chunk(tag,b) { return Buffer.concat([Buffer.from(tag),u32(b.length),b]); }
function array(tag,values,type) {
    const b = Buffer.alloc(values.length*(type==='float'?4:type==='short'?2:type==='byte'?1:4));
    values.forEach((v,i)=>type==='float'?b.writeFloatLE(v,i*4):type==='short'?b.writeUInt16LE(v,i*2):type==='byte'?b.writeUInt8(v,i):b.writeUInt32LE(v,i*4));
    return Buffer.concat([Buffer.from(tag),u32(values.length/(tag==='VRTX'||tag==='NRMS'?3:tag==='UVBS'?2:1)),b]);
}
function readChunks(buffer) {
    if(buffer.toString('ascii',0,4)!=='MDLX') throw Error('Not MDX');
    const result=[];
    for(let o=4;o<buffer.length;) {
        const tag=buffer.toString('ascii',o,o+4),n=buffer.readUInt32LE(o+4);
        result.push({tag,data:buffer.subarray(o+8,o+8+n)}); o+=8+n;
    }
    return result;
}
function geosets(data) {
    const result=[];
    for(let o=0;o<data.length;) {
        const n=data.readUInt32LE(o), end=o+n; let r=o+4;
        const fields={};
        for(const tag of ['VRTX','NRMS','PTYP','PCNT','PVTX','GNDX','MTGC','MATS']) {
            if(data.toString('ascii',r,r+4)!==tag) throw Error('Unexpected '+tag);
            const count=data.readUInt32LE(r+4), stride=tag==='VRTX'||tag==='NRMS'?12:tag==='PVTX'?2:tag==='GNDX'?1:4;
            fields[tag]=data.subarray(r,r+8+count*stride); r+=8+count*stride;
        }
        if([...fields.GNDX.subarray(8)].some(v=>v!==0)||fields.MTGC.readUInt32LE(4)!==1) throw Error('Only static single-group geometry supported');
        const header=Buffer.from(data.subarray(r,r+12));
        const animationCount=data.readUInt32LE(r+40); r+=44+animationCount*28;
        if(data.toString('ascii',r,r+4)!=='UVAS') throw Error('Missing UVAS');
        const uvCount=data.readUInt32LE(r+4); r+=8;
        if(uvCount!==1||data.toString('ascii',r,r+4)!=='UVBS') throw Error('Only single-UV geometry supported');
        const vertexCount=fields.VRTX.readUInt32LE(4);
        if(data.readUInt32LE(r+4)!==vertexCount) throw Error('UV count mismatch');
        const vertices=Array.from({length:vertexCount},(_,i)=>[
            ...Array.from({length:3},(_,j)=>fields.VRTX.readFloatLE(8+i*12+j*4)),
            ...Array.from({length:3},(_,j)=>fields.NRMS.readFloatLE(8+i*12+j*4)),
            data.readFloatLE(r+8+i*8),data.readFloatLE(r+12+i*8)]);
        const faces=Array.from({length:fields.PVTX.readUInt32LE(4)},(_,i)=>fields.PVTX.readUInt16LE(8+i*2));
        if(r+8+vertexCount*8!==end) throw Error('Unexpected geoset tail');
        result.push({fields,header,animationCount,vertices,faces}); o=end;
    }
    return result;
}
function bounds(vertices) {
    const min=[Infinity,Infinity,Infinity],max=[-Infinity,-Infinity,-Infinity];
    for(const v of vertices) for(let i=0;i<3;i++) {min[i]=Math.min(min[i],v[i]);max[i]=Math.max(max[i],v[i]);}
    const radius=Math.max(...vertices.map(v=>Math.hypot(...v.slice(0,3))));
    return [radius,...min,...max];
}
function clip(poly,axis,limit,lower) {
    const result=[];
    for(let i=0;i<poly.length;i++) {
        const a=poly[i],b=poly[(i+1)%poly.length],inside=lower?a[axis]>=limit:a[axis]<=limit,next=lower?b[axis]>=limit:b[axis]<=limit;
        if(inside) result.push(a);
        if(inside!==next) {const t=(limit-a[axis])/(b[axis]-a[axis]); result.push(a.map((v,j)=>v+t*(b[j]-v)));}
    }
    return result;
}
function serializeGeo(source,vertices) {
    const ext=floats(bounds(vertices)),indices=vertices.map((_,i)=>i);
    const body=Buffer.concat([
        array('VRTX',vertices.flatMap(v=>v.slice(0,3)),'float'),
        array('NRMS',vertices.flatMap(v=>{const n=Math.hypot(...v.slice(3,6));return v.slice(3,6).map(x=>n?x/n:x);}),'float'),
        array('PTYP',[4],'int'),array('PCNT',[indices.length],'int'),array('PVTX',indices,'short'),
        array('GNDX',vertices.map(()=>0),'byte'),source.fields.MTGC,source.fields.MATS,source.header,ext,
        u32(source.animationCount),...Array.from({length:source.animationCount},()=>ext),
        Buffer.from('UVAS'),u32(1),array('UVBS',vertices.flatMap(v=>v.slice(6,8)),'float')]);
    return Buffer.concat([u32(body.length+4),body]);
}
function split(buffer) {
    const original=readChunks(buffer), geo=geosets(original.find(c=>c.tag==='GEOS').data), cells=new Map();
    // Bone animations would need proper rebasing rather than the static translation here.
    const bones=original.find(c=>c.tag==='BONE').data;
    for(let o=0;o<bones.length;) {if(bones.readUInt32LE(o)!==96) throw Error('Animated bone not supported'); o+=104;}
    for(let gi=0;gi<geo.length;gi++) {
        const g=geo[gi];
        for(let i=0;i<g.faces.length;i+=3) {
            const tri=g.faces.slice(i,i+3).map(j=>g.vertices[j]);
            const minx=Math.floor(Math.min(...tri.map(v=>v[0]))/size),maxx=Math.floor(Math.max(...tri.map(v=>v[0]))/size);
            const miny=Math.floor(Math.min(...tri.map(v=>v[1]))/size),maxy=Math.floor(Math.max(...tri.map(v=>v[1]))/size);
            for(let x=minx;x<=maxx;x++) for(let y=miny;y<=maxy;y++) {
                let poly=tri;
                for(const [axis,limit,lower] of [[0,x*size,true],[0,(x+1)*size,false],[1,y*size,true],[1,(y+1)*size,false]]) poly=clip(poly,axis,limit,lower);
                if(poly.length<3) continue;
                const key=x+':'+y;
                if(!cells.has(key)) cells.set(key,{x:(x+.5)*size,y:(y+.5)*size,parts:geo.map(()=>[])});
                const cell=cells.get(key);
                for(let j=1;j<poly.length-1;j++) {
                    const a=poly[0],b=poly[j],c=poly[j+1];
                    const cross=[(b[1]-a[1])*(c[2]-a[2])-(b[2]-a[2])*(c[1]-a[1]),(b[2]-a[2])*(c[0]-a[0])-(b[0]-a[0])*(c[2]-a[2]),(b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])];
                    if(Math.hypot(...cross)<.0001) continue;
                    for(const v of [a,b,c]) cell.parts[gi].push([v[0]-cell.x,v[1]-cell.y,...v.slice(2)]);
                }
            }
        }
    }
    const results=[];
    for(const cell of cells.values()) {
        const vertices=cell.parts.flat(); if(!vertices.length) continue;
        const ext=bounds(vertices);
        const encoded=original.map(c=>{
            let data=Buffer.from(c.data);
            // Retain geoset indices for the existing bone references. Empty
            // geosets get a zero-area triangle at a real vertex, not the origin
            // (which could otherwise expand this chunk's measured extents).
            if(c.tag==='GEOS') data=Buffer.concat(cell.parts.map((v,i)=>serializeGeo(geo[i],v.length?v:[vertices[0],vertices[0],vertices[0]])));
            if(c.tag==='MODL') floats(ext).copy(data,340);
            if(c.tag==='SEQS') for(let i=0;i<data.length;i+=132) floats(ext).copy(data,i+104);
            if(c.tag==='PIVT') for(let i=0;i<data.length;i+=12) {data.writeFloatLE(data.readFloatLE(i)-cell.x,i);data.writeFloatLE(data.readFloatLE(i+4)-cell.y,i+4);}
            return chunk(c.tag,data);
        });
        results.push({x:cell.x,y:cell.y,bounds:[ext[1],ext[2],ext[4],ext[5]],buffer:Buffer.concat([Buffer.from('MDLX'),...encoded])});
    }
    return results;
}
module.exports = {readChunks,geosets,bounds,split};
if (require.main === module) {
fs.mkdirSync(output,{recursive:true});
const catalog={};
for(const name of ['a','b','c','D','f','g','h']) {
    const source=fs.readFileSync(path.join(directory,'Cave01_'+name+'.mdx'));
    const pieces=split(source); catalog[name]=[];
    pieces.forEach((piece,i)=>{
        const file=`Cave01_${name}_${i}.mdx`; fs.writeFileSync(path.join(output,file),piece.buffer);
        catalog[name].push({file,x:piece.x,y:piece.y,bounds:piece.bounds});
    });
}
// D00H is City_LowWall_ShortEndCap tinted RGB 0/0/0, with no editor pathing.
const blocker=readChunks(fs.readFileSync(blockerFile));
const blockBounds=bounds(geosets(blocker.find(c=>c.tag==='GEOS').data).flatMap(g=>g.vertices));
let lua="-- Generated by tools/build_scarab_render_chunks.js; original meshes remain unchanged.\nOnInit.global('ScarabKitRenderAssets', function()\n    ScarabKitRenderAssets = {\n";
for(const [name,parts]of Object.entries(catalog)) {
    lua+=`        ${name} = {\n`;
    for(const p of parts) lua+=`            {file = '${p.file}', x = ${p.x}, y = ${p.y}, bounds = {${p.bounds.map(v=>Number(v.toFixed(5))).join(',')}}},\n`;
    lua+='        },\n';
}
lua+=`        blocker = {model = 'Doodads\\\\Cityscape\\\\Structures\\\\City_LowWall_ShortEndCap\\\\City_LowWall_ShortEndCap.mdl', bounds = {${blockBounds.slice(1).map(v=>Number(v.toFixed(5))).join(',')}}},\n    }\nend)\n`;
fs.writeFileSync(catalogFile,lua);
console.log(JSON.stringify({chunks:Object.fromEntries(Object.entries(catalog).map(([name,p])=>[name,p.length])),blockerBounds:blockBounds}));
}
