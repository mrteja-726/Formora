---
name: Formora Fluid System
colors:
  surface: '#fbf8fe'
  surface-dim: '#dcd9de'
  surface-bright: '#fbf8fe'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f6f2f8'
  surface-container: '#f0edf2'
  surface-container-high: '#eae7ed'
  surface-container-highest: '#e4e1e7'
  on-surface: '#1b1b1f'
  on-surface-variant: '#424752'
  inverse-surface: '#303034'
  inverse-on-surface: '#f3f0f5'
  outline: '#727783'
  outline-variant: '#c2c6d4'
  surface-tint: '#005db6'
  primary: '#00478d'
  on-primary: '#ffffff'
  primary-container: '#005eb8'
  on-primary-container: '#c8daff'
  inverse-primary: '#a9c7ff'
  secondary: '#565e71'
  on-secondary: '#ffffff'
  secondary-container: '#dae2f9'
  on-secondary-container: '#5c6478'
  tertiary: '#643c49'
  on-tertiary: '#ffffff'
  tertiary-container: '#7e5361'
  on-tertiary-container: '#ffcddb'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#d6e3ff'
  primary-fixed-dim: '#a9c7ff'
  on-primary-fixed: '#001b3d'
  on-primary-fixed-variant: '#00468c'
  secondary-fixed: '#dae2f9'
  secondary-fixed-dim: '#bec6dc'
  on-secondary-fixed: '#131b2c'
  on-secondary-fixed-variant: '#3f4759'
  tertiary-fixed: '#ffd9e3'
  tertiary-fixed-dim: '#eeb8c8'
  on-tertiary-fixed: '#31111d'
  on-tertiary-fixed-variant: '#633b48'
  background: '#fbf8fe'
  on-background: '#1b1b1f'
  surface-variant: '#e4e1e7'
typography:
  display-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 57px
    fontWeight: '400'
    lineHeight: 64px
    letterSpacing: -0.25px
  headline-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 32px
    fontWeight: '400'
    lineHeight: 40px
  headline-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 28px
    fontWeight: '400'
    lineHeight: 36px
  title-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 22px
    fontWeight: '500'
    lineHeight: 28px
  title-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '500'
    lineHeight: 24px
    letterSpacing: 0.15px
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
    letterSpacing: 0.5px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
    letterSpacing: 0.25px
  label-lg:
    fontFamily: JetBrains Mono
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.5px
  headline-lg-mobile:
    fontFamily: Plus Jakarta Sans
    fontSize: 28px
    fontWeight: '400'
    lineHeight: 36px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  xs: 4px
  sm: 8px
  md: 12px
  lg: 16px
  xl: 24px
  2xl: 32px
  3xl: 48px
  gutter: 16px
  margin-mobile: 16px
  margin-desktop: 24px
---

## Brand & Style

This design system is engineered for a premium, privacy-first document vault. The brand personality is **Intelligent, Secure, and Refined**, aiming to evoke a sense of digital "calm" through high-density information architecture and effortless AI assistance.

The aesthetic represents a sophisticated synthesis of **Material Design 3 (M3)** logic, the functional simplicity of **Notion**, and the tactile "mechanical" polish of **Linear**. It prioritizes extreme legibility and a systematic approach to data visualization.

**Key Stylistic Pillars:**
- **Privacy-First Presence:** Use of subtle, protective-looking containers and "vault" metaphors.
- **Dynamic Adaptability:** Full support for Material You (Dynamic Color) while maintaining a high-contrast base for accessibility.
- **Precision Engineering:** Clean lines and consistent spacing scales that favor a "pro-tool" feel rather than a casual consumer app.

## Colors

