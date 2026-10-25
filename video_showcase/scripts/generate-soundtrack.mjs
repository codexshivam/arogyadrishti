import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Read timeline
const timelinePath = path.resolve(__dirname, '../src/timeline.json');
const timeline = JSON.parse(fs.readFileSync(timelinePath, 'utf8'));

const SAMPLE_RATE = 44100;
const FPS = timeline.fps || 60;
const TOTAL_FRAMES = timeline.durationInFrames || 3600; // 60.0s
const TOTAL_SECONDS = TOTAL_FRAMES / FPS; // 60.0s
const TOTAL_SAMPLES = Math.floor(SAMPLE_RATE * TOTAL_SECONDS);

// Stereo float buffer: L, R
const bufferL = new Float32Array(TOTAL_SAMPLES);
const bufferR = new Float32Array(TOTAL_SAMPLES);

const frameToSample = (f) => Math.floor((f / FPS) * SAMPLE_RATE);

function addSample(idx, leftVal, rightVal) {
  if (idx >= 0 && idx < TOTAL_SAMPLES) {
    bufferL[idx] += leftVal;
    bufferR[idx] += rightVal;
  }
}

// 1. Tactile Key Click / Tap
function playClick(f, pan = 0, pitch = 1800, gain = 0.22) {
  const start = frameToSample(f);
  const dur = Math.floor(SAMPLE_RATE * 0.025);
  for (let i = 0; i < dur; i++) {
    const t = i / SAMPLE_RATE;
    const env = Math.exp(-t * 220);
    const noise = (Math.random() * 2 - 1) * 0.35;
    const tone = Math.sin(2 * Math.PI * pitch * t) * 0.65;
    const s = (noise + tone) * env * gain;
    addSample(start + i, s * (1 - pan * 0.5), s * (1 + pan * 0.5));
  }
}

// 2. Soft Button Pop
function playPop(f, freq = 320, gain = 0.38) {
  const start = frameToSample(f);
  const dur = Math.floor(SAMPLE_RATE * 0.08);
  for (let i = 0; i < dur; i++) {
    const t = i / SAMPLE_RATE;
    const curFreq = freq * (1 - t * 6);
    const env = Math.exp(-t * 55);
    const s = Math.sin(2 * Math.PI * curFreq * t) * env * gain;
    addSample(start + i, s, s);
  }
}

// 3. Smooth Screen Slide Whoosh
function playWhoosh(f, durFrames = 26, gain = 0.32, panDir = 1) {
  const start = frameToSample(f);
  const dur = Math.floor((durFrames / FPS) * SAMPLE_RATE);
  let filterState = 0;
  for (let i = 0; i < dur; i++) {
    const t = i / dur;
    const env = Math.sin(Math.PI * t) ** 1.8;
    const cutoff = 280 + Math.sin(Math.PI * t) * 1400;
    const rc = 1.0 / (2 * Math.PI * cutoff);
    const dt = 1.0 / SAMPLE_RATE;
    const alpha = dt / (rc + dt);

    const white = Math.random() * 2 - 1;
    filterState += alpha * (white - filterState);

    const s = filterState * env * gain;
    const pan = (t * 2 - 1) * panDir;
    addSample(start + i, s * (0.8 - pan * 0.4), s * (0.8 + pan * 0.4));
  }
}

// 4. Harmonic Chime / Ping
function playChime(f, baseFreq = 880, gain = 0.28, decay = 8) {
  const start = frameToSample(f);
  const dur = Math.floor(SAMPLE_RATE * 0.5);
  for (let i = 0; i < dur; i++) {
    const t = i / SAMPLE_RATE;
    const env = Math.exp(-t * decay);
    const s1 = Math.sin(2 * Math.PI * baseFreq * t);
    const s2 = Math.sin(2 * Math.PI * baseFreq * 2.01 * t) * 0.25;
    const val = (s1 + s2) * env * gain;
    addSample(start + i, val * 0.95, val * 1.0);
  }
}

// 5. Digital Radar / Telemetry Bleep
function playRadar(f, freq = 1200, gain = 0.2) {
  const start = frameToSample(f);
  const dur = Math.floor(SAMPLE_RATE * 0.09);
  for (let i = 0; i < dur; i++) {
    const t = i / SAMPLE_RATE;
    const env = Math.exp(-t * 30);
    const val = Math.sin(2 * Math.PI * freq * t) * env * gain;
    addSample(start + i, val, val);
  }
}

// 6. Outro Swell
function playSwell(f, gain = 0.35) {
  const start = frameToSample(f);
  const dur = Math.floor(SAMPLE_RATE * 2.8);
  for (let i = 0; i < dur; i++) {
    const t = i / SAMPLE_RATE;
    const env = t < 0.8 ? (t / 0.8) ** 1.6 : Math.exp(-(t - 0.8) * 1.8);
    const chord =
      Math.sin(2 * Math.PI * 440 * t) * 0.4 +
      Math.sin(2 * Math.PI * 554.37 * t) * 0.3 +
      Math.sin(2 * Math.PI * 659.25 * t) * 0.3 +
      Math.sin(2 * Math.PI * 880 * t) * 0.2;
    const val = chord * env * gain;
    addSample(start + i, val * 0.9, val * 1.05);
  }
}

