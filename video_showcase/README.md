# NidanIQ — 1-Minute Programmatic Motion Showcase Video

Programmatic motion graphics showcase built with **Remotion 4**, **React 18**, and **TypeScript**, reproducing the NidanIQ mobile surveillance application in 100% custom layered vector UI components with spring physics and synchronized procedural Foley audio.

## Video Specifications
- **4K Output**: `out/nidaniq_showcase_4k.mp4` (3840×2160 @ 60 FPS, CRF 18, YUV420p)
- **1080p Output**: `out/nidaniq_showcase.mp4` (1920×1080 @ 60 FPS)
- **Duration**: `00:01:00.00` (3,600 frames @ 60 FPS, 1 minute)
- **Video Codec**: H.264 High Profile, progressive (`yuv420p`)
- **Audio Codec**: AAC stereo (48,000 Hz, 320 kbps)
- **Canvas Background**: Pure complete white `#FFFFFF` (clean opening frames 0–45)
- **Typography**: Poppins with generous line spacing
  - **Main Titles**: `#A12C18`
  - **Subtitles**: `#BF5341`
- **Closing Card**: Full red `#EE211E` background with centered white "NidanIQ" logo text matching the native Android app launch splash screen.

## Scene Progression & Motion Transitions
1. **Scene 1 (Frames 0–480 | 0s–8s)**: **Secure Municipal Onboarding**
   - Clean vector phone frame, typing registered phone `+91 99155 49458`, tactile OTP entry `482910`, and verification badge issuing role-scoped JWT claim.
2. **Scene 2 (Frames 480–930 | 8s–15.5s)**: **Home Dashboard & Proactive Alert**
   - **Transition**: Upward vertical lift & slide into Ward 17 identity context, Breteau Index alert (34.0 Critical), sparkline animation, quick action tap on `Scan`.
3. **Scene 3 (Frames 930–1380 | 15.5s–23s)**: **PaliGemma AI Vector Scan**
   - **Transition**: Diagonal slide and perspective tilt into active viewfinder detecting stagnant water matrix (96%) and larvae (88%), orbital climate telemetry.
4. **Scene 4 (Frames 1380–1860 | 23s–31s)**: **Precision Ward-Level GIS Risk Map**
   - **Transition**: Focal zoom-expansion from viewfinder thumbnail into full-screen GIS Chandigarh Ward 14 view with pulsating outbreak heatmaps and inspector GPS radar rings.
5. **Scene 5 (Frames 1860–2340 | 31s–39s)**: **Longitudinal Bento Grid & Stats**
   - **Transition**: 3D spatial rotation flip along Y-axis into multi-week trends (W28–W35), House Index radial gauge, Container Index bar, and WHO/NCVBDC standard badges.
6. **Scene 6 (Frames 2340–2820 | 39s–47s)**: **Autonomous Fleet Dispatch & Care**
   - **Transition**: Downward vertical slide revealing live MCC patrol route coordinates (`Van DL-1V-4920`), and accredited healthcare capacity with 1-tap call action.
7. **Scene 7 (Frames 2820–3270 | 47s–54.5s)**: **Emergency SOS & Support Escalation**
   - **Transition**: Center split-expand scale-in showing emergency SOS hotline, field issue ticket typing/dispatch, and live SLA countdown timer chips.
8. **Scene 8 (Frames 3270–3600 | 54.5s–60s)**: **Android Splash Style Closing Screen**
   - **Transition**: Camera scale-down into full-red canvas (`#EE211E`) featuring the white NidanIQ logo text.

## Commands

```bash
cd video_showcase

# Regenerate 60s procedural audio
npm run sound

# Launch interactive Remotion Studio preview
npm run studio

# Render 4K UHD video (3840x2160 @ 60 FPS)
npm run render:4k

# Render Full HD 1080p video (1920x1080 @ 60 FPS)
npm run render

# Check TypeScript types
npm run typecheck
```
