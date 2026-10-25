/**
 * AppShowcaseSequence.tsx
 * 60-second programmatic motion showcase for NidanIQ.
 *
 * Updates:
 * - Simple pure white screen in the beginning (frames 0–45)
 * - Plain full white background (#FFFFFF) with zero background lines/ropes
 * - Large headline titles in #A12C18, subtitle copy in #BF5341 (no black text on canvas)
 * - Clean Auth screen without clutter (no logo/staff portal/Chandigarh/DPDP badges)
 * - End screen strictly matching Android app splash screen (#EE211E full red background with white logo text centered)
 */
import React from 'react';
import {AbsoluteFill, Audio, Img, useCurrentFrame} from 'remotion';
import T from './timeline.json';
import soundtrack from './Soundtrack.wav';
import splashLogoPng from './splash_logo_4k.png';
import {C, FONT, SPRING, clamp, lerp, sp} from './theme';
import {
  AuthScreen,
  BottomNav,
  CentersVansScreen,
  HomeScreen,
  MapScreen,
  NAV_H,
  SH,
  SW,
  ScanScreen,
  StatsScreen,
  StatusBar,
  SupportScreen,
  THUMB,
  THUMB_K,
} from './VectorScreenMockup';

const TR = T.T;
const PHONE_W = SW + 20;
const PHONE_H = SH + 20;

/* ------------------------------------------------------------------ */
/* Camera: phone glides across canvas on composed spring paths         */
/* ------------------------------------------------------------------ */

type Key = {f: number; x: number; y: number; s: number; rot?: number};
const focusY = (localY: number, s: number) => 540 + (PHONE_H / 2 - localY) * s;
const LEFT_X = 580;
const RIGHT_X = 1340;

const KEYS: Key[] = [
  {f: 0, x: 960, y: focusY(300, 1.65), s: 1.65, rot: 0},
  {f: 45, x: 960, y: focusY(300, 1.65), s: 1.65, rot: 0},
  {f: T.auth.tapSend, x: 960, y: focusY(450, 1.65), s: 1.65, rot: 0},
  {f: T.auth.zoomOut, x: RIGHT_X, y: 540, s: 1.0, rot: 0},
  {f: TR.authToHome, x: RIGHT_X, y: 540, s: 1.0, rot: 0},
  {f: TR.homeToScan, x: LEFT_X, y: 540, s: 1.0, rot: -1.5},
  {f: TR.scanToMap, x: LEFT_X, y: 540, s: 1.03, rot: 0},
  {f: TR.mapToStats, x: RIGHT_X, y: 540, s: 1.0, rot: 1.5},
  {f: TR.statsToCenters, x: LEFT_X, y: 540, s: 1.0, rot: 0},
  {f: TR.centersToSupport, x: RIGHT_X, y: 540, s: 1.0, rot: 0},
  {f: TR.outro, x: 960, y: 540, s: 0.5, rot: 0},
  {f: TR.outro + 40, x: 960, y: 540, s: 0.2, rot: 0},
];

const camera = (frame: number) => {
  let {x, y, s, rot = 0} = KEYS[0];
  for (let i = 1; i < KEYS.length; i++) {
    const p = sp(frame, KEYS[i].f, SPRING);
    x += (KEYS[i].x - KEYS[i - 1].x) * p;
    y += (KEYS[i].y - KEYS[i - 1].y) * p;
    s += (KEYS[i].s - KEYS[i - 1].s) * p;
    rot += ((KEYS[i].rot || 0) - (KEYS[i - 1].rot || 0)) * p;
  }
  return {x, y, s, rot};
};

/* ------------------------------------------------------------------ */
/* Phone Screens with Diverse Spatial Transitions                     */
/* ------------------------------------------------------------------ */

const layer = (style: React.CSSProperties): React.CSSProperties => ({
  position: 'absolute',
  left: 0,
  top: 0,
  width: SW,
  height: SH,
  ...style,
});

