// Set the Colosseum Ticket's authored formula tier to Uncommon (2).
// Usage: node cotlua/tools/update_ticket_tier.js <editable-map-directory> [--check]
'use strict';
const fs = require('node:fs');
const path = require('node:path');
function transform(source) {
    const pattern = /(\/\/ Items: I008 [^\r\n]*, Ubertip \(Tooltip - Extended\)\r?\n\{\r?\n)([\s\S]*?)(\r?\n\})/g;
    const matches = [...source.matchAll(pattern)];
    if (matches.length !== 1) throw new Error('Expected exactly one Colosseum Ticket tooltip');
    return source.replace(pattern, (_, header, text, end) => {
        const newline = header.includes('\r\n') ? '\r\n' : '\n';
        const body = /\[tier\s+\d+\]/.test(text) ? text.replace(/\[tier\s+\d+\]/, '[tier 2]') : '[tier 2]' + newline + text;
        return header + body + end;
    });
}
if (require.main === module) {
    const directory = process.argv[2];
    if (!directory) throw new Error('Editable map directory is required');
    const file = path.join(directory, 'war3map.wts');
    const input = fs.readFileSync(file, 'utf8'), output = transform(input);
    if (process.argv.includes('--check')) {
        console.log(input === output ? 'Verified: Colosseum Ticket is tier 2 (Uncommon).' : 'Colosseum Ticket needs tier 2 (Uncommon).');
        if (input !== output) process.exitCode = 1;
    } else {
        if (input !== output) fs.writeFileSync(file, output, 'utf8');
        if (fs.readFileSync(file, 'utf8') !== output) throw new Error('Ticket tooltip write verification failed');
        console.log('Verified: Colosseum Ticket is tier 2 (Uncommon); other strings preserved.');
    }
}
module.exports = {transform};
