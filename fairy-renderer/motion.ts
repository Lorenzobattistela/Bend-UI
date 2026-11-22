import A from "../FAIRY_ANIMATOR.bend";
import B from "../FAIRY_MOTION.bend";
/**
 * Deterministic pose model. A pose is a pure function of (seed, time, state,
 * mood, gaze, reducedMotion): no wall clock, no Math.random, so any frame can
 * be reproduced exactly (tests, SSR, scrubbing).
 */
import type { AvatarMood, AvatarMotion, AvatarMotionBlend, AvatarState } from './types.ts';

/**
 * How the eyes are drawn, as numbers that blend: any two looks mix into a shape in between, so
 * the eyes morph from one to the other (see eyes.ts).
 */
export interface EyeLook {
  /** 0 = the plain pill, 1 = the happy arc. */
  arc: number;
  /** 0 = the plain pill, 1 = the flat slit of a waiting bot. Never more than `1 - arc`. */
  slit: number;
}

export interface Pose {
  /** View rotation in radians: yaw turns about the vertical axis, pitch about the horizontal. */
  yaw: number;
  pitch: number;
  /** In-plane rotation, degrees. */
  roll: number;
  /** Vertical offset (negative = up), viewBox units. */
  lift: number;
  /** Squash and stretch about the base of the body. */
  sx: number;
  sy: number;
  /** Eye look direction, -1..1 per axis. */
  gazeX: number;
  gazeY: number;
  /** 0 = open, 1 = fully closed. */
  blink: number;
  /** Extra lid narrowing per eye, 0..1. */
  squintL: number;
  squintR: number;
  eyes: EyeLook;
  /** Presence of the ribbons that circle the body: 0..1 draws them out and back in. */
  ribbons: number;
  /** Which layout the ribbons take: 0 a working turn's one hoop, 1 a celebration's cage of three. */
  cage: number;
  /**
   * How far the body's turn has carried the ribbons round, radians, signed and not wrapped: each
   * ribbon goes its own share of it, so a whole turn more does not put them back where they were.
   */
  sweep: number;
  /** How far the body has given way to a mark, 0..1 each: the exclamation mark and the three dots. */
  bang: number;
  dots: number;
}

/** Every state and mood, in the order hosts list them. */
export const STATES: readonly AvatarState[] = ['idle', 'thinking', 'working', 'waiting', 'blocked', 'done'];
export const MOODS: readonly AvatarMood[] = ['neutral', 'happy'];

export function isState(value: unknown): value is AvatarState {
  return STATES.includes(value as AvatarState);
}

export function isMood(value: unknown): value is AvatarMood {
  return MOODS.includes(value as AvatarMood);
}

/**
 * The state and mood to show. `motion` is the single option that came before them: `thinking`
 * is a state, `happy` a mood. An explicit `state` or `mood` wins over it.
 */
export function resolveLook(given: { state?: unknown; mood?: unknown; motion?: unknown }): { state: AvatarState; mood: AvatarMood } {
  return {
    state: isState(given.state) ? given.state : given.motion === 'thinking' ? 'thinking' : 'idle',
    mood: isMood(given.mood) ? given.mood : given.motion === 'happy' ? 'happy' : 'neutral',
  };
}

export interface PoseInput {
  seed: number;
  time: number;
  state?: AvatarState;
  mood?: AvatarMood;
  /** @deprecated Use `state` and `mood`; they win when given. */
  motion?: AvatarMotion;
  /** Seconds since `state` began: `done` celebrates from then on. Without it the state is at rest. */
  stateAge?: number;
  /** Look target, -1..1 per axis (x right, y down); `weight` 0..1 fades it in over the idle pose (default 1). */
  gaze?: { x: number; y: number; weight?: number };
  reducedMotion: boolean;
  /** Extra view rotation in radians (e.g. from drag-to-turn), added to the resting view. */
  view?: { yaw: number; pitch: number };
  /** Easing in from what was shown before (see blendPoses). */
  blend?: AvatarMotionBlend;
}

export function hashString(s: string): number {
  let h = 2166136261;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}


export const BASE_YAW = B.base(0).yaw;
export const BASE_PITCH = B.base(0).pitch;
export const DONE_TURN_S = 3.87;
export const DONE_CYCLE_S = 6.2;
const clamp = (x: number, a: number, b: number) => Math.min(b, Math.max(a, x));
const unpack = ({$, arc, slit, ...pose}: any): Pose => ({...pose, eyes: {arc, slit}});
const pack = ({eyes, ...pose}: Pose) => ({$: 'Pose', ...pose, arc: eyes.arc, slit: eyes.slit});
export function blendPoses(a: Pose, b: Pose, t: number): Pose { return unpack(B.blend_pose(pack(a), pack(b), t)); }
function history(blend: any): any {
  if (!blend || !(blend.t < 1)) return {$:'none'};
  const from=typeof blend.from==='string' ? {motion:blend.from} : blend.from;
  const look=resolveLook(from);
  return {$:'before',state:STATES.indexOf(look.state),arc:look.mood==='happy'?1:0,
    age:Number.isFinite(from.age)?Math.max(0,from.age):look.state==='done'?DONE_TURN_S:0,
    t:from.blend && Number.isFinite(from.blend.t)?from.blend.t:1,from:history(from.blend)};
}
export function computePose(input: PoseInput): Pose {
  const {state,mood}=resolveLook(input), g=input.gaze, v=input.view;
  const valid=g && Number.isFinite(g.x) && Number.isFinite(g.y);
  const weight=valid ? (Number.isFinite(g.weight) ? clamp(g.weight!,0,1) : 1) : 0;
  const vv=v && Number.isFinite(v.yaw) && Number.isFinite(v.pitch);
  const age=Number.isFinite(input.stateAge) ? Math.max(0,input.stateAge!) : state==='done' ? DONE_TURN_S : Math.max(0,input.time);
  return unpack(A.pose(history(input.blend),input.seed,input.time,STATES.indexOf(state),mood==='happy'?1:0,age,
    input.blend && Number.isFinite(input.blend.t)?input.blend.t:1,
    valid?clamp(g.x,-1,1):0,valid?clamp(g.y,-1,1):0,weight,input.reducedMotion,vv?v.yaw:0,vv?v.pitch:0));
}

export const noise = (seed: number, n: number) => B.noise(seed, n);