const PhoneScreens: React.FC<{f: number}> = ({f}) => {
  // Diverse transitions between screens:
  // 1. Auth -> Home: Upward lift & slide
  const p1 = sp(f, TR.authToHome);
  // 2. Home -> Scan: Diagonal slide with scale pulse
  const p2 = sp(f, TR.homeToScan);
  // 3. Scan -> Map: Focal zoom into map thumbnail
  const p3 = sp(f, TR.scanToMap);
  // 4. Map -> Stats: 3D perspective flip
  const p4 = sp(f, TR.mapToStats);
  // 5. Stats -> Centers: Downward vertical slide
  const p5 = sp(f, TR.statsToCenters);
  // 6. Centers -> Support: Split-expand scale-in
  const p6 = sp(f, TR.centersToSupport);

  // Scan -> Map focal expansion
  const z = clamp(p3, 0, 1.05);
  const k = lerp(THUMB_K, 1, z);
  const thumbCY = THUMB.y + THUMB.h / 2;
  const ty = (thumbCY - SH / 2) * (1 - z);
  const insetV = Math.max(0, ((SH - THUMB.h / THUMB_K) / 2) * (1 - z));
  const radius = (THUMB.r / THUMB_K) * (1 - clamp(z));

  // Map -> Stats 3D Flip
  const flipA = clamp(p4 * 2);
  const flipB = (p4 - 0.5) * 2;
  const dip = 1 - 0.08 * Math.sin(Math.PI * clamp(p4));

  return (
    <div style={{position: 'absolute', inset: 0, perspective: 1600, background: C.screen}}>
      {/* 1. Auth Screen */}
      {f < TR.authToHome + 60 && (
        <div
          style={layer({
            transform: `translateY(${-p1 * SH}px) scale(${1 - 0.08 * p1})`,
            opacity: 1 - 0.6 * clamp(p1),
          })}
        >
          <AuthScreen f={f} />
        </div>
      )}

      {/* 2. Home Dashboard (Enters upward, exits diagonally) */}
      {f >= TR.authToHome && f < TR.homeToScan + 60 && (
        <div
          style={layer({
            transform: `translateY(${(1 - p1) * SH - p2 * 140}px) translateX(${-p2 * SW}px) rotate(${-p2 * 2}deg)`,
          })}
        >
          <HomeScreen f={f} />
        </div>
      )}

      {/* 3. AI Scan (Enters diagonally from top-right) */}
      {f >= TR.homeToScan && f < TR.scanToMap + 80 && (
        <div
          style={layer({
            transform: `translateX(${(1 - p2) * SW}px) translateY(${(1 - p2) * 120}px) scale(${1 + 0.03 * clamp(p3)})`,
          })}
        >
          <ScanScreen f={f} />
          <div style={layer({background: C.ink, opacity: 0.35 * clamp(p3)})} />
        </div>
      )}

      {/* 4. GIS Map (Thumbnail zoom-in -> 3D flip exit) */}
      {f >= TR.scanToMap && p4 < 0.5 && (
        <div
          style={layer({
            transform: `translateY(${ty}px) scale(${k * dip}) rotateY(${-90 * flipA}deg)`,
            clipPath: `inset(${insetV}px 0px ${insetV}px 0px round ${radius}px)`,
            backfaceVisibility: 'hidden',
          })}
        >
          <MapScreen f={f} chrome={clamp((z - 0.6) / 0.4)} />
        </div>
      )}

      {/* 5. Stats Bento Grid (3D flip entrance -> Downward vertical exit) */}
      {f >= TR.mapToStats && p4 >= 0.5 && f < TR.statsToCenters + 60 && (
        <div
          style={layer({
            transform: `translateY(${p5 * SH}px) scale(${dip}) rotateY(${90 * (1 - flipB)}deg)`,
            backfaceVisibility: 'hidden',
          })}
        >
          <StatsScreen f={f} />
        </div>
      )}

      {/* 6. Centers & Vans (Enters from top, exits with soft scale) */}
      {f >= TR.statsToCenters && f < TR.centersToSupport + 60 && (
        <div
          style={layer({
            transform: `translateY(${(1 - p5) * -SH}px) scale(${1 - 0.1 * p6})`,
            opacity: 1 - 0.8 * clamp(p6),
          })}
        >
          <CentersVansScreen f={f} />
        </div>
      )}

      {/* 7. Support & SOS (Center scale-in expand) */}
      {f >= TR.centersToSupport && f < TR.outro + 60 && (
        <div
          style={layer({
            transform: `scale(${0.9 + 0.1 * p6})`,
            opacity: clamp(p6 * 1.5),
            boxShadow: '0 20px 50px rgba(15,23,42,0.18)',
          })}
        >
          <SupportScreen f={f} />
        </div>
      )}
    </div>
  );
};

/* ------------------------------------------------------------------ */
/* Phone Frame Chassis                                                */
/* ------------------------------------------------------------------ */

