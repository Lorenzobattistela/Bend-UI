// Regression checks against upstream numeric fixtures, and the approved spherical geometry.
import assert from 'node:assert/strict';
import {mkdtempSync,rmSync,readFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
const scratch=mkdtempSync(join(tmpdir(),'bend-ui-fairy-'));
try {
  let n=0;
  const compiled=await Bun.build({entrypoints:[join(import.meta.dir,'test/fairy-entry.ts')],outdir:scratch,target:'bun',plugins:[{name:'bend-check',setup(build){
    build.onLoad({filter:/\.bend$/},({path})=>{
      const dest=join(scratch,`bend-${n++}.mjs`);
      execFileSync('bend',[path,'-o',dest],{stdio:'pipe'});
      return {contents:readFileSync(dest,'utf8'),loader:'js'};
    });
  }}]});
  assert(compiled.success,compiled.logs.join('\n'));
  const N=await import(compiled.outputs[0].path);
  const fixtures=JSON.parse(readFileSync(new URL('./test/fairy-motion.json',import.meta.url),'utf8'));
  function compare(a,b,tolerance){
    for(const [key,value] of Object.entries(a)){
      if(typeof value==='number')assert(Math.abs(value-b[key])<tolerance,`${key}: ${value} vs ${b[key]}`);
      else if(value&&typeof value==='object')compare(value,b[key],tolerance);
      else assert.equal(value,b[key],key);
    }
  }
  for(const f of fixtures.poses)compare(f.expected,N.computePose(f.input),.001);
  const animator=N.createAnimator();
  for(const f of fixtures.trajectory)compare(f.expected,animator.step(f.input),.00002);
  animator.reset(); compare(fixtures.trajectory[0].expected,animator.step(fixtures.trajectory[0].input),.00002);
  const vol=N.preparedVolume(N.fairy).vol, core=vol.parts[0];
  assert.equal(vol.parts.length,15); assert.equal(vol.eyePart,0); assert.equal(core.depth,41);
  for(let x=30;x<=70;x+=.5)for(let y=32;y<=72;y+=.5){
    const expected=Math.sqrt(Math.max(0,20.5**2-(x-50)**2-(y-52)**2));
    if(expected>1)assert(Math.abs(core.height(x,y)-expected)<.00001,'Core must be a sphere');
  }
  for(const state of ['idle','thinking','working','waiting','blocked','done'])for(const yaw of [0,Math.PI/2,Math.PI])for(const pitch of [-.9,0,.9]){
    const frame=N.liveFrame(N.fairy,{state,stateAge:1.3,time:3.21,view:{yaw,pitch}});
    assert(frame.shapes.length>0); assert(!/NaN|Infinity/.test(JSON.stringify(frame)));
  }
  console.log(`FAIRY: ${fixtures.poses.length} reference poses, ${fixtures.trajectory.length} interrupted history steps, 54 rotated frames, spherical surface passed.`);
} finally { rmSync(scratch,{recursive:true,force:true}); }
