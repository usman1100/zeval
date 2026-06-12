---
name: High-Performance Engineering
colors:
  surface: "#121314"
  surface-dim: "#121314"
  surface-bright: "#393939"
  surface-container-lowest: "#0d0e0f"
  surface-container-low: "#1b1c1c"
  surface-container: "#1f2020"
  surface-container-high: "#292a2a"
  surface-container-highest: "#343535"
  on-surface: "#e3e2e2"
  on-surface-variant: "#c4c7c7"
  inverse-surface: "#e3e2e2"
  inverse-on-surface: "#303031"
  outline: "#8e9192"
  outline-variant: "#444748"
  surface-tint: "#c9c6c5"
  primary: "#c9c6c5"
  on-primary: "#313030"
  primary-container: "#0a0a0a"
  on-primary-container: "#7b7979"
  inverse-primary: "#5f5e5e"
  secondary: "#c8c6c5"
  on-secondary: "#313030"
  secondary-container: "#474746"
  on-secondary-container: "#b7b4b4"
  tertiary: "#c8c6c5"
  on-tertiary: "#303030"
  tertiary-container: "#0a0a0a"
  on-tertiary-container: "#7a7979"
  error: "#ffb4ab"
  on-error: "#690005"
  error-container: "#93000a"
  on-error-container: "#ffdad6"
  primary-fixed: "#e5e2e1"
  primary-fixed-dim: "#c9c6c5"
  on-primary-fixed: "#1c1b1b"
  on-primary-fixed-variant: "#474646"
  secondary-fixed: "#e5e2e1"
  secondary-fixed-dim: "#c8c6c5"
  on-secondary-fixed: "#1c1b1b"
  on-secondary-fixed-variant: "#474746"
  tertiary-fixed: "#e4e2e1"
  tertiary-fixed-dim: "#c8c6c5"
  on-tertiary-fixed: "#1b1c1c"
  on-tertiary-fixed-variant: "#474746"
  background: "#121314"
  on-background: "#e3e2e2"
  surface-variant: "#343535"
  emerald-success: "#10b981"
  ruby-error: "#e11d48"
  border-subtle: "#262626"
  text-primary: "#ffffff"
  text-secondary: "#a3a3a3"
  text-muted: "#525252"
typography:
  headline-lg:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: "600"
    lineHeight: 32px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: "600"
    lineHeight: 28px
    letterSpacing: -0.01em
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: "400"
    lineHeight: 20px
  body-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: "400"
    lineHeight: 18px
  label-mono:
    fontFamily: JetBrains Mono
    fontSize: 12px
    fontWeight: "500"
    lineHeight: 16px
    letterSpacing: 0.02em
  code-block:
    fontFamily: JetBrains Mono
    fontSize: 13px
    fontWeight: "400"
    lineHeight: 20px
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  container-max: 1440px
  gutter: 1rem
  margin-page: 2rem
  stack-xs: 0.25rem
  stack-sm: 0.5rem
  stack-md: 1rem
  stack-lg: 1.5rem
---

## Brand & Style

The design system is engineered for developers who value speed, precision, and clarity. It rejects the soft, approachable trends of consumer software in favor of a **minimalist, high-performance aesthetic** that mirrors the tools used in professional software engineering.

The visual narrative is built on the concept of "The IDE as a Dashboard"—utilizing a restricted color palette, rigorous grid systems, and high-density information layouts. The emotional response should be one of competence and reliability. By utilizing deep blacks and crisp, low-opacity borders, the interface recedes to let the user's data and code take center stage.

Design principles:

- **Mechanical Precision:** Every element exists for a functional reason.
- **Data Density:** Prioritize information over whitespace, without sacrificing legibility.
- **Zero Distraction:** No gradients, shadows, or "friendly" illustrations.
- **Immediate Feedback:** Use high-contrast status colors (Emerald and Ruby) to signal system health instantly.

## Colors

The palette is a strictly regulated dark-mode system. It relies on a hierarchy of "Blacks" and "Grays" to create structure through contrast rather than shadow.

- **Backgrounds:** The foundation is `#0a0a0a`. Elevated surfaces like sidebars or cards use `#171717`.
- **Borders:** Use `#262626` for all structural divisions. This creates the "Vercel-style" crispness.
- **Accents:** Use `emerald-success` for primary actions (Save, Deploy, Active) and `ruby-error` for destructive actions or critical failures.
- **Typography:** Pure white (`#ffffff`) is reserved for headers and active text. Use `#a3a3a3` for standard body text and `#525252` for metadata and disabled states.

## Typography

Typography is the primary tool for hierarchy. This design system uses **Inter** for all UI elements to maintain a modern, neutral feel, and **JetBrains Mono** for all technical data, IDs, and code snippets.

- **Scale:** Keep sizes small to maximize information density. `14px` is the standard body size.
- **Capitalization:** Use uppercase with increased letter spacing for `label-mono` when used in table headers or sidebar category labels.
- **Monospace:** Any data that is machine-generated (UUIDs, API Keys, Timestamps) must use the `label-mono` or `code-block` tokens to signal technical context.

## Layout & Spacing

The layout utilizes a **fixed grid** approach for dashboards and a **fluid grid** for data tables.

- **The 4px Rule:** All spacing (padding, margins, gaps) must be a multiple of 4px.
- **Structure:** A standard 260px fixed sidebar on the left, with a main content area that caps at 1440px to ensure line-length readability.
- **Tables:** Tables should span the full width of their container. Use `stack-sm` (8px) for vertical cell padding to maintain high density, and `stack-md` (16px) for horizontal cell padding.
- **Breakpoints:**
  - Mobile (<768px): Sidebar collapses into a hamburger menu; page margins reduce to 1rem.
  - Desktop (>1024px): Standard 2-column layout with fixed navigation.

## Elevation & Depth

This design system avoids traditional shadows to maintain a "flat" engineering feel. Depth is communicated through **tonal layering** and **crisp outlines**.

- **Level 0 (Background):** `#0a0a0a`. The furthest back layer.
- **Level 1 (Surfaces):** `#171717`. Used for cards, sidebars, and modas.
- **Level 2 (Interactions):** `#262626`. Used for hover states on list items or buttons.
- **Outlines:** All containers must have a 1px solid border using the `border-subtle` (`#262626`) color.
- **Focus States:** Active inputs or focused elements should use a 1px solid white border or a subtle emerald ring—never a heavy glow.

## Shapes

The shape language is "Soft-Square." While sharp edges (0px) can feel too aggressive, large rounds feel too consumer-focused.

- **Standard Radius:** Use `0.25rem` (4px) for buttons, inputs, and small cards.
- **Large Radius:** Use `0.5rem` (8px) for main content containers or modals.
- **Exceptions:** Status badges (pills) may use `rounded-full` to distinguish them from interactive buttons.

## Components

- **Buttons:**
  - Primary: Solid `emerald-success` with black text.
  - Secondary: Ghost style with `border-subtle` and white text.
  - Danger: Solid `ruby-error` with white text.
- **Inputs:** Dark background (`#0a0a0a`), `border-subtle`, and monospace text for data entry. Focus state turns the border to white.
- **Data Tables:** No external borders. Use `border-b` (`#262626`) between rows. Headers should be uppercase mono text.
- **Status Badges:** Low-opacity backgrounds of the status color (e.g., 10% emerald) with high-saturation text of the same hue.
- **Code Blocks:** A specialized container with a `#111111` background, 1px border, and syntax highlighting using a "Night Owl" or similar high-contrast theme.
- **Breadcrumbs:** Use `text-muted` for parent links and `text-primary` for the current page, separated by a forward slash `/`.