const Phone: React.FC<{f: number}> = ({f}) => {
  const cam = camera(f);

  // Initial simple white screen: phone appears gracefully after frame 45
  const initialEnter = sp(f, 45);
  const fade = (1 - sp(f, TR.outro)) * clamp(initialEnter * 1.4);
  if (fade <= 0.001) return null;

  return (
    <div
      style={{
        position: 'absolute',
        left: cam.x - PHONE_W / 2,
        top: cam.y - PHONE_H / 2,
        width: PHONE_W,
        height: PHONE_H,
        transform: `scale(${cam.s}) rotate(${cam.rot}deg)`,
        opacity: fade,
        zIndex: 10,
      }}
    >
      {/* Device Shadow */}
      <div
        style={{
          position: 'absolute',
          inset: 0,
          borderRadius: 48,
          boxShadow: '0 30px 60px -20px rgba(15,23,42,0.22), 0 12px 24px -12px rgba(15,23,42,0.14)',
        }}
      />
      {/* Phone Screen Canvas */}
      <div
        style={{
          position: 'absolute',
          left: 10,
          top: 10,
          width: SW,
          height: SH,
          borderRadius: 40,
          overflow: 'hidden',
          background: C.screen,
          isolation: 'isolate',
        }}
      >
        <PhoneScreens f={f} />
        <StatusBar />
        <BottomNav f={f} />
      </div>
      {/* Minimalist Phone Bezel */}
      <svg width={PHONE_W} height={PHONE_H} style={{position: 'absolute', left: 0, top: 0, pointerEvents: 'none'}}>
        <rect
          x={5}
          y={5}
          width={PHONE_W - 10}
          height={PHONE_H - 10}
          rx={48}
          fill="none"
          stroke="#0F172A"
          strokeWidth={10}
        />
      </svg>
      {/* Dynamic Island Pill */}
      <div
        style={{
          position: 'absolute',
          top: 22,
          left: PHONE_W / 2 - 58,
          width: 116,
          height: 33,
          borderRadius: 17,
          background: '#0F172A',
        }}
      />
    </div>
  );
};

/* ------------------------------------------------------------------ */
/* Editorial Headline in Poppins (A12C18 & BF5341 - NO Black text!)    */
/* ------------------------------------------------------------------ */

type H = (typeof T.headlines)[number];

const Headline: React.FC<{h: H; f: number}> = ({h, f}) => {
  if (f < h.start - 2 || f > h.end + 40) return null;
  const left = h.side === 'left' ? 140 : 1020;
  const enter = sp(f, h.start);
  const out = sp(f, h.end);

  return (
    <div
      style={{
        position: 'absolute',
        left,
        top: 0,
        width: 740,
        height: 1080,
        display: 'flex',
        flexDirection: 'column',
        justifyContent: 'center',
        zIndex: 5,
        opacity: clamp(enter * 1.3) * (1 - clamp(out)),
        transform: `translateY(${(1 - enter) * 28 - out * 20}px)`,
      }}
    >
      {/* Stage Badge with soft tint and A12C18 text */}
      <div style={{display: 'flex', alignItems: 'center', gap: 12, marginBottom: 22}}>
        <div
          style={{
            display: 'inline-flex',
            alignItems: 'center',
            gap: 8,
            padding: '6px 14px',
            borderRadius: 999,
            background: '#FFF5F5',
            border: '1px solid #FCE7E7',
          }}
        >
          <span
            style={{
              width: 8,
              height: 8,
              borderRadius: 8,
              background: C.textTitle,
              display: 'inline-block',
            }}
          />
          <span
            style={{
              fontFamily: FONT.poppins,
              fontSize: 13,
              fontWeight: 700,
              letterSpacing: 1.5,
              color: C.textTitle,
              textTransform: 'uppercase',
            }}
          >
            {h.step}
          </span>
        </div>
      </div>

      {/* Main Headline Title in Poppins, #A12C18 color */}
      <div
        style={{
          fontFamily: FONT.poppins,
          fontSize: 64,
          fontWeight: 700,
          lineHeight: 1.25,
          letterSpacing: -1.5,
          color: C.textTitle,
          marginBottom: 20,
        }}
      >
        {h.title}
      </div>

      {/* Subtitle in Poppins, #BF5341 color with generous line spacing */}
      <div
        style={{
          fontFamily: FONT.poppins,
          fontSize: 22,
          fontWeight: 400,
          lineHeight: 1.6,
          color: C.textSubtitle,
          maxWidth: 620,
        }}
      >
        {h.subtitle}
      </div>

      {/* Scene 1: Staff Whitelist Verification Terminal Card */}
      {h.id === 'auth' && <AuthVerificationBadge f={f} out={out} />}
    </div>
  );
};

