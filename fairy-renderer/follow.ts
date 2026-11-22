// Browser values into Bend; no second smoothing layer.
import B from "../FAIRY_MOTION.bend";
export interface FollowState { x: number; y: number; attention: number; }
export const REST: FollowState = {x:0,y:0,attention:0};
export function pointerGaze(p:any, b:any, o={x:.5,y:.5}) {
  if (![p.x,p.y,b.left,b.top,b.width,b.height,o.x,o.y].every(Number.isFinite)) return {x:0,y:0};
  const {x,y}=B.pointer_gaze(p.x,p.y,b.left,b.top,b.width,b.height,o.x,o.y); return {x,y};
}
export function followStep(s:FollowState,t:{x:number,y:number}|null,dt:number,r:boolean) {
  const v=B.follow_step(s.x,s.y,s.attention,t?.x??0,t?.y??0,!!t,dt,r);
  const {x,y,attention}=v.state; return {state:{x,y,attention},moving:v.moving};
}
export function followGaze(s:FollowState) {
  const weight=B.smooth(s.attention); return weight>0 ? {x:s.x,y:s.y,weight} : undefined;
}
