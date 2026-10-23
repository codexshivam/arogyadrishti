/**
 * VectorScreenMockup.tsx
 * High-fidelity, 100% vector (CSS/SVG) reproductions of the Arogya Drishti
 * app: Staff Auth flow + Home, AI Scan, GIS Map, Stats, Centers & Vans, Support.
 * Typography is enlarged ~15–20% over the shipping app for mobile legibility.
 * Every component is a pure function of the global frame `f`.
 */
import React from 'react';
import {random} from 'remotion';
import T from './timeline.json';
import {C, FONT, clamp, lerp, press, rise, smooth, sp, tick} from './theme';
import {Icon, LogoMark, type IconName} from './icons';

export const SW = 424; // screen width
export const SH = 892; // screen height
export const NAV_H = 86;

/* ------------------------------------------------------------------ */
/* Shared primitives                                                   */
/* ------------------------------------------------------------------ */

const card: React.CSSProperties = {
  background: C.card,
  borderRadius: 22,
  border: `1px solid ${C.line}`,
  boxShadow: '0 1px 2px rgba(20,20,19,.04), 0 12px 28px -14px rgba(20,20,19,.16)',
};

const Abs: React.FC<{
  x?: number;
  y: number;
  w?: number;
  h?: number;
  style?: React.CSSProperties;
  children?: React.ReactNode;
}> = ({x = 20, y, w = SW - 40, h, style, children}) => (
  <div style={{position: 'absolute', left: x, top: y, width: w, height: h, ...style}}>{children}</div>
);

const Chip: React.FC<{
  color: string;
  bg: string;
  children: React.ReactNode;
  style?: React.CSSProperties;
}> = ({color, bg, children, style}) => (
  <div
    style={{
      display: 'inline-flex',
      alignItems: 'center',
      gap: 6,
      padding: '5px 11px',
      borderRadius: 999,
      background: bg,
      color,
      fontSize: 13,
      fontWeight: 700,
      letterSpacing: 0.2,
      whiteSpace: 'nowrap',
      ...style,
    }}
  >
    {children}
  </div>
);

const Dot: React.FC<{color: string; size?: number; f?: number}> = ({color, size = 8, f}) => {
  const glow = f === undefined ? 0 : (Math.sin(f / 9) + 1) / 2;
  return (
    <span
      style={{
        width: size,
        height: size,
        borderRadius: size,
        background: color,
        display: 'inline-block',
        boxShadow: `0 0 0 ${2 + glow * 4}px ${color}${Math.round(40 - glow * 30)
          .toString(16)
          .padStart(2, '0')}`,
      }}
    />
  );
};

const IconBubble: React.FC<{name: IconName; color: string; bg: string; size?: number; icon?: number}> = ({
  name,
  color,
  bg,
  size = 44,
  icon = 22,
}) => (
  <div
    style={{
      width: size,
      height: size,
      borderRadius: size / 2.6,
      background: bg,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      flexShrink: 0,
    }}
  >
    <Icon name={name} size={icon} color={color} />
  </div>
);

/** Tap ripple, spring-scaled. */
const Ripple: React.FC<{f: number; at: number; x: number; y: number; color?: string}> = ({
  f,
  at,
  x,
  y,
  color = C.blue,
}) => {
  if (f < at || f > at + 40) return null;
  const p = sp(f, at, {damping: 30, stiffness: 120, mass: 0.8});
  return (
    <div
      style={{
        position: 'absolute',
        left: x - 50,
        top: y - 50,
        width: 100,
        height: 100,
        borderRadius: 100,
        background: color,
        opacity: 0.28 * (1 - clamp(p)),
        transform: `scale(${0.2 + p * 1.3})`,
        pointerEvents: 'none',
      }}
    />
  );
};