const AuthVerificationBadge: React.FC<{f: number; out: number}> = ({f, out}) => {
  const P = T.auth.pipeline;
  const appear = sp(f, P[0] - 10);
  const lines = [
    {at: P[0], glyph: '✓', title: 'Firebase Phone OTP', sub: '+91 99155 49458 · idToken verified'},
    {at: P[1], glyph: '→', title: 'FastAPI Staff Directory', sub: 'POST /api/v1/auth/verify-staff · 200 OK'},
    {at: P[2], glyph: '✓', title: 'Whitelist Match Confirmed', sub: 'Ward 17 (LGD 0404400017)'},
    {at: P[3], glyph: '★', title: 'Role-Scoped JWT Issued', sub: 'role: sanitary_inspector'},
  ];

  return (
    <div
      style={{
        marginTop: 32,
        width: 640,
        borderRadius: 18,
        background: C.surfaceWhite,
        border: '1.5px solid #FCE7E7',
        padding: '18px 22px',
        boxSizing: 'border-box',
        boxShadow: '0 12px 28px -12px rgba(161,44,24,0.08)',
        opacity: clamp(appear * 1.3) * (1 - clamp(out)),
        transform: `translateY(${(1 - appear) * 20}px)`,
      }}
    >
      <div style={{display: 'flex', alignItems: 'center', gap: 10, marginBottom: 14}}>
        <span
          style={{
            fontFamily: FONT.poppins,
            fontSize: 13,
            fontWeight: 700,
            color: C.textTitle,
            letterSpacing: 1.2,
            textTransform: 'uppercase',
          }}
        >
          Staff Directory Verification
        </span>
      </div>
      <div style={{display: 'flex', flexDirection: 'column', gap: 10}}>
        {lines.map((l) => {
          const p = sp(f, l.at);
          const isDone = f >= l.at;
          return (
            <div
              key={l.title}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: 12,
                opacity: clamp(p * 1.5),
                transform: `translateX(${(1 - p) * -16}px)`,
              }}
            >
              <div
                style={{
                  width: 26,
                  height: 26,
                  borderRadius: 8,
                  background: isDone ? '#DEF7EC' : '#FFF5F5',
                  color: isDone ? '#046C4E' : C.textSubtitle,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  fontSize: 13,
                  fontWeight: 800,
                }}
              >
                {l.glyph}
              </div>
              <div>
                <div style={{fontFamily: FONT.poppins, fontSize: 14.5, fontWeight: 700, color: C.textTitle}}>
                  {l.title}
                </div>
                <div style={{fontFamily: FONT.mono, fontSize: 12, color: C.textSubtitle}}>
                  {l.sub}
                </div>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
};

/* ------------------------------------------------------------------ */
/* Scene 8 — Android App Splash Screen Closing End Screen             */
/* Full red background (#EE211E) with white logo text centered         */
/* ------------------------------------------------------------------ */

const ClosingEndCard: React.FC<{f: number}> = ({f}) => {
  const O = T.outro;
  if (f < O.start) return null;

  const bgEnter = sp(f, O.start);
  const logoPop = sp(f, O.logoPop);

  return (
    <AbsoluteFill
      style={{
        background: C.splashBg, // #EE211E matching Android launch_background.xml
        opacity: clamp(bgEnter * 1.4),
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        zIndex: 30,
      }}
    >
      {/* Centered White "NidanIQ" Logo Text exactly like Android Splash Screen */}
      <div
        style={{
          transform: `scale(${logoPop})`,
          opacity: clamp(logoPop * 1.4),
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <Img
          src={splashLogoPng}
          style={{
            width: 440,
            height: 'auto',
            objectFit: 'contain',
          }}
        />
      </div>
    </AbsoluteFill>
  );
};

/* ------------------------------------------------------------------ */
/* Main Composition Sequence                                           */
/* ------------------------------------------------------------------ */

export const AppShowcaseSequence: React.FC = () => {
  const f = useCurrentFrame();

  return (
    <AbsoluteFill style={{background: C.canvas, overflow: 'hidden'}}>
      {/* Split-Screen Headlines in Poppins (#A12C18 & #BF5341) */}
      {T.headlines.map((h) => (
        <Headline key={h.id} h={h} f={f} />
      ))}

      {/* Main Vector Device Chassis */}
      <Phone f={f} />

      {/* Android Splash Screen Closing End Card */}
      <ClosingEndCard f={f} />

      {/* Synchronized 60-second procedural audio */}
      <Audio src={soundtrack} />
    </AbsoluteFill>
  );
};

export const PHONE_NAV_H = NAV_H;
