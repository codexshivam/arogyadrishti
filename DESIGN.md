---
name: Arogya Drishti
colors:
  surface: '#f7f9fb'
  surface-dim: '#d8dadc'
  surface-bright: '#f7f9fb'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f2f4f6'
  surface-container: '#eceef0'
  surface-container-high: '#e6e8ea'
  surface-container-highest: '#e0e3e5'
  on-surface: '#191c1e'
  on-surface-variant: '#5a403f'
  inverse-surface: '#2d3133'
  inverse-on-surface: '#eff1f3'
  outline: '#8f706e'
  outline-variant: '#e3bebb'
  surface-tint: '#b81e2a'
  primary: '#7c0012'
  on-primary: '#ffffff'
  primary-container: '#a50c1f'
  on-primary-container: '#ffb1ad'
  inverse-primary: '#ffb3af'
  secondary: '#565e74'
  on-secondary: '#ffffff'
  secondary-container: '#dae2fd'
  on-secondary-container: '#5c647a'
  tertiary: '#201bb3'
  on-tertiary: '#ffffff'
  tertiary-container: '#3b3cc9'
  on-tertiary-container: '#bfc0ff'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#ffdad7'
  primary-fixed-dim: '#ffb3af'
  on-primary-fixed: '#410005'
  on-primary-fixed-variant: '#930017'
  secondary-fixed: '#dae2fd'
  secondary-fixed-dim: '#bec6e0'
  on-secondary-fixed: '#131b2e'
  on-secondary-fixed-variant: '#3f465c'
  tertiary-fixed: '#e1e0ff'
  tertiary-fixed-dim: '#c0c1ff'
  on-tertiary-fixed: '#07006c'
  on-tertiary-fixed-variant: '#2f2ebe'
  background: '#f7f9fb'
  on-background: '#191c1e'
  surface-variant: '#e0e3e5'
typography:
  headline-xl:
    fontFamily: Plus Jakarta Sans
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
  headline-xl-mobile:
    fontFamily: Plus Jakarta Sans
    fontSize: 26px
    fontWeight: '700'
    lineHeight: 34px
  headline-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 32px
  headline-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  body-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
  label-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
  label-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
  label-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 10px
    fontWeight: '700'
    lineHeight: 14px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  gutter-mobile: 0.75rem
  margin: 1.5rem
  margin-mobile: 1rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2rem
---

## Brand & Style

This design system is tailored for Indian public health officers, frontline surveillance workers, and vector-borne disease control teams operating in high-pressure field environments. The visual tone balances clinical urgency with institutional authority, clarity, and assistive intelligence.

### Aesthetic Foundation
- **Modern Clinical & Utilitarian:** Minimal, clutter-free interfaces prioritizing immediate legibility in bright sunlight, high-dust outdoor environments, and varying mobile hardware.
- **Urgent Yet Reassuring:** A dominant deep crimson anchor signals medical vigilance and official government action without inducing alarm fatigue.
- **Assistive AI Accents:** Subtle multi-stop gradient sparks (Gemini-inspired cyan to violet) reserved exclusively for automated surveillance predictions, outbreak likelihood scores, and automated field dispatch insights.

## Colors

The palette ensures AAA compliance across key data entry and status monitors.

### Core Palette
- **Primary Brand Red (`#a50c1f` / `#991b1b` / `#b91c1c`):** Applied to high-priority field alerts, primary action triggers, brand bars, active tab highlights, and urgent triage cases.
- **Slate Text Scale:**
  - **Headings & Critical Data (`#0f172a`):** Maximum contrast for outdoor sunlight readability.
  - **Body & Secondary Copy (`#334155`):** High clarity for patient histories, symptoms, and location markers.
  - **Muted & Metadata (`#64748b`):** Timestamps, deactivated states, and helper instructions.
- **Pure White (`#ffffff`):** Dedicated to elevated card surfaces, triage sheets, and data forms to maintain clear containment against the backdrop.
- **Soft Neutral Canvas (`#f8fafc`):** Reduces eye strain across prolonged survey shifts.
- **AI Accent Gradient:** A linear progression from Sky Blue (`#38bdf8`) to Indigo (`#6366f1`) and Soft Fuchsia (`#c084fc`), reserved strictly for smart vector prediction indicators and automated voice-to-text validation tags.

## Typography

Plus Jakarta Sans is utilized system-wide for its geometric clarity, open apertures, and exceptional legibility across varied regional scripts and numeric surveillance tallies.