The color system is built on the **Material 3 Tonal Palette** logic. While the primary blue (#005EB8) represents security and trust, the system is designed to ingest **Dynamic Color** tokens from the user's wallpaper on Android devices.

- **Primary:** Represents action and the core identity. Used for FABs, active states, and primary buttons.
- **Secondary/Neutral:** Utilized for document categorization and structural UI elements to minimize cognitive load.
- **Accessibility:** All color combinations must maintain a minimum contrast ratio of 4.5:1 for body text (WCAG AA) and 7:1 for critical data (WCAG AAA). 

In **Dark Mode**, surfaces use the M3 "Surface Container" logic, moving away from pure blacks to deep, tonal greys that reduce eye strain during long document review sessions.

## Typography

The typography strategy employs a dual-font approach to balance personality with utility. 

- **Display & Headlines:** **Plus Jakarta Sans** provides a modern, approachable, and slightly geometric feel that softens the "technical" nature of document management.
- **Body & Content:** **Inter** is used for its exceptional readability and neutral character, ensuring that dense information is easy to scan.
- **Labels & Data:** **JetBrains Mono** is utilized sparingly for metadata, document IDs, and AI-generated tags to provide a distinct "technical/secure" aesthetic.

**Hierarchy Rules:**
- Use **Title Large** for top app bar titles.
- Use **Label Large** for category tags and status indicators.
- Maintain a minimum of 20px line-height for any body text to ensure readability on mobile displays.

## Layout & Spacing

The design system follows a strict **4dp baseline grid**. All spatial relationships are derived from the defined spacing scale to ensure mathematical harmony.

**Grid Philosophy:**
- **Mobile:** 4-column fluid grid with 16px margins and 16px gutters.
- **Tablet/Foldable:** 8-column grid with 24px margins. Introduction of the **Navigation Rail** for persistent access.
- **Desktop:** 12-column fixed grid (max-width 1440px) with 24px gutters.

**Spacing Logic:**
- Use `sm` (8px) for internal element spacing (e.g., icon to text).
- Use `lg` (16px) for standard padding within cards and list items.
- Use `xl` (24px) for vertical section spacing.

## Elevation & Depth

This system utilizes the **Material 3 Tonal Elevation** model. Instead of relying solely on heavy shadows, depth is communicated through subtle color shifts and surface overlays.

- **Level 0 (Flat):** Used for the main background.
- **Level 1:** Used for card surfaces. Provides a subtle tint over the background color.
- **Level 2:** Used for interaction states (hover/pressed) and navigation bars.
- **Level 3:** Used for Search bars and smaller floating elements.
- **Level 4-5:** Reserved for Dialogs, Menus, and the Floating Action Button (FAB).

**Shadows:** When used, shadows are highly diffused (blur radius 2x the offset) with a low-opacity alpha (10-15%) of the primary color to maintain a clean, modern appearance.

## Shapes

The shape language is "Optimistically Rounded," following the M3 specification for high-spec devices. The generous radii make the platform feel accessible despite its powerful capabilities.

- **Large Components (Cards, Sheets):** 24px radius creates a soft container for complex data.
- **Medium Components (Buttons, Inputs):** 16px radius ensures high touch-target visibility and a consistent "pill-like" aesthetic.
- **Overlays (Dialogs):** 28px radius provides maximum distinction from the underlying grid.

All icons must use **Material Symbols (Rounded)** to align with the soft corner treatment of the UI containers.

## Components

### Buttons
- **Filled:** Used for the primary "Save" or "Upload" actions. 16px radius.
- **Tonal:** Secondary actions within a view. Uses a lighter version of the primary color.
- **Outlined:** Tertiary actions or "Cancel" buttons. 1px stroke.

### Input Fields
- **Style:** Filled with bottom-indicator or Outlined (16px radius).
- **States:** Active states must use a 2px stroke width. Labels use **Title Medium** when minimized.

### Cards
- **Elevated:** For document previews.
- **Outlined:** For secondary information like "Storage Used" or "Privacy Tips."
- **Padding:** Minimum 16px (`lg`) internal padding.

### Navigation
- **Bottom Navigation:** Mobile only. Uses pill-shaped active indicators.
- **Navigation Rail:** For Tablet/Desktop, providing quick access to "Vault," "Recent," and "AI Assistant."

### Floating Action Button (FAB)
- Always uses the **Primary Container** color.
- Employs **Container Transform** motion when expanding into a new document entry form.

### AI Assistant (Custom Component)
- A distinct "Glow" or "Gradient" border component that uses the Tertiary color palette to indicate AI-active states or suggestions.