const ScreenHeader: React.FC<{
  f: number;
  at: number;
  title: string;
  sub: string;
  back?: boolean;
  right?: React.ReactNode;
}> = ({f, at, title, sub, back, right}) => (
  <Abs y={62} h={52} style={{display: 'flex', alignItems: 'center', gap: 12, ...rise(f, at, 14)}}>
    {back && (
      <div
        style={{
          width: 42,
          height: 42,
          borderRadius: 14,
          background: C.card,
          border: `1px solid ${C.line}`,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <Icon name="chevronLeft" size={22} color={C.ink} />
      </div>
    )}
    <div style={{flex: 1, minWidth: 0}}>
      <div style={{fontSize: 23, fontWeight: 800, color: C.ink, letterSpacing: -0.4}}>{title}</div>
      <div style={{fontSize: 14, color: C.muted, marginTop: 2, fontWeight: 500}}>{sub}</div>
    </div>
    {right}
  </Abs>
);

const mono = (size: number, weight = 700, color: string = C.ink): React.CSSProperties => ({
  fontFamily: FONT.mono,
  fontSize: size,
  fontWeight: weight,
  color,
  fontVariantNumeric: 'tabular-nums',
  letterSpacing: -0.5,
});

/* ------------------------------------------------------------------ */
/* Persistent chrome: status bar + bottom navigation                  */
/* ------------------------------------------------------------------ */

export const StatusBar: React.FC = () => (
  <div
    style={{
      position: 'absolute',
      left: 0,
      top: 0,
      width: SW,
      height: 50,
      padding: '17px 32px 0 36px',
      display: 'flex',
      justifyContent: 'space-between',
      fontFamily: FONT.sans,
      fontWeight: 700,
      fontSize: 17,
      color: C.ink,
      zIndex: 50,
    }}
  >
    <span>9:41</span>
    <div style={{display: 'flex', gap: 7, alignItems: 'center'}}>
      <svg width="19" height="12" viewBox="0 0 19 12">
        {[0, 1, 2, 3].map((i) => (
          <rect key={i} x={i * 5} y={9 - i * 3} width="3.4" height={3 + i * 3} rx="1" fill={C.ink} />
        ))}
      </svg>
      <svg width="17" height="12" viewBox="0 0 17 12" fill="none" stroke={C.ink} strokeWidth="2" strokeLinecap="round">
        <path d="M1.5 4.2a10 10 0 0 1 14 0" />
        <path d="M4.3 7a6 6 0 0 1 8.4 0" />
        <circle cx="8.5" cy="10" r="1" fill={C.ink} />
      </svg>
      <svg width="27" height="13" viewBox="0 0 27 13">
        <rect x="0.5" y="0.5" width="23" height="12" rx="3.5" fill="none" stroke={C.ink} opacity=".4" />
        <rect x="2.5" y="2.5" width="17" height="8" rx="2" fill={C.ink} />
        <rect x="24.5" y="4.5" width="1.6" height="4" rx=".8" fill={C.ink} opacity=".4" />
      </svg>
    </div>
  </div>
);

const NAV_ITEMS: {icon: IconName; label: string}[] = [
  {icon: 'home', label: 'Home'},
  {icon: 'camera', label: 'Scan'},
  {icon: 'map', label: 'Map'},
  {icon: 'chart', label: 'Stats'},
  {icon: 'grid', label: 'More'},
];

export const BottomNav: React.FC<{f: number}> = ({f}) => {
  if (f < T.T.authToHome) return null;
  const enter = sp(f, T.T.authToHome + 6);
  const idx =
    sp(f, T.T.homeToScan) + sp(f, T.T.scanToMap) + sp(f, T.T.mapToStats) + sp(f, T.T.statsToCenters);
  const active = Math.round(idx);
  const itemW = SW / NAV_ITEMS.length;
  return (
    <div
      style={{
        position: 'absolute',
        left: 0,
        bottom: 0,
        width: SW,
        height: NAV_H,
        background: 'rgba(255,255,255,0.96)',
        borderTop: `1px solid ${C.line}`,
        transform: `translateY(${(1 - enter) * NAV_H * 1.2}px)`,
        zIndex: 40,
      }}
    >
      <div
        style={{
          position: 'absolute',
          top: 9,
          left: idx * itemW + (itemW - 60) / 2,
          width: 60,
          height: 34,
          borderRadius: 17,
          background: '#DBE6FE',
        }}
      />
      {NAV_ITEMS.map((it, i) => {
        const on = i === active;
        return (
          <div
            key={it.label}
            style={{
              position: 'absolute',
              left: i * itemW,
              top: 14,
              width: itemW,
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              gap: 7,
            }}
          >
            <Icon name={it.icon} size={23} color={on ? C.blue : C.muted} stroke={on ? 2.4 : 2} />
            <span style={{fontSize: 12.5, fontWeight: on ? 800 : 600, color: on ? C.blue : C.muted}}>{it.label}</span>
          </div>
        );
      })}
      <div
        style={{
          position: 'absolute',
          bottom: 7,
          left: SW / 2 - 66,
          width: 132,
          height: 5,
          borderRadius: 5,
          background: C.ink,
        }}
      />
    </div>
  );
};

/* ------------------------------------------------------------------ */
/* Scene 1 — Staff Auth (Firebase OTP → whitelist → JWT)              */
/* ------------------------------------------------------------------ */

const PIPELINE: {icon: IconName; title: string; sub: string}[] = [
  {icon: 'shieldCheck', title: 'Firebase Auth Verified', sub: 'phone_number ✓ · idToken issued'},
  {icon: 'server', title: 'POST /api/v1/auth/verify-staff', sub: '200 OK · 142 ms'},
  {icon: 'database', title: 'Staff Directory Match', sub: 'Ward 17 · LGD 0404400017'},
  {icon: 'key', title: 'JWT Issued', sub: 'role: sanitary_inspector'},
];

export const AuthScreen: React.FC<{f: number}> = ({f}) => {
  const A = T.auth;
  const typed =
    f < A.typeStart ? 0 : Math.min(A.digits.length, Math.floor((f - A.typeStart) / A.typeInterval) + 1);
  const d = A.digits.slice(0, typed);
  const shown = d.length > 5 ? `${d.slice(0, 5)} ${d.slice(5)}` : d;
  const focused = f < A.tapSend + 3;
  const caret = focused && Math.floor(f / 16) % 2 === 0;
  const btnPress = press(f, A.tapSend);
  const sent = f >= A.tapSend + 4;
  const otpIn = sp(f, A.otpShow);
  const otpCount = f < A.otpStart ? 0 : Math.min(6, Math.floor((f - A.otpStart) / A.otpInterval) + 1);
  const pipeIn = sp(f, A.pipeline[0] - 14);
  const ok = sp(f, A.success);
  const verified = f >= A.success;
  const ring = sp(f, A.success, {damping: 40, stiffness: 50, mass: 1});

  return (
    <div style={{position: 'absolute', inset: 0, background: C.screen, fontFamily: FONT.sans}}>
      <Abs y={110}>
        <div style={{fontSize: 32, fontWeight: 800, color: C.ink, letterSpacing: -0.6}}>Verify your identity</div>
        <div style={{fontSize: 16, color: C.muted, marginTop: 8, lineHeight: 1.45, fontWeight: 500}}>
          Enter your registered mobile number to continue.
        </div>
      </Abs>
      <Abs y={210} style={{fontSize: 13, fontWeight: 800, color: C.muted, letterSpacing: 1.4}}>
        REGISTERED MOBILE NUMBER
      </Abs>
      <Abs
        y={238}
        h={62}
        style={{
          background: C.card,
          borderRadius: 16,
          border: `2px solid ${focused ? C.blue : C.line}`,
          boxShadow: focused ? '0 0 0 4px rgba(37,99,235,0.12)' : 'none',
          display: 'flex',
          alignItems: 'center',
          padding: '0 18px',
          gap: 14,
          boxSizing: 'border-box',
        }}
      >
        <span style={{...mono(21, 700, C.ink)}}>+91</span>
        <span style={{width: 1.5, height: 28, background: C.line}} />
        <span style={{...mono(23, 600, C.ink), letterSpacing: 1}}>
          {shown}
          <span style={{opacity: caret ? 1 : 0, color: C.blue, fontWeight: 400}}>|</span>
        </span>
        {typed === A.digits.length && (
          <span style={{marginLeft: 'auto', transform: `scale(${sp(f, A.typeStart + 10 * A.typeInterval)})`}}>
            <Icon name="check" size={22} color={C.emerald} stroke={3} />
          </span>
        )}
      </Abs>
      <Abs
        y={314}
        h={58}
        style={{
          borderRadius: 16,
          background: verified ? C.emerald : sent ? C.card : C.blue,
          border: sent && !verified ? `2px solid ${C.line}` : '2px solid transparent',
          color: sent && !verified ? C.muted : '#fff',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          gap: 10,
          fontSize: 18,
          fontWeight: 800,
          transform: `scale(${1 - 0.06 * btnPress + 0.03 * (ok - sp(f, A.success + 8))})`,
          boxSizing: 'border-box',
          overflow: 'hidden',
          position: 'absolute',
        }}
      >
        {verified ? (
          <>
            <Icon name="check" size={21} color="#fff" stroke={3} /> Verified · Entering dashboard
          </>
        ) : sent ? (
          <>OTP sent · Resend in 0:{String(Math.max(10, 30 - Math.floor((f - A.tapSend) / 60))).padStart(2, '0')}</>
        ) : (
          <>
            Send OTP <Icon name="arrowRight" size={20} color="#fff" stroke={2.6} />
          </>
        )}
        <Ripple f={f} at={A.tapSend} x={192} y={29} color="#fff" />
      </Abs>

      {/* OTP block */}
      <Abs
        y={394}
        h={100}
        style={{
          opacity: clamp(otpIn * 1.3),
          transform: `translateY(${(1 - otpIn) * 24}px)`,
        }}
      >
        <div style={{fontSize: 15, color: C.muted, fontWeight: 600}}>
          Enter the 6-digit code sent to <span style={{color: C.ink, ...mono(15, 700)}}>+91 ••••• 49458</span>
        </div>
        <div style={{display: 'flex', gap: 10, marginTop: 12}}>
          {A.otp.split('').map((dig, i) => {
            const filled = i < otpCount;
            const pop = sp(f, A.otpStart + i * A.otpInterval);
            const activeBox = i === otpCount && f >= A.otpShow && otpCount < 6;
            return (
              <div
                key={i}
                style={{
                  width: 54,
                  height: 62,
                  borderRadius: 14,
                  background: C.card,
                  border: `2px solid ${verified ? C.emerald : filled ? C.ink : activeBox ? C.blue : C.line}`,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  boxSizing: 'border-box',
                }}
              >
                <span
                  style={{
                    ...mono(27, 700, filled ? C.ink : C.faint),
                    transform: `scale(${filled ? 0.6 + 0.4 * pop : 1})`,
                    display: 'inline-block',
                  }}
                >
                  {filled ? dig : '•'}
                </span>
              </div>
            );
          })}
        </div>
      </Abs>

      {/* Verification pipeline */}
      <Abs
        y={520}
        h={236}
        style={{
          ...card,
          border: `1.5px solid ${verified ? C.emerald : C.line}`,
          padding: '12px 16px',
          boxSizing: 'border-box',
          opacity: clamp(pipeIn * 1.4),
          transform: `translateY(${(1 - pipeIn) * 30}px)`,
        }}
      >
        {verified && (
          <div
            style={{
              position: 'absolute',
              inset: -2,
              borderRadius: 24,
              border: `3px solid ${C.emerald}`,
              opacity: 0.6 * (1 - ring),
              transform: `scale(${1 + ring * 0.08})`,
            }}
          />
        )}
        {PIPELINE.map((row, i) => {
          const at = A.pipeline[i];
          const done = f >= at;
          const running = !done && f >= at - 14;
          const pop = sp(f, at);
          return (
            <div key={row.title} style={{display: 'flex', alignItems: 'center', gap: 12, height: 50}}>
              <div
                style={{
                  width: 34,
                  height: 34,
                  borderRadius: 11,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  background: done ? '#D1FAE5' : C.soft,
                  transform: `scale(${done ? 0.7 + 0.3 * pop : 1})`,
                }}
              >
                {done ? (
                  <Icon name="check" size={18} color="#047857" stroke={3} />
                ) : running ? (
                  <svg width="20" height="20" viewBox="0 0 20 20" style={{transform: `rotate(${f * 14}deg)`}}>
                    <circle cx="10" cy="10" r="7.5" fill="none" stroke={C.line} strokeWidth="3" />
                    <path d="M10 2.5a7.5 7.5 0 0 1 7.5 7.5" fill="none" stroke={C.blue} strokeWidth="3" strokeLinecap="round" />
                  </svg>
                ) : (
                  <Icon name={row.icon} size={17} color={C.faint} />
                )}
              </div>
              <div style={{minWidth: 0, opacity: done || running ? 1 : 0.45}}>
                <div
                  style={{
                    fontSize: i === 1 ? 14 : 15.5,
                    fontWeight: 800,
                    color: C.ink,
                    fontFamily: i === 1 ? FONT.mono : FONT.sans,
                    letterSpacing: i === 1 ? -0.4 : -0.1,
                  }}
                >
                  {row.title}
                </div>
                <div style={{...mono(12.5, 500, done ? '#047857' : C.muted), letterSpacing: -0.2}}>{row.sub}</div>
              </div>
            </div>
          );
        })}
      </Abs>
      <Abs
        y={838}
        h={24}
        style={{
          display: 'flex',
          justifyContent: 'center',
          alignItems: 'center',
          gap: 7,
          fontSize: 13,
          color: C.muted,
          fontWeight: 600,
        }}
      >
        <Icon name="shield" size={14} color={C.muted} /> Protected by Firebase Authentication · reCAPTCHA
      </Abs>
    </div>
  );
};

/* ------------------------------------------------------------------ */
/* Scene 2 — Home Dashboard                                            */
/* ------------------------------------------------------------------ */

export const HomeScreen: React.FC<{f: number}> = ({f}) => {
  const t0 = T.T.authToHome + 10;
  const tap = T.home.tapScan;
  const bi = tick(f, t0 + 20, 0, 34);
  const spark = [10, 12, 11, 15, 19, 24, 29, 34];
  const sparkPath = spark.map((v, i) => `${i === 0 ? 'M' : 'L'}${i * 17} ${44 - v}`).join(' ');
  const sparkDraw = smooth(f, t0 + 30);
  const actions: {icon: IconName; label: string; color: string; bg: string}[] = [
    {icon: 'camera', label: 'Scan', color: '#fff', bg: C.blue},
    {icon: 'truck', label: 'Request Van', color: C.ink, bg: C.soft},
    {icon: 'megaphone', label: 'Send Alert', color: C.crimson, bg: '#FEE2E2'},
  ];
  return (
    <div style={{position: 'absolute', inset: 0, background: C.screen, fontFamily: FONT.sans}}>
      <Abs y={60} h={54} style={{display: 'flex', alignItems: 'center', gap: 12, ...rise(f, t0, 16)}}>
        <div
          style={{
            width: 50,
            height: 50,
            borderRadius: 25,
            background: 'linear-gradient(135deg,#1E3A8A,#2563EB)',
            color: '#fff',
            fontWeight: 800,
            fontSize: 18,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          SY
        </div>
        <div style={{flex: 1}}>
          <div style={{fontSize: 14.5, color: C.muted, fontWeight: 600}}>Good evening,</div>
          <div style={{fontSize: 23, fontWeight: 800, color: C.ink, letterSpacing: -0.5}}>Shivam Yadav</div>
        </div>
        <div
          style={{
            width: 46,
            height: 46,
            borderRadius: 16,
            background: C.card,
            border: `1px solid ${C.line}`,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            position: 'relative',
          }}
        >
          <Icon name="bell" size={22} color={C.ink} />
          <span
            style={{
              position: 'absolute',
              top: 10,
              right: 11,
              width: 9,
              height: 9,
              borderRadius: 9,
              background: C.crimson,
              border: '2px solid #fff',
            }}
          />
        </div>
      </Abs>
      <Abs y={124} h={30} style={{display: 'flex', gap: 8, alignItems: 'center', ...rise(f, t0 + 4, 14)}}>
        <Chip color={C.ink} bg={C.card} style={{border: `1px solid ${C.line}`}}>
          <Icon name="pin" size={14} color={C.crimson} stroke={2.4} /> Chandigarh · Ward 17
        </Chip>
        <Chip color="#047857" bg="#D1FAE5">
          <Icon name="shieldCheck" size={14} color="#047857" stroke={2.4} /> Sanitary Inspector
        </Chip>
      </Abs>

      {/* Proactive alert */}
      <Abs
        y={170}
        h={206}
        style={{
          borderRadius: 26,
          background: 'linear-gradient(140deg,#EF4444 0%,#DC2626 45%,#991B1B 100%)',
          color: '#fff',
          padding: 18,
          boxSizing: 'border-box',
          boxShadow: '0 20px 40px -18px rgba(220,38,38,0.65)',
          overflow: 'hidden',
          ...rise(f, t0 + 8, 30),
        }}
      >
        <div style={{display: 'flex', alignItems: 'center', gap: 8}}>
          <Chip color="#fff" bg="rgba(255,255,255,0.18)">
            <Dot color="#fff" size={7} f={f} /> PROACTIVE ALERT
          </Chip>
          <span style={{marginLeft: 'auto', fontSize: 13, opacity: 0.85, fontWeight: 600}}>2 min ago</span>
        </div>
        <div style={{marginTop: 14, fontSize: 15, opacity: 0.88, fontWeight: 600}}>Breteau Index · Ward 14</div>
        <div style={{display: 'flex', alignItems: 'flex-end', gap: 12, marginTop: 2}}>
          <span style={{...mono(52, 700, '#fff'), lineHeight: 1}}>{bi.toFixed(1)}</span>
          <Chip color={C.crimson} bg="#fff" style={{marginBottom: 6}}>
            <Icon name="alert" size={14} color={C.crimson} stroke={2.6} /> Critical
          </Chip>
          <svg width="122" height="48" viewBox="-2 -2 124 50" style={{marginLeft: 'auto'}}>
            <path
              d={sparkPath}
              fill="none"
              stroke="#fff"
              strokeWidth="3"
              strokeLinecap="round"
              strokeLinejoin="round"
              pathLength={1}
              strokeDasharray={1}
              strokeDashoffset={1 - sparkDraw}
            />
            <circle cx={119} cy={10} r={4.5 * sparkDraw} fill="#fff" />
          </svg>
        </div>
        <div style={{marginTop: 10, fontSize: 15, fontWeight: 600, opacity: 0.95}}>
          Anand Vihar · ↑ rising 3 consecutive weeks
        </div>
      </Abs>

      <Abs y={396} style={{fontSize: 19, fontWeight: 800, color: C.ink, ...rise(f, t0 + 14, 14)}}>
        Quick actions
      </Abs>
      <Abs y={430} h={110} style={{display: 'flex', gap: 12}}>
        {actions.map((a, i) => {
          const tapScale = i === 0 ? 1 - 0.08 * press(f, tap) : 1;
          return (
            <div
              key={a.label}
              style={{
                ...card,
                flex: 1,
                position: 'relative',
                overflow: 'hidden',
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'flex-start',
                justifyContent: 'space-between',
                padding: 14,
                boxSizing: 'border-box',
                border: i === 0 && f >= tap ? `2px solid ${C.blue}` : card.border,
                ...rise(f, t0 + 16 + i * 4, 26),
                transform: `${rise(f, t0 + 16 + i * 4, 26).transform} scale(${tapScale})`,
              }}
            >
              <IconBubble name={a.icon} color={a.color} bg={a.bg} size={44} icon={22} />
              <span style={{fontSize: 15.5, fontWeight: 800, color: C.ink, letterSpacing: -0.2}}>{a.label}</span>
              {i === 0 && <Ripple f={f} at={tap} x={60} y={55} />}
            </div>
          );
        })}
      </Abs>

      <Abs y={556} h={104} style={{display: 'flex', gap: 12}}>
        {[
          {label: 'Houses surveyed', v: tick(f, t0 + 34, 0, 128), c: C.ink, sub: 'today'},
          {label: 'Positive containers', v: tick(f, t0 + 38, 0, 19), c: C.crimson, sub: 'of 199 inspected'},
        ].map((s, i) => (
          <div
            key={s.label}
            style={{...card, flex: 1, padding: 15, boxSizing: 'border-box', ...rise(f, t0 + 26 + i * 4, 24)}}
          >
            <div style={{fontSize: 14, color: C.muted, fontWeight: 700}}>{s.label}</div>
            <div style={{...mono(34, 700, s.c), marginTop: 4}}>{Math.round(s.v)}</div>
            <div style={{fontSize: 12.5, color: C.muted, fontWeight: 600}}>{s.sub}</div>
          </div>
        ))}
      </Abs>
      <Abs
        y={676}
        h={112}
        style={{...card, padding: '14px 16px', boxSizing: 'border-box', ...rise(f, t0 + 34, 24)}}
      >
        <div style={{display: 'flex', alignItems: 'center', justifyContent: 'space-between'}}>
          <span style={{fontSize: 16, fontWeight: 800, color: C.ink}}>Recent field log</span>
          <Chip color="#047857" bg="#D1FAE5">
            <Dot color={C.emerald} size={7} f={f} /> Live sync
          </Chip>
        </div>
        {[
          ['Sector 22-C', '3 containers positive', '08:42'],
          ['Anand Vihar', 'Drum larvae · AI 88%', '08:17'],
        ].map(([a, b, c]) => (
          <div key={a} style={{display: 'flex', alignItems: 'center', gap: 10, marginTop: 9}}>
            <Dot color={C.crimson} size={7} />
            <span style={{fontSize: 14.5, fontWeight: 700, color: C.ink}}>{a}</span>
            <span style={{fontSize: 14, color: C.muted, fontWeight: 500}}>{b}</span>
            <span style={{marginLeft: 'auto', ...mono(13, 500, C.muted)}}>{c}</span>
          </div>
        ))}
      </Abs>
    </div>
  );
};

/* ------------------------------------------------------------------ */
/* GIS map world (shared by Scan thumbnail + Map screen)              */
/* ------------------------------------------------------------------ */

const BLOCK = 150;
const ROAD = 22;
const STEP = BLOCK + ROAD;

const MapWorld: React.FC<{f: number; pinsFrom?: number}> = ({f, pinsFrom = -1}) => {
  const blocks: React.ReactNode[] = [];
  let sector = 1;
  for (let r = 0; r < 9; r++) {
    for (let c = 0; c < 7; c++) {
      const x = c * STEP + ROAD;
      const y = r * STEP + ROAD;
      const seed = `b${r}-${c}`;
      const buildings: React.ReactNode[] = [];
      for (let k = 0; k < 9; k++) {
        const bx = x + 12 + (k % 3) * 44 + random(`${seed}x${k}`) * 8;
        const by = y + 12 + Math.floor(k / 3) * 44 + random(`${seed}y${k}`) * 8;
        const bw = 22 + random(`${seed}w${k}`) * 14;
        const bh = 18 + random(`${seed}h${k}`) * 16;
        buildings.push(<rect key={k} x={bx} y={by} width={bw} height={bh} rx={3} fill="#DDD8CC" />);
      }
      const park = (r + c * 2) % 7 === 3;
      blocks.push(
        <g key={seed}>
          <rect x={x} y={y} width={BLOCK} height={BLOCK} rx={8} fill={park ? '#D4E6C9' : '#E9E5DB'} />
          {!park && buildings}
          <text
            x={x + BLOCK / 2}
            y={y + BLOCK / 2 + 5}
            textAnchor="middle"
            style={{fontFamily: FONT.sans, fontSize: 13, fontWeight: 700, fill: '#A39E92', letterSpacing: 1}}
          >
            {`SECTOR ${sector}`}
          </text>
        </g>,
      );
      sector++;
    }
  }
  const heat = [
    {x: 640, y: 800, r: 165, c: '220,38,38', a: 0.62},
    {x: 770, y: 910, r: 115, c: '220,38,38', a: 0.5},
    {x: 560, y: 940, r: 95, c: '239,68,68', a: 0.42},
    {x: 300, y: 430, r: 110, c: '217,119,6', a: 0.35},
    {x: 920, y: 1240, r: 90, c: '217,119,6', a: 0.3},
  ];
  const pins = [
    {x: 600, y: 760, n: 'RK'},
    {x: 735, y: 965, n: 'AS'},
    {x: 835, y: 815, n: 'PM'},
    {x: 470, y: 880, n: 'SY'},
  ];
  const sites = [
    [660, 840],
    [700, 790],
    [610, 880],
    [790, 930],
    [545, 965],
    [745, 870],
    [320, 450],
  ];
  return (
    <svg width={1220} height={1600} viewBox="0 0 1220 1600" style={{display: 'block'}}>
      <defs>
        {heat.map((h, i) => (
          <radialGradient key={i} id={`heat${i}`}>
            <stop offset="0" stopColor={`rgba(${h.c},${h.a})`} />
            <stop offset="0.55" stopColor={`rgba(${h.c},${h.a * 0.45})`} />
            <stop offset="1" stopColor={`rgba(${h.c},0)`} />
          </radialGradient>
        ))}
      </defs>
      <rect width={1220} height={1600} fill="#FBFAF7" />
      {blocks}
      {/* arterial avenues */}
      {[1, 4].map((c) => (
        <rect key={`v${c}`} x={c * STEP + ROAD - ROAD} y={0} width={ROAD} height={1600} fill="#F3DFA2" />
      ))}
      {[2, 6].map((r) => (
        <rect key={`h${r}`} x={0} y={r * STEP} width={1220} height={ROAD} fill="#F3DFA2" />
      ))}
      {/* Leisure valley + lake */}
      <path d="M0 260 C 180 300, 260 420, 420 520 S 700 700, 760 1600 L 700 1600 C 650 760, 420 600, 300 520 S 120 340, 0 320 Z" fill="#CFE3C4" opacity="0.9" />
      <path d="M960 40 C 1080 20, 1200 80, 1210 170 C 1220 260, 1100 300, 1020 270 C 930 240, 880 90, 960 40 Z" fill="#BCD7E8" />
      <text x={1050} y={170} textAnchor="middle" style={{fontFamily: FONT.sans, fontSize: 15, fontWeight: 700, fill: '#5B89A8'}}>
        Sukhna Lake
      </text>
      {/* Heatmap */}
      {heat.map((h, i) => {
        const pulse = 1 + 0.09 * Math.sin(f / 13 + i * 1.7);
        return <circle key={i} cx={h.x} cy={h.y} r={h.r * pulse} fill={`url(#heat${i})`} />;
      })}
      {/* Ward 14 boundary */}
      <path
        d="M505 690 L 860 680 L 905 905 L 830 1030 L 520 1020 L 470 860 Z"
        fill="rgba(220,38,38,0.05)"
        stroke={C.crimson}
        strokeWidth={3}
        strokeDasharray="10 8"
        strokeDashoffset={-f * 0.6}
      />
      <g transform="translate(520 662)">
        <rect width={216} height={30} rx={15} fill={C.crimson} />
        <text x={108} y={20} textAnchor="middle" style={{fontFamily: FONT.sans, fontSize: 13, fontWeight: 800, fill: '#fff', letterSpacing: 1}}>
          WARD 14 · ANAND VIHAR
        </text>
      </g>
      {sites.map(([x, y], i) => (
        <rect key={i} x={x - 6} y={y - 6} width={12} height={12} rx={2} transform={`rotate(45 ${x} ${y})`} fill={C.crimson} stroke="#fff" strokeWidth={2.5} />
      ))}
      {/* Inspector GPS pins */}
      {pins.map((p, i) => {
        const appear = pinsFrom < 0 ? 1 : sp(f, T.map.pins[i] ?? pinsFrom);
        const t = ((f + i * 17) % 70) / 70;
        const e = 1 - Math.pow(1 - t, 3);
        return (
          <g key={p.n} transform={`translate(${p.x} ${p.y}) scale(${appear})`}>
            <circle r={14 + e * 30} fill="none" stroke={C.blue} strokeWidth={2.5} opacity={(1 - e) * 0.7} />
            <circle r={19} fill={C.blue} stroke="#fff" strokeWidth={4} />
            <text y={5} textAnchor="middle" style={{fontFamily: FONT.sans, fontSize: 12.5, fontWeight: 800, fill: '#fff'}}>
              {p.n}
            </text>
          </g>
        );
      })}
    </svg>
  );
};

type Pan = {x: number; y: number; z: number};
const PAN0: Pan = {x: 170, y: 200, z: 1};
const PAN1: Pan = {x: 536, y: 600, z: 1.1};

const MapViewport: React.FC<{f: number; pan: Pan; pinsFrom?: number}> = ({f, pan, pinsFrom}) => (
  <div style={{position: 'absolute', left: 0, top: 0, width: SW, height: SH, overflow: 'hidden', background: '#FBFAF7'}}>
    <div
      style={{
        position: 'absolute',
        left: 0,
        top: 0,
        transformOrigin: '0 0',
        transform: `translate(${-pan.x}px, ${-pan.y}px) scale(${pan.z})`,
      }}
    >
      <MapWorld f={f} pinsFrom={pinsFrom} />
    </div>
  </div>
);

/* Map thumbnail geometry inside the Scan screen (used for the zoom-in transition). */
export const THUMB = {x: 20, y: 690, w: SW - 40, h: 104, r: 20};
export const THUMB_K = THUMB.w / SW;

/* ------------------------------------------------------------------ */
/* Scene 3 — AI Vector Scan                                            */
/* ------------------------------------------------------------------ */

const Viewfinder: React.FC<{f: number}> = ({f}) => {
  const [b1, b2] = T.scan.boxes;
  const pWater = sp(f, b1);
  const pLarva = sp(f, b2);
  const conf = tick(f, b2, 0, 88);
  const confW = tick(f, b1, 0, 96);
  const scanY = 170 + Math.sin(f / 22) * 150;
  const larvae = [
    [196, 132],
    [214, 142],
    [232, 128],
    [222, 155],
    [246, 147],
    [204, 150],
    [240, 136],
  ];
  const Box: React.FC<{x: number; y: number; w: number; h: number; c: string; p: number}> = ({x, y, w, h, c, p}) => {
    const s = 1.25 - 0.25 * p;
    const L = 16;
    return (
      <g opacity={clamp(p * 1.5)} transform={`translate(${x + w / 2} ${y + h / 2}) scale(${s}) translate(${-w / 2} ${-h / 2})`}>
        <rect width={w} height={h} rx={6} fill={`${c}1A`} stroke={c} strokeWidth={1.5} opacity={0.7} />
        <path
          d={`M0 ${L} V0 H${L} M${w - L} 0 H${w} V${L} M${w} ${h - L} V${h} H${w - L} M${L} ${h} H0 V${h - L}`}
          fill="none"
          stroke={c}
          strokeWidth={4}
          strokeLinecap="round"
        />
      </g>
    );
  };
  return (
    <svg width={384} height={330} viewBox="0 0 384 330" style={{display: 'block'}}>
      <defs>
        <linearGradient id="vf-bg" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#2A3436" />
          <stop offset="1" stopColor="#111819" />
        </linearGradient>
        <linearGradient id="drum" x1="0" y1="0" x2="1" y2="0">
          <stop offset="0" stopColor="#1E3A8A" />
          <stop offset="0.45" stopColor="#2563EB" />
          <stop offset="1" stopColor="#1E3A8A" />
        </linearGradient>
        <radialGradient id="water" cx="0.45" cy="0.4">
          <stop offset="0" stopColor="#3F6B5A" />
          <stop offset="1" stopColor="#14302A" />
        </radialGradient>
        <linearGradient id="scan" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="rgba(16,185,129,0)" />
          <stop offset="1" stopColor="rgba(16,185,129,0.35)" />
        </linearGradient>
      </defs>
      <rect width={384} height={330} fill="url(#vf-bg)" />
      {[0, 1, 2, 3, 4, 5].map((i) => (
        <path key={i} d={`M${-40 + i * 90} 330 L ${60 + i * 60} 200`} stroke="rgba(255,255,255,0.05)" strokeWidth={2} />
      ))}
      {/* drum */}
      <path d="M72 140 L 72 330 L 312 330 L 312 140 Z" fill="url(#drum)" />
      {[205, 270].map((y) => (
        <path key={y} d={`M72 ${y} Q 192 ${y + 34} 312 ${y}`} fill="none" stroke="rgba(255,255,255,0.18)" strokeWidth={4} />
      ))}
      <ellipse cx={192} cy={140} rx={120} ry={42} fill="#1E40AF" stroke="#60A5FA" strokeWidth={3} />
      <ellipse cx={192} cy={142} rx={106} ry={34} fill="url(#water)" />
      {[0, 1, 2].map((i) => {
        const t = ((f + i * 30) % 90) / 90;
        const e = 1 - Math.pow(1 - t, 2);
        return (
          <ellipse key={i} cx={170} cy={145} rx={10 + e * 70} ry={3 + e * 22} fill="none" stroke="rgba(255,255,255,0.35)" strokeWidth={1.4} opacity={1 - e} />
        );
      })}
      {larvae.map(([x, y], i) => (
        <path
          key={i}
          d="M-6 0 q 3 -4 6 0 t 6 0"
          transform={`translate(${x} ${y}) rotate(${Math.sin(f / 5 + i * 1.3) * 35 + i * 40})`}
          stroke="#E7E1C8"
          strokeWidth={2}
          fill="none"
          strokeLinecap="round"
        />
      ))}
      <Box x={80} y={100} w={224} h={82} c="#60A5FA" p={pWater} />
      <Box x={184} y={116} w={76} h={50} c="#F87171" p={pLarva} />
      {/* labels */}
      <g opacity={clamp(pWater * 1.5)} transform={`translate(80 ${190 + (1 - pWater) * 10})`}>
        <rect width={178} height={28} rx={8} fill={C.blue} />
        <text x={10} y={19} style={{fontFamily: FONT.sans, fontSize: 13.5, fontWeight: 800, fill: '#fff'}}>
          {`Stagnant Water · ${Math.round(confW)}%`}
        </text>
      </g>
      <g opacity={clamp(pLarva * 1.5)} transform={`translate(150 ${68 - (1 - pLarva) * 10})`}>
        <rect width={202} height={30} rx={8} fill={C.crimson} />
        <text x={10} y={20} style={{fontFamily: FONT.sans, fontSize: 14, fontWeight: 800, fill: '#fff'}}>
          {`Larvae Detected + ${Math.round(conf)}%`}
        </text>
      </g>
      {/* scanline */}
      <rect x={0} y={scanY - 40} width={384} height={40} fill="url(#scan)" />
      <rect x={0} y={scanY} width={384} height={2} fill="rgba(52,211,153,0.9)" />
      {/* HUD */}
      <path d="M14 38 V14 H38 M346 14 H370 V38 M370 292 V316 H346 M38 316 H14 V292" fill="none" stroke="rgba(255,255,255,0.75)" strokeWidth={3} strokeLinecap="round" />
      <text x={24} y={36} style={{fontFamily: FONT.mono, fontSize: 11.5, fill: 'rgba(255,255,255,0.85)', fontWeight: 500}}>
        PaliGemma 2 · 3B · int8
      </text>
      <circle cx={322} cy={31} r={5} fill={C.crimson} opacity={0.5 + 0.5 * Math.sin(f / 7)} />
      <text x={332} y={36} style={{fontFamily: FONT.mono, fontSize: 11.5, fill: '#fff', fontWeight: 700}}>
        REC
      </text>
      <text x={24} y={306} style={{fontFamily: FONT.mono, fontSize: 11.5, fill: 'rgba(255,255,255,0.8)', fontWeight: 500}}>
        {`24 ms · 30.7046°N 76.7179°E · f${String(1200 + Math.floor(f / 2)).padStart(5, '0')}`}
      </text>
    </svg>
  );
};

export const ScanScreen: React.FC<{f: number}> = ({f}) => {
  const t0 = T.T.homeToScan + 8;
  const tel = T.scan.telemetry;
  const water = tick(f, tel, 0, 96);
  const temp = tick(f, tel + 12, 24, 31.4);
  const rain = tick(f, tel + 24, 0, 42.6);
  return (
    <div style={{position: 'absolute', inset: 0, background: C.screen, fontFamily: FONT.sans}}>
      <ScreenHeader
        f={f}
        at={t0}
        back
        title="AI Vector Scan"
        sub="PaliGemma · on-device inference"
        right={
          <Chip color={C.crimson} bg="#FEE2E2">
            <Dot color={C.crimson} size={7} f={f} /> LIVE
          </Chip>
        }
      />
      <Abs y={126} h={330} style={{borderRadius: 26, overflow: 'hidden', boxShadow: '0 18px 36px -18px rgba(20,20,19,.5)', ...rise(f, t0 + 4, 30)}}>
        <Viewfinder f={f} />
      </Abs>
      <Abs y={470} h={84} style={{...card, padding: '12px 16px', boxSizing: 'border-box', ...rise(f, tel - 10, 24)}}>
        <div style={{display: 'flex', alignItems: 'center', gap: 12}}>
          <IconBubble name="droplet" color={C.blue} bg="#DBEAFE" size={40} icon={20} />
          <div style={{flex: 1}}>
            <div style={{fontSize: 14, color: C.muted, fontWeight: 700}}>Stagnant Water Matrix</div>
            <div style={{height: 8, borderRadius: 8, background: C.soft, marginTop: 8, overflow: 'hidden'}}>
              <div style={{width: `${water}%`, height: '100%', borderRadius: 8, background: `linear-gradient(90deg,${C.blue},#60A5FA)`}} />
            </div>
          </div>
          <span style={mono(28, 700, C.blue)}>{Math.round(water)}%</span>
        </div>
      </Abs>
      <Abs y={566} h={108} style={{display: 'flex', gap: 12}}>
        {[
          {icon: 'thermometer' as IconName, label: 'Surface Temp', v: `${temp.toFixed(1)}°C`, src: 'Sentinel-3 LST', c: C.crimson, bg: '#FEE2E2'},
          {icon: 'rain' as IconName, label: 'Rainfall · 72h', v: `${rain.toFixed(1)} mm`, src: 'GPM IMERG', c: C.blue, bg: '#DBEAFE'},
        ].map((m, i) => (
          <div key={m.label} style={{...card, flex: 1, padding: 14, boxSizing: 'border-box', ...rise(f, tel - 4 + i * 6, 24)}}>
            <div style={{display: 'flex', alignItems: 'center', gap: 8}}>
              <IconBubble name={m.icon} color={m.c} bg={m.bg} size={32} icon={17} />
              <span style={{fontSize: 14, color: C.muted, fontWeight: 700}}>{m.label}</span>
            </div>
            <div style={{...mono(27, 700, C.ink), marginTop: 8}}>{m.v}</div>
            <div style={{fontSize: 12, color: C.muted, fontWeight: 600, fontFamily: FONT.mono}}>{m.src}</div>
          </div>
        ))}
      </Abs>
      {/* Map thumbnail — expands into the GIS screen */}
      <div
        style={{
          position: 'absolute',
          left: THUMB.x,
          top: THUMB.y,
          width: THUMB.w,
          height: THUMB.h,
          borderRadius: THUMB.r,
          overflow: 'hidden',
          boxShadow: '0 12px 28px -14px rgba(20,20,19,.4)',
          ...rise(f, tel + 20, 24),
        }}
      >
        <div
          style={{
            position: 'absolute',
            left: 0,
            top: THUMB.h / 2 - (SH * THUMB_K) / 2,
            width: SW,
            height: SH,
            transformOrigin: '0 0',
            transform: `scale(${THUMB_K})`,
          }}
        >
          <MapViewport f={f} pan={PAN0} />
        </div>
        <div
          style={{
            position: 'absolute',
            inset: 0,
            background: 'linear-gradient(90deg, rgba(20,20,19,0.75), rgba(20,20,19,0.05) 75%)',
            padding: '18px 18px',
            color: '#fff',
          }}
        >
          <div style={{fontSize: 13, fontWeight: 700, opacity: 0.8, letterSpacing: 1}}>GEO-TAGGED</div>
          <div style={{fontSize: 17, fontWeight: 800, marginTop: 3}}>Ward 14 · Anand Vihar</div>
          <div style={{fontSize: 13.5, fontWeight: 600, marginTop: 4, display: 'flex', alignItems: 'center', gap: 6}}>
            Open risk map <Icon name="arrowRight" size={15} color="#fff" stroke={2.6} />
          </div>
        </div>
      </div>
    </div>
  );
};

/* ------------------------------------------------------------------ */
/* Scene 4 — GIS Risk Map                                              */
/* ------------------------------------------------------------------ */

export const MapScreen: React.FC<{f: number; chrome: number}> = ({f, chrome}) => {
  const p = sp(f, T.map.pan, {damping: 26, stiffness: 22, mass: 1});
  const drift = Math.sin(f / 80) * 8;
  const pan: Pan = {x: lerp(PAN0.x, PAN1.x, p) + drift, y: lerp(PAN0.y, PAN1.y, p), z: lerp(PAN0.z, PAN1.z, p)};
  const sheet = sp(f, T.map.sheet);
  const bi = tick(f, T.map.sheet + 8, 0, 34);
  return (
    <div style={{position: 'absolute', inset: 0, fontFamily: FONT.sans}}>
      <MapViewport f={f} pan={pan} pinsFrom={T.map.pins[0]} />
      <div style={{opacity: chrome}}>
        <Abs
          y={58}
          h={54}
          style={{
            background: C.card,
            borderRadius: 18,
            display: 'flex',
            alignItems: 'center',
            gap: 10,
            padding: '0 14px',
            boxSizing: 'border-box',
            boxShadow: '0 10px 24px -12px rgba(20,20,19,.35)',
            ...rise(f, T.T.scanToMap + 20, 16),
          }}
        >
          <Icon name="search" size={20} color={C.muted} />
          <span style={{fontSize: 15.5, fontWeight: 700, color: C.ink, flex: 1}}>Ward 14 · Anand Vihar, Chandigarh</span>
          <IconBubble name="layers" color={C.ink} bg={C.soft} size={34} icon={18} />
        </Abs>
        <Abs y={122} h={34} style={{display: 'flex', gap: 8, ...rise(f, T.T.scanToMap + 28, 16)}}>
          <Chip color="#fff" bg={C.crimson} style={{boxShadow: '0 6px 14px -6px rgba(220,38,38,.6)'}}>
            <Dot color="#fff" size={7} f={f} /> Heatmap
          </Chip>
          <Chip color={C.blue} bg={C.card}>
            <Dot color={C.blue} size={7} /> Inspectors 6
          </Chip>
          <Chip color={C.ink} bg={C.card}>
            ◆ Breeding sites 23
          </Chip>
        </Abs>
      </div>
      {/* Ward risk summary sheet */}
      <Abs
        x={12}
        w={SW - 24}
        y={SH - NAV_H - 12 - 272}
        h={272}
        style={{
          ...card,
          borderRadius: 26,
          padding: '10px 18px 16px',
          boxSizing: 'border-box',
          transform: `translateY(${(1 - sheet) * 320}px)`,
        }}
      >
        <div style={{width: 44, height: 5, borderRadius: 5, background: C.line, margin: '0 auto 10px'}} />
        <div style={{display: 'flex', alignItems: 'center'}}>
          <div style={{flex: 1}}>
            <div style={{fontSize: 12.5, fontWeight: 800, color: C.muted, letterSpacing: 1.4}}>WARD RISK SUMMARY</div>
            <div style={{fontSize: 21, fontWeight: 800, color: C.ink, marginTop: 2}}>Ward 14 · Anand Vihar</div>
          </div>
          <Chip color="#fff" bg={C.crimson}>
            <Icon name="alert" size={14} color="#fff" stroke={2.6} /> Critical
          </Chip>
        </div>
        <div style={{display: 'flex', alignItems: 'flex-end', gap: 10, marginTop: 10}}>
          <span style={{fontSize: 15, color: C.muted, fontWeight: 700, marginBottom: 7}}>Breteau Index</span>
          <span style={{...mono(42, 700, C.crimson), lineHeight: 1}}>{bi.toFixed(1)}</span>
          <span style={{fontSize: 14, fontWeight: 800, color: C.crimson, marginBottom: 7}}>• Critical</span>
        </div>
        <div style={{display: 'flex', gap: 10, marginTop: 12}}>
          {[
            ['House Index', `${tick(f, T.map.sheet + 14, 0, 14.2).toFixed(1)}%`],
            ['Container Idx', `${tick(f, T.map.sheet + 18, 0, 28.6).toFixed(1)}%`],
            ['Inspectors', `${Math.round(tick(f, T.map.sheet + 22, 0, 6))} live`],
          ].map(([l, v]) => (
            <div key={l} style={{flex: 1, background: C.soft, borderRadius: 14, padding: '9px 10px'}}>
              <div style={{fontSize: 12, color: C.muted, fontWeight: 700}}>{l}</div>
              <div style={mono(18, 700)}>{v}</div>
            </div>
          ))}
        </div>
        <div
          style={{
            marginTop: 12,
            height: 46,
            borderRadius: 14,
            background: C.ink,
            color: '#fff',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: 8,
            fontSize: 15.5,
            fontWeight: 800,
          }}
        >
          <Icon name="truck" size={18} color="#fff" /> Dispatch fogging van
        </div>
      </Abs>
    </div>
  );
};

/* ------------------------------------------------------------------ */
/* Scene 5 — Longitudinal Stats bento                                  */
/* ------------------------------------------------------------------ */

const BI = [8.2, 11.4, 13.9, 17.6, 21.3, 25.8, 30.1, 34.0];
const BASE = [9, 10, 11.5, 12.5, 13.5, 14.5, 15, 15.5];

export const StatsScreen: React.FC<{f: number}> = ({f}) => {
  const t0 = T.T.mapToStats + 10;
  const ch = T.stats.chart;
  const cw = 344;
  const chH = 118;
  const X = (i: number) => 12 + i * ((cw - 24) / 7);
  const Y = (v: number) => chH - (v / 40) * (chH - 8);
  const line = BI.map((v, i) => `${i ? 'L' : 'M'}${X(i)} ${Y(v)}`).join(' ');
  const base = BASE.map((v, i) => `${i ? 'L' : 'M'}${X(i)} ${Y(v)}`).join(' ');
  const area = `${line} L ${X(7)} ${chH} L ${X(0)} ${chH} Z`;
  const draw = sp(f, ch, {damping: 26, stiffness: 40, mass: 1});
  const hi = tick(f, ch + 20, 0, 14.2);
  const ci = tick(f, ch + 28, 0, 28.6);
  const R = 36;
  const circ = 2 * Math.PI * R;
  const evals = [
    {k: 'BI 34.0 ≥ 20', d: 'Outbreak threshold exceeded', c: C.crimson, bg: '#FEE2E2'},
    {k: 'HI 14.2% ≥ 10%', d: 'High transmission risk', c: C.amber, bg: '#FEF3C7'},
    {k: 'CI 28.6% ≥ 20%', d: 'Priority source reduction', c: C.crimson, bg: '#FEE2E2'},
  ];
  return (
    <div style={{position: 'absolute', inset: 0, background: C.screen, fontFamily: FONT.sans}}>
      <ScreenHeader
        f={f}
        at={t0}
        title="Longitudinal Indices"
        sub="Ward 14 · Anand Vihar · Monsoon 2026"
        right={<Chip color={C.blue} bg="#DBEAFE">W28–W35</Chip>}
      />
      {/* Trend card */}
      <Abs y={124} h={238} style={{...card, padding: '14px 18px', boxSizing: 'border-box', ...rise(f, t0 + 6, 26)}}>
        <div style={{display: 'flex', alignItems: 'center'}}>
          <div style={{flex: 1}}>
            <div style={{fontSize: 15, fontWeight: 700, color: C.muted}}>Breteau Index trend</div>
            <div style={{display: 'flex', alignItems: 'baseline', gap: 8}}>
              <span style={mono(32, 700)}>{tick(f, ch, 8.2, 34).toFixed(1)}</span>
              <span style={{fontSize: 13.5, fontWeight: 800, color: C.crimson}}>↑ 315% vs W28</span>
            </div>
          </div>
          <div style={{display: 'flex', flexDirection: 'column', gap: 4, fontSize: 12, fontWeight: 700, color: C.muted}}>
            <span style={{display: 'flex', alignItems: 'center', gap: 6}}>
              <span style={{width: 16, height: 3, background: C.blue, borderRadius: 2}} /> 2026
            </span>
            <span style={{display: 'flex', alignItems: 'center', gap: 6}}>
              <span style={{width: 16, height: 0, borderTop: `2px dashed ${C.faint}`}} /> 5-yr baseline
            </span>
          </div>
        </div>
        <svg width={cw} height={chH + 26} style={{marginTop: 8, overflow: 'visible'}}>
          <defs>
            <linearGradient id="area" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0" stopColor="rgba(220,38,38,0.22)" />
              <stop offset="1" stopColor="rgba(37,99,235,0.02)" />
            </linearGradient>
            <linearGradient id="lineg" x1="0" y1="0" x2="1" y2="0">
              <stop offset="0" stopColor={C.blue} />
              <stop offset="1" stopColor={C.crimson} />
            </linearGradient>
          </defs>
          {[0, 10, 20, 30, 40].map((v) => (
            <line key={v} x1={0} x2={cw} y1={Y(v)} y2={Y(v)} stroke={C.line} strokeWidth={1} />
          ))}
          <line x1={0} x2={cw} y1={Y(20)} y2={Y(20)} stroke={C.crimson} strokeDasharray="5 5" strokeWidth={1.5} opacity={0.8} />
          <text x={cw - 2} y={Y(20) - 6} textAnchor="end" style={{fontFamily: FONT.mono, fontSize: 11, fill: C.crimson, fontWeight: 700}}>
            WHO threshold · 20
          </text>
          <path d={area} fill="url(#area)" opacity={clamp(draw)} />
          <path d={base} fill="none" stroke={C.faint} strokeWidth={2} strokeDasharray="4 5" />
          <path
            d={line}
            fill="none"
            stroke="url(#lineg)"
            strokeWidth={3.5}
            strokeLinecap="round"
            strokeLinejoin="round"
            pathLength={1}
            strokeDasharray={1}
            strokeDashoffset={1 - clamp(draw)}
          />
          {BI.map((v, i) => {
            const pp = sp(f, ch + i * 7);
            return <circle key={i} cx={X(i)} cy={Y(v)} r={4.5 * pp} fill="#fff" stroke={i > 4 ? C.crimson : C.blue} strokeWidth={2.5} />;
          })}
          {BI.map((_, i) => (
            <text key={i} x={X(i)} y={chH + 20} textAnchor="middle" style={{fontFamily: FONT.mono, fontSize: 11.5, fill: C.muted, fontWeight: 500}}>
              {`W${28 + i}`}
            </text>
          ))}
        </svg>
      </Abs>
      {/* HI + CI */}
      <Abs y={374} h={176} style={{display: 'flex', gap: 12}}>
        <div style={{...card, flex: 1, padding: 14, boxSizing: 'border-box', ...rise(f, t0 + 14, 26)}}>
          <div style={{fontSize: 14, fontWeight: 700, color: C.muted}}>House Index</div>
          <div style={{display: 'flex', alignItems: 'center', gap: 10, marginTop: 8}}>
            <svg width={86} height={86} viewBox="0 0 86 86">
              <circle cx={43} cy={43} r={R} fill="none" stroke={C.soft} strokeWidth={10} />
              <circle
                cx={43}
                cy={43}
                r={R}
                fill="none"
                stroke={C.amber}
                strokeWidth={10}
                strokeLinecap="round"
                strokeDasharray={`${(hi / 30) * circ} ${circ}`}
                transform="rotate(-90 43 43)"
              />
              <text x={43} y={49} textAnchor="middle" style={{fontFamily: FONT.mono, fontSize: 17, fontWeight: 700, fill: C.ink}}>
                {`${hi.toFixed(1)}%`}
              </text>
            </svg>
          </div>
          <Chip color={C.amber} bg="#FEF3C7" style={{marginTop: 10, fontSize: 12}}>
            &gt; 10% · High
          </Chip>
        </div>
        <div style={{...card, flex: 1, padding: 14, boxSizing: 'border-box', ...rise(f, t0 + 18, 26)}}>
          <div style={{fontSize: 14, fontWeight: 700, color: C.muted}}>Container Index</div>
          <div style={{...mono(32, 700, C.crimson), marginTop: 8}}>{ci.toFixed(1)}%</div>
          <div style={{position: 'relative', height: 12, borderRadius: 8, background: C.soft, marginTop: 10}}>
            <div style={{width: `${(ci / 50) * 100}%`, height: '100%', borderRadius: 8, background: C.crimson}} />
            <div style={{position: 'absolute', left: '40%', top: -4, width: 2, height: 20, background: C.ink}} />
          </div>
          <div style={{...mono(12, 500, C.muted), marginTop: 8}}>57 / 199 positive</div>
          <Chip color={C.crimson} bg="#FEE2E2" style={{marginTop: 8, fontSize: 12}}>
            &gt; 20% · High
          </Chip>
        </div>
      </Abs>
      {/* Standards */}
      <Abs y={562} h={228} style={{...card, padding: '14px 16px', boxSizing: 'border-box', ...rise(f, t0 + 22, 26)}}>
        <div style={{display: 'flex', alignItems: 'center', gap: 8}}>
          <Icon name="shieldCheck" size={20} color={C.ink} />
          <span style={{fontSize: 16, fontWeight: 800, color: C.ink}}>WHO / NCVBDC Evaluation</span>
        </div>
        {evals.map((e, i) => {
          const at = T.stats.evalRows[i];
          const p = sp(f, at);
          return (
            <div
              key={e.k}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: 10,
                marginTop: 11,
                padding: '9px 12px',
                borderRadius: 14,
                background: e.bg,
                opacity: clamp(p * 1.4),
                transform: `translateX(${(1 - p) * 40}px)`,
              }}
            >
              <Icon name="alert" size={18} color={e.c} stroke={2.4} />
              <span style={{...mono(14, 700, e.c)}}>{e.k}</span>
              <span style={{fontSize: 13.5, fontWeight: 700, color: C.ink, marginLeft: 'auto'}}>{e.d}</span>
            </div>
          );
        })}
      </Abs>
    </div>
  );
};

/* ------------------------------------------------------------------ */
/* Scene 6 — Centers & Vans                                            */
/* ------------------------------------------------------------------ */

const ROUTE: [number, number][] = [
  [16, 96],
  [84, 96],
  [84, 54],
  [176, 54],
  [176, 86],
  [262, 86],
  [262, 30],
  [334, 30],
];

const along = (pts: [number, number][], t: number): [number, number] => {
  const segs = pts.slice(1).map((p, i) => Math.hypot(p[0] - pts[i][0], p[1] - pts[i][1]));
  const total = segs.reduce((a, b) => a + b, 0);
  let d = clamp(t) * total;
  for (let i = 0; i < segs.length; i++) {
    if (d <= segs[i]) {
      const k = d / segs[i];
      return [lerp(pts[i][0], pts[i + 1][0], k), lerp(pts[i][1], pts[i + 1][1], k)];
    }
    d -= segs[i];
  }
  return pts[pts.length - 1];
};

export const CentersVansScreen: React.FC<{f: number}> = ({f}) => {
  const t0 = T.T.statsToCenters + 10;
  const travel = 0.12 + 0.62 * sp(f, t0 + 10, {damping: 40, stiffness: 9, mass: 1});
  const [vx, vy] = along(ROUTE, travel);
  const routeD = ROUTE.map((p, i) => `${i ? 'L' : 'M'}${p[0]} ${p[1]}`).join(' ');
  const lat = 30.7334 + travel * 0.0042 + Math.sin(f / 9) * 0.00002;
  const lon = 76.7798 + travel * 0.0031;
  const tap = T.centers.tapCall;
  const vans = [
    {id: 'Van DL-1V-4920', drv: 'Driver: Ramesh Kumar', st: 'En route · ETA 6 min', c: '#047857', bg: '#D1FAE5', ic: C.emerald},
    {id: 'Van CH-01-GA-2231', drv: 'Driver: Sukhvinder Singh', st: 'Fogging · Sec 22', c: C.blue, bg: '#DBEAFE', ic: C.blue},
  ];
  const centers = [
    {n: 'GMSH-16', d: 'Govt. Multi Specialty Hospital, Sec 16', km: '1.2 km · 4 min', beds: '18 beds free'},
    {n: 'Civil Disp. 19', d: 'Civil Dispensary, Sector 19-B', km: '2.1 km · 7 min', beds: 'OPD open'},
  ];
  return (
    <div style={{position: 'absolute', inset: 0, background: C.screen, fontFamily: FONT.sans}}>
      <ScreenHeader
        f={f}
        at={t0}
        title="Dispatch & Care"
        sub="MCC fleet · accredited centres"
        right={
          <Chip color="#047857" bg="#D1FAE5">
            <Dot color={C.emerald} size={7} f={f} /> 4 live
          </Chip>
        }
      />
      <Abs y={124} h={196} style={{...card, padding: '12px 14px', boxSizing: 'border-box', ...rise(f, t0 + 4, 26)}}>
        <div style={{display: 'flex', alignItems: 'center', gap: 8}}>
          <Icon name="activity" size={18} color={C.emerald} stroke={2.4} />
          <span style={{fontSize: 15.5, fontWeight: 800, color: C.ink}}>Live patrol telemetry</span>
          <span style={{marginLeft: 'auto', ...mono(13, 600, C.muted)}}>{`${Math.round(28 + Math.sin(f / 20) * 6)} km/h`}</span>
        </div>
        <svg width={350} height={112} style={{marginTop: 8, borderRadius: 14, background: '#F3F1EA', display: 'block'}}>
          {[0, 1, 2, 3, 4, 5].map((i) => (
            <line key={`v${i}`} x1={i * 70} x2={i * 70} y1={0} y2={112} stroke="#fff" strokeWidth={8} />
          ))}
          {[0, 1, 2].map((i) => (
            <line key={`h${i}`} x1={0} x2={350} y1={i * 50 + 10} y2={i * 50 + 10} stroke="#fff" strokeWidth={8} />
          ))}
          <path d={routeD} fill="none" stroke="#A7F3D0" strokeWidth={6} strokeLinecap="round" strokeLinejoin="round" />
          <path
            d={routeD}
            fill="none"
            stroke={C.emerald}
            strokeWidth={6}
            strokeLinecap="round"
            strokeLinejoin="round"
            pathLength={1}
            strokeDasharray={1}
            strokeDashoffset={1 - travel}
          />
          <circle cx={334} cy={30} r={9} fill={C.crimson} stroke="#fff" strokeWidth={3} />
          <circle cx={vx} cy={vy} r={16} fill={C.emerald} opacity={0.22 + 0.1 * Math.sin(f / 6)} />
          <circle cx={vx} cy={vy} r={9} fill={C.emerald} stroke="#fff" strokeWidth={3} />
        </svg>
        <div style={{...mono(13.5, 600, C.ink), marginTop: 8, display: 'flex', justifyContent: 'space-between'}}>
          <span>{`${lat.toFixed(4)}° N  ${lon.toFixed(4)}° E`}</span>
          <span style={{color: C.emerald}}>GPS ±3 m</span>
        </div>
      </Abs>
      <Abs y={332} style={{fontSize: 17, fontWeight: 800, color: C.ink, ...rise(f, t0 + 8, 14)}}>
        Active MCC fleet
      </Abs>
      {vans.map((v, i) => (
        <Abs
          key={v.id}
          y={362 + i * 82}
          h={72}
          style={{
            ...card,
            borderRadius: 18,
            display: 'flex',
            alignItems: 'center',
            gap: 12,
            padding: '0 14px',
            boxSizing: 'border-box',
            ...rise(f, T.centers.vans[i], 26),
          }}
        >
          <IconBubble name="truck" color="#fff" bg={v.ic} size={44} icon={21} />
          <div style={{flex: 1, minWidth: 0}}>
            <div style={{...mono(16, 700), letterSpacing: -0.6}}>{v.id}</div>
            <div style={{fontSize: 14, color: C.muted, fontWeight: 600}}>{v.drv}</div>
          </div>
          <Chip color={v.c} bg={v.bg} style={{fontSize: 12}}>
            {v.st}
          </Chip>
        </Abs>
      ))}
      <Abs y={534} style={{fontSize: 17, fontWeight: 800, color: C.ink, ...rise(f, t0 + 20, 14)}}>
        Nearest accredited centres
      </Abs>
      <Abs y={564} h={226} style={{display: 'flex', gap: 12}}>
        {centers.map((c, i) => (
          <div
            key={c.n}
            style={{
              ...card,
              flex: 1,
              padding: 13,
              boxSizing: 'border-box',
              display: 'flex',
              flexDirection: 'column',
              position: 'relative',
              overflow: 'hidden',
              ...rise(f, t0 + 24 + i * 6, 30),
            }}
          >
            <IconBubble name="plus" color={C.crimson} bg="#FEE2E2" size={38} icon={20} />
            <div style={{fontSize: 16.5, fontWeight: 800, color: C.ink, marginTop: 8}}>{c.n}</div>
            <div style={{fontSize: 12.5, color: C.muted, fontWeight: 600, lineHeight: 1.3, marginTop: 2, height: 34}}>{c.d}</div>
            <div style={{...mono(13, 600), marginTop: 6}}>{c.km}</div>
            <div style={{fontSize: 12.5, color: '#047857', fontWeight: 800, marginTop: 2}}>{c.beds}</div>
            <div style={{display: 'flex', gap: 6, marginTop: 'auto'}}>
              <div
                style={{
                  flex: 1,
                  height: 36,
                  borderRadius: 11,
                  background: C.blue,
                  color: '#fff',
                  fontSize: 13.5,
                  fontWeight: 800,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  gap: 5,
                  transform: i === 0 ? `scale(${1 - 0.1 * press(f, tap)})` : undefined,
                }}
              >
                <Icon name="phone" size={14} color="#fff" stroke={2.4} /> Call
              </div>
              <div
                style={{
                  width: 40,
                  height: 36,
                  borderRadius: 11,
                  border: `1.5px solid ${C.line}`,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                }}
              >
                <Icon name="navigation" size={16} color={C.ink} />
              </div>
            </div>
            {i === 0 && <Ripple f={f} at={tap} x={60} y={196} />}
          </div>
        ))}
      </Abs>
    </div>
  );
};

/* ------------------------------------------------------------------ */
/* Scene 7 — Support & Escalation                                      */
/* ------------------------------------------------------------------ */

export const SupportScreen: React.FC<{f: number}> = ({f}) => {
  const S = T.support;
  const t0 = T.T.centersToSupport + 10;
  const n = f < S.typeStart ? 0 : Math.min(S.text.length, Math.floor((f - S.typeStart) / S.typeInterval) + 1);
  const typing = f >= S.typeStart && f < S.tapSubmit;
  const caret = typing && Math.floor(f / 14) % 2 === 0;
  const submitted = f >= S.tapSubmit + 4;
  const ring = ((f % 60) / 60);
  const ringE = 1 - Math.pow(1 - ring, 3);
  const slaSecs = Math.max(0, 7200 - 18 - Math.max(0, Math.floor((f - S.chips[1]) / 30)));
  const sla = `${String(Math.floor(slaSecs / 3600)).padStart(2, '0')}:${String(Math.floor((slaSecs % 3600) / 60)).padStart(2, '0')}:${String(slaSecs % 60).padStart(2, '0')}`;
  const chips = [
    {l: 'Logged', c: C.ink, bg: C.soft, at: S.tapSubmit + 6},
    {l: 'Dispatch Sent', c: '#047857', bg: '#D1FAE5', at: S.chips[0]},
    {l: 'Pending CMO', c: '#B45309', bg: '#FEF3C7', at: S.chips[1]},
  ];
  return (
    <div style={{position: 'absolute', inset: 0, background: C.screen, fontFamily: FONT.sans}}>
      <ScreenHeader f={f} at={t0} title="Support & Escalation" sub="24×7 outbreak response desk" />
      <Abs
        y={124}
        h={138}
        style={{
          borderRadius: 24,
          background: 'linear-gradient(140deg,#EF4444,#B91C1C)',
          color: '#fff',
          padding: 18,
          boxSizing: 'border-box',
          display: 'flex',
          alignItems: 'center',
          gap: 16,
          boxShadow: '0 20px 40px -18px rgba(220,38,38,0.7)',
          ...rise(f, t0 + 4, 26),
        }}
      >
        <div style={{position: 'relative', width: 66, height: 66, flexShrink: 0}}>
          <div
            style={{
              position: 'absolute',
              inset: 0,
              borderRadius: 66,
              border: '3px solid #fff',
              opacity: 1 - ringE,
              transform: `scale(${1 + ringE * 0.6})`,
            }}
          />
          <div
            style={{
              position: 'absolute',
              inset: 0,
              borderRadius: 66,
              background: '#fff',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <Icon name="phone" size={28} color={C.crimson} stroke={2.4} />
          </div>
        </div>
        <div>
          <div style={{fontSize: 13, fontWeight: 800, letterSpacing: 1.4, opacity: 0.85}}>SOS HOTLINE</div>
          <div style={{fontSize: 21, fontWeight: 800, letterSpacing: -0.4}}>Outbreak Emergency</div>
          <div style={{fontSize: 14, fontWeight: 600, opacity: 0.9, marginTop: 3}}>Hold to connect · avg pickup 8 s</div>
        </div>
      </Abs>
      <Abs y={276} h={310} style={{...card, padding: '14px 16px', boxSizing: 'border-box', ...rise(f, t0 + 10, 26)}}>
        <div style={{fontSize: 17, fontWeight: 800, color: C.ink}}>Log field issue</div>
        {[
          ['Category', 'Breeding site · Construction'],
          ['Location', 'Ward 14 · Anand Vihar'],
        ].map(([l, v]) => (
          <div
            key={l}
            style={{
              marginTop: 10,
              height: 46,
              borderRadius: 13,
              border: `1.5px solid ${C.line}`,
              display: 'flex',
              alignItems: 'center',
              padding: '0 12px',
              gap: 8,
            }}
          >
            <span style={{fontSize: 12.5, color: C.muted, fontWeight: 700, width: 70}}>{l}</span>
            <span style={{fontSize: 15, color: C.ink, fontWeight: 700, flex: 1}}>{v}</span>
            <Icon name="chevronDown" size={18} color={C.muted} />
          </div>
        ))}
        <div
          style={{
            marginTop: 10,
            height: 66,
            borderRadius: 13,
            border: `1.5px solid ${typing ? C.blue : C.line}`,
            boxShadow: typing ? '0 0 0 4px rgba(37,99,235,0.1)' : 'none',
            padding: '9px 12px',
            fontSize: 15,
            fontWeight: 600,
            color: C.ink,
            lineHeight: 1.35,
            boxSizing: 'border-box',
          }}
        >
          {n === 0 ? <span style={{color: C.faint}}>Describe the issue…</span> : S.text.slice(0, n)}
          <span style={{opacity: caret ? 1 : 0, color: C.blue}}>|</span>
        </div>
        <div style={{display: 'flex', gap: 8, marginTop: 10, alignItems: 'center'}}>
          <Chip color={C.ink} bg={C.soft}>
            <Icon name="paperclip" size={13} color={C.ink} /> IMG_2041.jpg
          </Chip>
          <Chip color="#047857" bg="#D1FAE5">
            <Icon name="pin" size={13} color="#047857" /> GPS ✓
          </Chip>
          <div
            style={{
              marginLeft: 'auto',
              height: 40,
              padding: '0 14px',
              borderRadius: 12,
              background: submitted ? C.emerald : C.blue,
              color: '#fff',
              display: 'flex',
              alignItems: 'center',
              gap: 6,
              fontSize: 14,
              fontWeight: 800,
              position: 'relative',
              overflow: 'hidden',
              transform: `scale(${1 - 0.1 * press(f, S.tapSubmit)})`,
            }}
          >
            <Icon name={submitted ? 'check' : 'send'} size={15} color="#fff" stroke={2.6} /> {submitted ? 'Escalated' : 'Escalate'}
            <Ripple f={f} at={S.tapSubmit} x={50} y={20} color="#fff" />
          </div>
        </div>
      </Abs>
      <Abs y={598} h={192} style={{...card, padding: '14px 16px', boxSizing: 'border-box', ...rise(f, t0 + 16, 26)}}>
        <div style={{display: 'flex', alignItems: 'center'}}>
          <span style={{fontSize: 16, fontWeight: 800, color: C.ink, flex: 1}}>Escalation status</span>
          <span style={mono(13, 600, C.muted)}>#AD-2026-0417</span>
        </div>
        <div style={{display: 'flex', gap: 7, marginTop: 14, flexWrap: 'wrap'}}>
          {chips.map((c) => {
            const p = sp(f, c.at);
            const on = f >= c.at;
            return (
              <div key={c.l} style={{transform: `scale(${on ? 0.6 + 0.4 * p : 1})`, opacity: on ? 1 : 0.35}}>
                <Chip color={on ? c.c : C.muted} bg={on ? c.bg : C.soft} style={{fontSize: 13}}>
                  {c.l === 'Pending CMO' && on ? <Dot color={C.amber} size={7} f={f} /> : <Icon name="check" size={13} color={on ? c.c : C.muted} stroke={3} />}
                  {c.l}
                </Chip>
              </div>
            );
          })}
        </div>
        <div style={{display: 'flex', alignItems: 'center', gap: 10, marginTop: 16}}>
          <Icon name="clock" size={20} color={C.amber} />
          <span style={{fontSize: 14, fontWeight: 700, color: C.muted}}>SLA remaining</span>
          <span style={{...mono(22, 700, f >= S.chips[1] ? C.ink : C.faint), marginLeft: 'auto'}}>{f >= S.chips[1] ? sla : '--:--:--'}</span>
        </div>
        <div style={{height: 8, borderRadius: 8, background: C.soft, marginTop: 10, overflow: 'hidden'}}>
          <div style={{width: `${100 * smooth(f, S.chips[1])}%`, height: '100%', background: `linear-gradient(90deg,${C.emerald},${C.amber})`, borderRadius: 8}} />
        </div>
      </Abs>
    </div>
  );
};
