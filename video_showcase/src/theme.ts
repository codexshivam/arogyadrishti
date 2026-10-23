import {spring, type SpringConfig} from 'remotion';
import {loadFont as loadPoppins} from '@remotion/google-fonts/Poppins';
import {loadFont as loadMono} from '@remotion/google-fonts/JetBrainsMono';

const poppinsRegular = loadPoppins('normal', {
  weights: ['400', '500', '600', '700', '800'],
  subsets: ['latin'],
});
const mono = loadMono('normal', {
  weights: ['400', '500', '700'],
  subsets: ['latin'],
});

export const FONT = {
  poppins: poppinsRegular.fontFamily,
  sans: poppinsRegular.fontFamily,
  mono: mono.fontFamily,
};

/**
 * Design tokens strictly adhering to user specifications:
 * - Plain full white background: #FFFFFF
 * - Large text: #A12C18
 * - Subtitle text: #BF5341
 * - Splash screen background: #EE211E
 */
export const C = {
  // Canvas & Surfaces (plain full white background)
  canvas: '#FFFFFF',
  surfaceWhite: '#FFFFFF',
  surfaceContainerLow: '#F8FAFC',
  surfaceContainer: '#F1F5F9',
  stone: '#ECEAE4',
  borderHairline: '#E2E8F0',
  inputBorder: '#CBD5E1',

  // User-specified editorial colors (NO black text!)
  textTitle: '#A12C18',
  textSubtitle: '#BF5341',
  splashBg: '#EE211E',

  // Primary Clinical Palette
  primaryCrimson: '#A12C18',
  primaryCrimsonDark: '#7C0012',
  primaryCrimsonActive: '#991B1B',

  // Text mappings to user's colors
  slateHeading: '#A12C18',
  slateBody: '#BF5341',
  slateMuted: '#BF5341',

  // Triage & Semantic Tokens
  triageRedBg: '#FEE2E2',
  triageRedText: '#991B1B',
  triageAmberBg: '#FEF3C7',
  triageAmberText: '#92400E',
  triageEmeraldBg: '#DCFCE7',
  triageEmeraldText: '#166534',
  aiChipBg: '#E0E7FF',
  aiChipText: '#4338CA',

  // Legacy mappings for app screen mockups
  ink: '#1E293B',
  crimson: '#A12C18',
  emerald: '#16A34A',
  blue: '#2563EB',
  amber: '#D97706',
  muted: '#64748B',
  faint: '#94A3B8',
  line: '#E2E8F0',
  card: '#FFFFFF',
  screen: '#F8FAFC',
  soft: '#F1F5F9',
};

export const FPS = 60;

/** Natural spring physics for smooth 60-second runtime. */
export const SPRING: Partial<SpringConfig> = {damping: 18, stiffness: 140, mass: 0.9};
/** Smooth critical damping for numbers and path drawing. */
export const SMOOTH: Partial<SpringConfig> = {damping: 120, stiffness: 45, mass: 1};

export const sp = (frame: number, start: number, config: Partial<SpringConfig> = SPRING) =>
  frame < start ? 0 : spring({frame: frame - start, fps: FPS, config});

export const smooth = (frame: number, start: number) => sp(frame, start, SMOOTH);

/** Live-ticking metric value. */
export const tick = (frame: number, start: number, from: number, to: number) =>
  from + (to - from) * smooth(frame, start);

/** Tactile press bump (0 → 1 → 0). */
export const press = (frame: number, start: number) => sp(frame, start) - sp(frame, start + 9);

export const clamp = (v: number, lo = 0, hi = 1) => Math.min(hi, Math.max(lo, v));
export const lerp = (a: number, b: number, t: number) => a + (b - a) * t;

/** Spring-driven entrance: fade + gentle rise. */
export const rise = (frame: number, start: number, dist = 20): React.CSSProperties => {
  const p = sp(frame, start);
  return {
    opacity: clamp(p * 1.3),
    transform: `translateY(${(1 - p) * dist}px)`,
  };
};