### Usage Standards
- **Display & Section Headers:** High-weight headers (`700`) establish quick contextual orientation on small handheld devices.
- **Data Tables & Vital Logs:** Ensure tabular figures (`tnum`) are enforced on body tokens to preserve vertical alignment of survey numbers, vector density metrics, and household IDs.
- **Field Micro-copy:** Labels use semi-bold to bold weights (`600` - `700`) to remain sharp even under antireflective or damaged screen protectors.

## Layout & Spacing

Field data collection demands generous touch surfaces, ergonomic bottom-screen actions, and distinct horizontal boundaries to prevent tap errors while walking or holding equipment.

### Screen Layout Principles
- **Grid Structure:** 4-column layout on mobile viewports (<640px) expanding to an 8-column layout on surveillance tablets (640px–1024px) and 12-column on desktop administrative dashboards.
- **Safe Margins:** Standard 16px (`1rem`) edge margin on mobile devices to prevent touch clipping near rounded screen bezels.
- **Field Ergonomics:** Primary forms and critical CTAs (e.g., "Submit Larval Survey", "Dispatch Fogging Unit") must occupy a persistent bottom sheet or sticky footer zone within thumb reach.

## Elevation & Depth

To preserve device battery life, reduce GPU rendering load on entry-level Android devices, and ensure high contrast outdoors, this design system avoids heavy drop shadows and diffuse blurs.

### Hierarchy & Layers
- **Base Canvas:** Flat `#f8fafc` tint.
- **Level 1 (Cards & Data Panels):** Pure white (`#ffffff`) resting on `#f8fafc` with a subtle hairline border (`1px solid #e2e8f0`). Flat with zero blur.
- **Level 2 (Active Modals & Bottom Sheets):** Crisp ambient shadow: `0 4px 16px -2px rgba(15, 23, 42, 0.08)` paired with an upper hairline edge.
- **Level 3 (Toasts, Emergency Alerts, Floating Action Buttons):** `0 10px 24px -4px rgba(165, 12, 31, 0.25)` to distinguish urgent live actions from static survey entries.
- **AI Assistive Cards:** Dual border styling: an inner `1px` translucent gradient border over a soft ambient indigo glow (`0 0 12px rgba(99, 102, 241, 0.12)`).

## Shapes

A balanced `roundedness: 2` (base `8px / 0.5rem`, cards `16px / 1rem`, hero containers `24px / 1.5rem`) creates an approachable, modern clinical environment while maintaining structural density for data-heavy inspection logs.

### Application Rules
- **Interactive Buttons & Form Inputs:** 8px (`0.5rem`) corner radius for crisp tap bounds.
- **Information Cards & Inspection Modules:** 16px (`1rem`) corner radius to clearly separate patient and site dossiers.
- **Status Pills & AI Spark Badges:** Fully rounded (`9999px`) to distinguish actionable metadata from square input fields.
- **Top Brand Banners:** Large curved convex base (inspired by the circular brand header) descending from mobile top navigation for authoritative presence.

## Components

### Buttons
- **Primary Field CTA:** Solid deep crimson (`#a50c1f`) background, `#ffffff` text, 48px minimum touch height, `8px` corner radius. Active state darkens to `#991b1b`.
- **Secondary Action:** White background with a `1.5px` border in `#cbd5e1` and slate `#0f172a` text.
- **AI Assist Button:** Gradient background (`linear-gradient(135deg, #0f172a 0%, #1e1b4b 100%)`) with an accent border (`#6366f1`) and sparkling icon indicator for automated risk modeling.

### Input Fields
- White container surface, `48px` height for gloved/field one-handed use, bordered by `1px solid #cbd5e1`.
- Focused state transitions to a `2px` deep crimson ring (`#a50c1f`).
- Error state switches to `#dc2626` outline with mandatory descriptive caption text for rapid correction.

### Chips & Badges
- **Triage Badges:** High-contrast solid fills for urgency: Red (`#fee2e2` bg, `#991b1b` text) for Positive/Active Outbreak; Amber (`#fef3c7` bg, `#92400e` text) for Suspected; Emerald (`#dcfce7` bg, `#166534` text) for Clear/Sprayed.
- **AI Predictive Chip:** Indigo tint (`#e0e7ff` bg, `#4338ca` text) preceded by an iridescent gradient spark dot.

### Cards & Dossiers
- Pure white `#ffffff` canvas with `16px` border radius, bounded by `1px solid #f1f5f9`.
- Header section houses bold slate IDs (`#0f172a`), timestamp in `#64748b`, and right-aligned status indicators.
- Quick action divider at base containing direct calling, map navigation, or survey update triggers.

### Specialized Field Components
- **Vector Density Gauge:** Horizontal segmented bar using crimson, amber, and slate tracking larval index per ward.
- **Offline Sync Indicator:** Persistent mini-pill in app header showing synced state vs. local cached records awaiting network connectivity.
