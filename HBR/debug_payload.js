const fs = require('fs');
const zlib = require('zlib');
const raw = fs.readFileSync("12-05-26-20h28-Emman64vsVerone (1).hbr2");
const p = zlib.inflateRawSync(raw.slice(12));
console.log("first 50 bytes:", p.slice(0, 50).toString('hex'));
// uint16 LE at various positions
for(let i=0;i<10;i++) console.log(`uint16LE[${i}]:`, p.readUInt16LE(i), `uint16BE[${i}]:`, p.readUInt16BE(i));
