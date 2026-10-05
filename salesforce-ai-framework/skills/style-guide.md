# Skill: WarpDrive UI Style Guide & Design System

## Purpose
This document is the authoritative design system and visual style sheet for all user interface developments, Lightning Web Components (LWC), and pitch collateral. It establishes a consistent, high-end, light-theme aesthetic inspired by the **WarpDrive Tech Works** brand identity (Salesforce Summit Partner).

---

## 1. Core Principles

> [!CRITICAL]
> **Strict Light-Mode Mandate**:
> - Never apply dark slate, navy, charcoal, or pitch-black background colors to cards or main container surfaces.
> - Backgrounds must be pure `#FFFFFF` or subtle light canvas `#F8FAFC`.
> - All high-contrast text must be deep slate (`#0F172A`), never light gray on white or white on dark.

- **Vibrant Emerald Accents**: Clean, high-energy emerald green (`#00A859`) conveys institutional confidence, precision, and modern SaaS excellence.
- **Pill Geometry**: Primary call-to-actions, category tags, and status chips utilize fully rounded pill silhouettes (`border-radius: 9999px`).
- **Subtle Elevation**: Flat surfaces feel sterile; harsh shadows feel dated. We use layered, soft ambient shadows (`box-shadow: 0 1px 3px rgba(0,0,0,0.05)`).
- **Numbered Badges**: Workflow steps and milestone indicators leverage clean circular badges (`01`, `02`, `04`).

---

## 2. Color Palette & Token Definitions

```
┌────────────────────────────────────────────────────────────────────────┐
│                        WarpDrive Color Palette                         │
├────────────────────┬──────────┬──────────────┬─────────────────────────┤
│ Role               │ Hex Code │ RGB / HSL    │ Usage                   │
├────────────────────┼──────────┼──────────────┼─────────────────────────┤
│ Primary Brand      │ #00A859  │ rgb(0,168,89)│ Main CTA, Primary Icons │
│ Primary Hover      │ #008C4A  │ rgb(0,140,74)│ Hover & Active States   │
│ Mint Tint Surface  │ #ECFDF5  │ rgb(236,253,245) Chip Fills, Active Tabs│
│ Mint Accent Border │ #A7F3D0  │ rgb(167,243,208) Pill & Card Outlines   │
│ Forest Deep Text   │ #065F46  │ rgb(6,95,70) │ High-Contrast on Mint   │
│ Card Surface       │ #FFFFFF  │ rgb(255,255,255) Component Containers   │
│ Page Canvas        │ #F8FAFC  │ rgb(248,250,252) App Canvas & Modals    │
│ Headings / Titles  │ #0F172A  │ rgb(15,23,42)│ H1, H2, Metric Values   │
│ Muted Subtext      │ #64748B  │ rgb(100,116,139) Subtitles, Field Labels│
│ Divider Line       │ #E2E8F0  │ rgb(226,232,240) Subtle Table Borders   │
└────────────────────┴──────────┴──────────────┴─────────────────────────┘
```

### Auxiliary Status Colors (Semantic)
- **Available / Success**: Background `#ECFDF5`, Border `#A7F3D0`, Text `#065F46`
- **Blocked / Warning**: Background `#FFFBEB`, Border `#FDE68A`, Text `#92400E`
- **Sold / Neutral**: Background `#F1F5F9`, Border `#CBD5E1`, Text `#475569`
- **Overdue / Danger**: Background `#FEF2F2`, Border `#FECACA`, Text `#991B1B`

---

## 3. UI Component Specifications

### A. Primary Pill Buttons
Pill buttons provide the signature WarpDrive action aesthetic.
```css
.wd-btn-primary {
    background-color: #00A859;
    color: #FFFFFF;
    font-size: 0.875rem;
    font-weight: 600;
    line-height: 1.25rem;
    padding: 0.5rem 1.35rem;
    border-radius: 9999px;
    border: none;
    cursor: pointer;
    box-shadow: 0 4px 14px rgba(0, 168, 89, 0.35);
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
    transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
}

.wd-btn-primary:hover {
    background-color: #008C4A;
    box-shadow: 0 6px 18px rgba(0, 168, 89, 0.45);
    transform: translateY(-1px);
}

.wd-btn-primary:active {
    transform: translateY(0);
}

.wd-btn-secondary {
    background-color: #FFFFFF;
    color: #0F172A;
    font-size: 0.875rem;
    font-weight: 600;
    padding: 0.5rem 1.35rem;
    border-radius: 9999px;
    border: 1px solid #E2E8F0;
    cursor: pointer;
    transition: all 0.2s ease;
}

.wd-btn-secondary:hover {
    background-color: #F8FAFC;
    border-color: #CBD5E1;
}
```

### B. Numbered Step Badges (`01`, `02`, `04`)
For sequence cards, stage indicators, or pipeline steps:
```css
.wd-step-badge {
    width: 2rem;
    height: 2rem;
    border-radius: 50%;
    background-color: #ECFDF5;
    border: 1.5px solid #A7F3D0;
    color: #065F46;
    font-size: 0.75rem;
    font-weight: 700;
    display: flex;
    align-items: center;
    justify-content: center;
}

.wd-step-badge.active {
    background-color: #00A859;
    border-color: #00A859;
    color: #FFFFFF;
    box-shadow: 0 2px 8px rgba(0, 168, 89, 0.3);
}
```

### C. Standard Card Container
```css
.wd-container-card {
    background: #FFFFFF;
    border: 1px solid #E2E8F0;
    border-radius: 12px;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05), 0 1px 2px rgba(0, 0, 0, 0.03);
    padding: 1.5rem;
}

.wd-container-card:hover {
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.06);
    border-color: #CBD5E1;
}
```

---

## 4. Copy-Paste LWC Master CSS Tokens (`tokens.css`)

Drop this boilerplate directly into your component's CSS or import via static resource:

```css
:host {
    --wd-color-primary: #00A859;
    --wd-color-primary-hover: #008C4A;
    --wd-color-primary-light: #10B981;
    --wd-color-mint-bg: #ECFDF5;
    --wd-color-mint-border: #A7F3D0;
    --wd-color-mint-text: #065F46;
    --wd-color-surface: #FFFFFF;
    --wd-color-canvas: #F8FAFC;
    --wd-color-text-title: #0F172A;
    --wd-color-text-body: #334155;
    --wd-color-text-muted: #64748B;
    --wd-color-border: #E2E8F0;
    --wd-radius-pill: 9999px;
    --wd-radius-card: 12px;
    --wd-shadow-card: 0 1px 3px rgba(0, 0, 0, 0.05), 0 1px 2px rgba(0, 0, 0, 0.03);
    --wd-shadow-pill: 0 4px 14px rgba(0, 168, 89, 0.35);
}
```