console.log(`Synthesizing 60-second Foley & sound effects for ${TOTAL_SECONDS}s (${TOTAL_FRAMES} frames)...`);

// --- Foley events from timeline ---
// Auth typing
const digits = timeline.auth.digits || '9915549458';
for (let i = 0; i < digits.length; i++) {
  const f = timeline.auth.typeStart + i * timeline.auth.typeInterval;
  playClick(f, (i % 3 - 1) * 0.2, 1600 + (i % 4) * 80, 0.2);
}

// Tap Send
playPop(timeline.auth.tapSend, 280, 0.4);

// OTP typing
const otp = timeline.auth.otp || '482910';
for (let i = 0; i < otp.length; i++) {
  const f = timeline.auth.otpStart + i * timeline.auth.otpInterval;
  playClick(f, (i % 2 === 0 ? -0.2 : 0.2), 2000 + i * 90, 0.24);
}

// Pipeline steps
const pipe = timeline.auth.pipeline || [240, 280, 320, 360];
const pipeFreqs = [587.33, 659.25, 783.99, 880.00];
pipe.forEach((f, idx) => {
  playChime(f, pipeFreqs[idx % pipeFreqs.length], 0.26, 12);
});

// Auth Success
playChime(timeline.auth.success, 1046.50, 0.38, 7);
playChime(timeline.auth.success + 6, 1318.51, 0.32, 6);

// Transitions whooshes
const T_trans = timeline.T;
playWhoosh(T_trans.authToHome, 28, 0.32, 1);
playWhoosh(T_trans.homeToScan, 28, 0.32, -1);
playWhoosh(T_trans.scanToMap, 30, 0.35, 1);
playWhoosh(T_trans.mapToStats, 28, 0.32, -1);
playWhoosh(T_trans.statsToCenters, 28, 0.32, 1);
playWhoosh(T_trans.centersToSupport, 28, 0.32, -1);
playWhoosh(T_trans.outro, 36, 0.4, 0);

// Home alert pop & scan tap
playPop(timeline.home.alertPop, 300, 0.38);
playPop(timeline.home.tapScan, 340, 0.42);

// Scan detections
const scanBoxes = timeline.scan.boxes || [1000, 1070];
playRadar(scanBoxes[0], 1320, 0.25);
playRadar(scanBoxes[1], 1580, 0.3);

// Map inspector pins
const pins = timeline.map.pins || [1440, 1470, 1500, 1530];
pins.forEach((f, idx) => {
  playChime(f, 987.77 + idx * 110, 0.2, 18);
});

// Stats rows
const evalRows = timeline.stats.evalRows || [1980, 2030, 2080];
evalRows.forEach((f, idx) => {
  playPop(f, 360 + idx * 70, 0.3);
});

// Centers tap call
playPop(timeline.centers.tapCall, 340, 0.38);

// Support typing & submit
const supportText = timeline.support.text || 'Uncovered water tanks at site';
for (let i = 0; i < Math.min(supportText.length, 28); i += 2) {
  const f = timeline.support.typeStart + i * timeline.support.typeInterval;
  playClick(f, (i % 2 === 0 ? 0.15 : -0.15), 1700 + (i % 5) * 60, 0.16);
}
playPop(timeline.support.tapSubmit, 310, 0.42);
playChime(timeline.support.tapSubmit + 6, 880, 0.28, 10);

// Outro lockup swell & final resolution
playSwell(timeline.outro.start, 0.35);
playChime(timeline.outro.logoPop, 523.25, 0.38, 4);
playChime(timeline.outro.title, 659.25, 0.35, 4);
playChime(timeline.outro.subtitle, 1046.50, 0.4, 3);

// --- Minimalist kinetic ambient music bed (BPM 120, warm pulsing Rhodes chords) ---
console.log(`Synthesizing kinetic musical bed (BPM 120, ${TOTAL_SECONDS}s)...`);
const BPM = timeline.bpm || 120;
const BEAT_DUR = 60 / BPM; // 0.5s = 30 frames
const TOTAL_BEATS = Math.floor(TOTAL_SECONDS / BEAT_DUR);

const CHORDS = [
  [174.61, 261.63, 329.63, 392.00], // F3, C4, E4, G4
  [196.00, 261.63, 293.66, 392.00], // G3, C4, D4, G4
  [220.00, 261.63, 329.63, 440.00], // A3, C4, E4, A4
  [164.81, 246.94, 329.63, 392.00], // E3, B3, E4, G4
];

