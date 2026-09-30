# Design System Strategy: The Tactile Wellness Document

## 1. Overview & Creative North Star
### Creative North Star: "The Bio-Tactile Sanctuary"
This design system rejects the clinical flatness of modern web standards in favor of a "Bio-Tactile Sanctuary." We are blending the hyper-legibility of high-end health editorials (Apple Health) with the physical intuition of skeuomorphism. 

To break the "template" look, we move away from rigid, boxy grids. We utilize **intentional asymmetry**, where pill-shaped cards vary in height to create a rhythmic, vertical flow, and **overlapping glass layers** that suggest a 3D space rather than a flat screen. The experience should feel like interacting with high-end physical medical instruments—precise, soft to the touch, and deeply reassuring.

---

## 2. Colors & Surface Logic
Our palette is anchored in `surface` (#f9f9fe), a near-white that feels cleaner and more "medical-premium" than pure white.

### The "No-Line" Rule
**Borders are prohibited for sectioning.** To define boundaries, you must use background shifts or tonal transitions.
*   **Example:** A `surface-container-low` (#f3f3f8) card should sit on a `background` (#f9f9fe) without any stroke. The contrast in tone is sufficient to define the edge.

### Surface Hierarchy & Nesting
Treat the UI as a series of physical layers. Use the tiers to create "nested" depth:
1.  **Level 0 (Base):** `surface` (#f9f9fe)
2.  **Level 1 (Sections):** `surface-container-low` (#f3f3f8)
3.  **Level 2 (Interactive Cards):** `surface-container-lowest` (#ffffff)
4.  **Level 3 (Floating Overlays):** Glassmorphism (see below)

### The "Glass & Gradient" Rule
Floating elements (modals, navigation bars) must use **Glassmorphism**. Apply a semi-transparent version of `surface-container-lowest` with a `backdrop-blur` (20px–40px). 

### Signature Textures
Main CTAs and data visualizations must move beyond flat fills. Use subtle linear gradients:
*   **Primary Action:** Transition from `primary` (#ba0034) to `primary-container` (#e51245) at a 135-degree angle. This adds a "soul" to the button that makes it feel pressurized and tactile.

---

## 3. Typography
We utilize **Inter** to achieve a high-legibility, editorial feel. The hierarchy is designed to guide the eye through dense health data with ease.

*   **Display (lg, md, sm):** Used for "Hero Stats" (e.g., Step Counts). These should be tight-tracked (-2%) to feel like a premium magazine header.
*   **Headline & Title:** Use `headline-lg` for category names. Pair with `title-sm` for sub-labels to create a clear "Editorial Anchor."
*   **Body:** `body-lg` is your workhorse. Always ensure a line height of 1.5x for maximum breathability.
*   **Labels:** Use `label-md` in uppercase with +5% letter spacing for small metadata or section headers that need an "authoritative" tone.

---

## 4. Elevation & Depth (The Tactile Engine)
This is the core differentiator of the system. We do not use "drop shadows"; we use **Ambient Lighting.**

### The Layering Principle
Depth is achieved by "stacking" surface tiers. Place a `surface-container-lowest` (#ffffff) card on a `surface-container-low` (#f3f3f8) background to create a soft, natural lift.

### Ambient Shadows & Neumorphism
For elements that require high tactile affordance (Buttons/Main Cards):
*   **The Outer Glow:** Use a shadow with a blur of 30px, 10% opacity, using a tinted version of `on-surface` (#1a1c1f).
*   **The Inner Tactility:** To create the "pressed" or "pill" feel, use a 2px inner shadow (inset) on the top-left with a white highlight and a 2px inner shadow on the bottom-right with a 5% `on-surface` tint.

### The "Ghost Border" Fallback
If a layout absolutely fails accessibility tests without a border, use a **Ghost Border**: 
*   `outline-variant` (#e6bcbd) at **15% opacity**. Never use a 100% opaque stroke.

---

## 5. Components

### Pill Buttons (Primary/Secondary)
*   **Shape:** Always `rounding.full` (9999px).
*   **Style:** Primary uses the Signature Gradient (Primary to Primary-Container). Secondary uses `surface-container-highest` with a soft inner shadow to look "carved" into the interface.
*   **Padding:** Vertical 1rem, Horizontal 2rem.

### Tactile Data Cards
*   **Shape:** `rounding.lg` (2rem).
*   **Logic:** No dividers. Separate content using `body-md` for headers and `display-sm` for the data point. Use `secondary` (#006e26) for positive trends and `error` (#ba1a1a) for alerts.
*   **Background:** `surface-container-lowest` (#ffffff).

### Glass Overlays (Navigation/Bottom Sheets)
*   **Effect:** 70% opacity of `surface-container-lowest` with a heavy blur.
*   **Edge:** A 1px "Ghost Border" at the top edge only to define the sheet's start.

### Selection Chips
*   **Style:** Use `surface-container-high`. When selected, transition to `tertiary` (#0058bc) with `on-tertiary` (#ffffff) text.

---

## 6. Do's and Don'ts

### Do:
*   **Do** use extreme rounded corners (`lg` or `full`) to maintain the "biological" feel.
*   **Do** use vertical white space (32px+) instead of horizontal lines to separate content.
*   **Do** overlap elements slightly (e.g., an icon breaking the boundary of a card) to create visual interest.
*   **Do** use vibrant accents (`primary`, `secondary`, `tertiary`) sparingly for data-only.

### Don't:
*   **Don't** use pure black (#000000) for text. Always use `on-surface` (#1a1c1f).
*   **Don't** use 1px solid dividers. If you feel you need one, increase the padding instead.
*   **Don't** use "Standard" drop shadows. If it looks like a default CSS box-shadow, it is wrong. Soften the blur and reduce the opacity until it's "felt, not seen."
*   **Don't** use sharp corners. Even "small" rounding should be `sm` (0.5rem).