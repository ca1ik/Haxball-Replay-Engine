process.stdout.write = () => {};  // silence all stdout
process.stderr.write = () => {};  // silence all stderr
const {Replay,EventFactory}=require('node-haxball')({performance:require('perf_hooks').performance,pako:require('pako')});
const fs=require('fs');
process.stdout.write = process.stdout.write.bind(process.stdout);  // restore
const r1=Replay.readAll(new Uint8Array(fs.readFileSync('12-05-26-20h41-VeronevsEmman64 (1).hbr2')));
const r2=Replay.readAll(new Uint8Array(fs.readFileSync('12-05-26-20h28-Emman64vsVerone (1).hbr2')));
const OFFSET=r1.totalFrames+1;
const few=r2.events.slice(0,5).map(e=>Object.assign({},e,{frameNo:e.frameNo+OFFSET}));
r1.events=[...r1.events,...few];
r1.totalFrames=r1.totalFrames+1+r2.totalFrames;
const out=Replay.writeAll(r1);
const r3=Replay.readAll(new Uint8Array(out));
const results={eventsLen:r3.events.length,totalFrames:r3.totalFrames,last10:r3.events.slice(-10).map(e=>({f:e.frameNo,type:e.eventType,X:e.X}))};
fs.writeFileSync('test_result.json',JSON.stringify(results,null,2));