for (let b = 0; b < TOTAL_BEATS; b++) {
  const beatTime = b * BEAT_DUR;
  const startSample = Math.floor(beatTime * SAMPLE_RATE);
  if (startSample >= TOTAL_SAMPLES) break;

  const bar = Math.floor(b / 4);
  const beatInBar = b % 4;
  const chord = CHORDS[bar % CHORDS.length];

  // 1. Warm sub kick on beat 0 and 2
  if (beatInBar === 0 || beatInBar === 2) {
    const kickDur = Math.floor(SAMPLE_RATE * 0.2);
    for (let i = 0; i < kickDur; i++) {
      const t = i / SAMPLE_RATE;
      const kf = 115 * Math.exp(-t * 26) + 40;
      const env = Math.exp(-t * 14);
      const val = Math.sin(2 * Math.PI * kf * t) * env * 0.26;
      addSample(startSample + i, val, val);
    }
  }

  // 2. Soft kinetic shaker / hi-hat tick every 8th note
  for (let sub = 0; sub < 2; sub++) {
    const subSample = startSample + Math.floor((sub * 0.5 * BEAT_DUR) * SAMPLE_RATE);
    const hatDur = Math.floor(SAMPLE_RATE * 0.024);
    for (let i = 0; i < hatDur; i++) {
      const t = i / SAMPLE_RATE;
      const env = Math.exp(-t * 150);
      const val = (Math.random() * 2 - 1) * env * (sub === 0 ? 0.055 : 0.032);
      addSample(subSample + i, val * 0.9, val * 1.1);
    }
  }

  // 3. Gentle harmonic pluck note on offbeats
  if (beatInBar === 1 || beatInBar === 3 || beatInBar === 0) {
    const noteFreq = chord[(b + (beatInBar === 1 ? 2 : 1)) % chord.length];
    const noteDur = Math.floor(SAMPLE_RATE * 0.35);
    for (let i = 0; i < noteDur; i++) {
      const t = i / SAMPLE_RATE;
      const env = Math.exp(-t * 9.0);
      const val = Math.sin(2 * Math.PI * noteFreq * t) * env * 0.07;
      addSample(startSample + i, val * (beatInBar === 1 ? 0.8 : 1.2), val * (beatInBar === 1 ? 1.2 : 0.8));
    }
  }
}

// Master fade out in last 2.0 seconds (frames 3480 - 3600)
const fadeStartSample = frameToSample(TOTAL_FRAMES - 120);
for (let i = fadeStartSample; i < TOTAL_SAMPLES; i++) {
  const fade = (TOTAL_SAMPLES - i) / (TOTAL_SAMPLES - fadeStartSample);
  bufferL[i] *= fade;
  bufferR[i] *= fade;
}

// Normalize and write WAV file
console.log('Normalizing and encoding 16-bit stereo WAV...');
let maxPeak = 0;
for (let i = 0; i < TOTAL_SAMPLES; i++) {
  const absL = Math.abs(bufferL[i]);
  const absR = Math.abs(bufferR[i]);
  if (absL > maxPeak) maxPeak = absL;
  if (absR > maxPeak) maxPeak = absR;
}

const targetPeak = 0.88;
const scale = maxPeak > 0 ? targetPeak / maxPeak : 1;

const wavHeaderSize = 44;
const pcmByteLength = TOTAL_SAMPLES * 2 * 2;
const totalFileSize = wavHeaderSize + pcmByteLength;
const wavBuffer = Buffer.alloc(totalFileSize);

// RIFF header
wavBuffer.write('RIFF', 0);
wavBuffer.writeUInt32LE(totalFileSize - 8, 4);
wavBuffer.write('WAVE', 8);

// "fmt " subchunk
wavBuffer.write('fmt ', 12);
wavBuffer.writeUInt32LE(16, 16);
wavBuffer.writeUInt16LE(1, 20);
wavBuffer.writeUInt16LE(2, 22);
wavBuffer.writeUInt32LE(SAMPLE_RATE, 24);
wavBuffer.writeUInt32LE(SAMPLE_RATE * 2 * 2, 28);
wavBuffer.writeUInt16LE(4, 32);
wavBuffer.writeUInt16LE(16, 34);

// "data" subchunk
wavBuffer.write('data', 36);
wavBuffer.writeUInt32LE(pcmByteLength, 40);

let offset = 44;
for (let i = 0; i < TOTAL_SAMPLES; i++) {
  const sL = Math.max(-1, Math.min(1, bufferL[i] * scale));
  const sR = Math.max(-1, Math.min(1, bufferR[i] * scale));
  const intL = sL < 0 ? Math.floor(sL * 32768) : Math.floor(sL * 32767);
  const intR = sR < 0 ? Math.floor(sR * 32768) : Math.floor(sR * 32767);
  wavBuffer.writeInt16LE(intL, offset);
  wavBuffer.writeInt16LE(intR, offset + 2);
  offset += 4;
}

const outputPath = path.resolve(__dirname, '../src/Soundtrack.wav');
fs.writeFileSync(outputPath, wavBuffer);
console.log(`Successfully generated ${outputPath} (${(wavBuffer.length / (1024 * 1024)).toFixed(2)} MB, ${TOTAL_SECONDS}s @ 44.1kHz 16-bit stereo)`);
