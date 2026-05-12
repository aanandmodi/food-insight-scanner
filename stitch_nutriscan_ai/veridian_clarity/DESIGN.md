# Design System Document: The Editorial Health Experience

## 1. Overview & Creative North Star: "The Living Vitality"
This design system moves away from the clinical, sterile aesthetic typical of health apps and toward a high-end, editorial experience we call **"The Living Vitality."** 

Our Creative North Star is the concept of a "Digital Nutritionist's Atelier"—a space that feels premium, curated, and deeply intentional. We reject the generic "card-on-grey-background" template. Instead, we embrace **intentional asymmetry**, high-contrast typography scales, and a sense of "breathing room" that mirrors the clarity of a healthy lifestyle. The interface should feel like a high-end lifestyle magazine: sophisticated, effortless, and authoritative.

---

## 2. Color & Tonal Depth
Our palette is anchored in the vitality of `primary` (#006D43) and the lightness of `surface` (#F7F9FB). 

### The "No-Line" Rule
**Explicit Instruction:** Designers are prohibited from using 1px solid borders to define sections. Boundaries must be established through background color shifts. Use `surface-container-low` to sit on a `surface` background to create a section. Structural integrity comes from tonal contrast, not wireframe lines.

### Surface Hierarchy & Nesting
Treat the UI as a series of physical, layered sheets of "frosted glass" and "fine paper."
*   **Base:** `surface` (#F7F9FB).
*   **Mid-Level (Sections):** `surface-container-low` (#F2F4F6).
*   **Elevated (Cards/Modals):** `surface-container-lowest` (#FFFFFF).
By nesting a `surface-container-lowest` card inside a `surface-container-low` section, we create a soft, natural lift that feels sophisticated rather than "stuck on."

### The "Glass & Gradient" Rule
To inject "soul" into the digital experience:
*   **Glassmorphism:** For floating action buttons or overlaying insight panels, use `surface-container-lowest` at 70% opacity with a `backdrop-filter: blur(20px)`. 
*   **Signature Textures:** For high-impact CTAs or "Scan Results," utilize a subtle linear gradient transitioning from `primary` (#006D43) to `primary-container` (#00D084). This provides a luminous, healthy glow that flat colors cannot replicate.

---

## 3. Typography: Editorial Authority
We utilize a pairing of **Manrope** for high-impact displays and **Inter** for functional clarity.

*   **Display & Headlines (Manrope):** These are our "Editorial Voice." Use `display-lg` (3.5rem) with tight letter-spacing for hero metrics (e.g., a "Health Score"). The intentional scale difference between a `display-md` headline and `body-md` text creates a professional, curated feel.
*   **Titles & Body (Inter):** Inter handles the "Data Voice." It provides maximum readability for ingredient lists and nutritional facts. 
*   **Labeling:** Use `label-md` in `on-surface-variant` (#3C4A40) for meta-data to keep the hierarchy clean and non-competitive.

---

## 4. Elevation & Depth: Tonal Layering
Traditional shadows are often "dirty." We use light and tone to define space.

*   **The Layering Principle:** Depth is achieved by "stacking" surface tokens. A `surface-container-highest` element should only ever appear on top of a `surface-container-low` element to maintain a logical physical stack.
*   **Ambient Shadows:** If a floating effect is required (e.g., a "Food Log" entry), use a shadow with a blur radius of `32px` or higher at 6% opacity. Use a tint of `on-surface` (#191C1E) rather than pure black to ensure the shadow feels like part of the environment.
*   **The "Ghost Border" Fallback:** If a container requires a boundary for accessibility, use the `outline-variant` (#BACBBD) at **15% opacity**. This creates a "Ghost Border"—it suggests a boundary without creating a hard visual stop.

---

## 5. Components & Signature Patterns

### Buttons
*   **Primary:** Rounded `full` (9999px) with the signature `primary` to `primary-container` gradient. Use `on-primary` (#FFFFFF) for text.
*   **Tertiary:** No background or border. Use `primary` text with an icon. Interaction is shown through a `surface-variant` circular hover state.

### Cards & Lists: The "No-Divider" Mandate
*   **Forbid Dividers:** Do not use horizontal lines to separate list items. 
*   **The Alternative:** Use `1.5rem` (`md`) vertical spacing and subtle background shifts. For food logs, use a `surface-container-low` background for the container and `surface-container-lowest` for the individual item cards.

### Input Fields (The Scanner Input)
*   **Style:** Large `xl` (3rem) rounded corners. Background set to `surface-container-highest`.
*   **Active State:** Transition the background to `surface-container-lowest` and apply a "Ghost Border" of `primary` at 20% opacity.

### Nutritional Chips
*   **Visuals:** Use `sm` (0.5rem) roundedness. 
*   **Logic:** Use `tertiary-container` (#FF9E63) for warnings (High Sugar) and `primary-fixed-dim` (#31E193) for positive attributes (High Protein).

---

## 6. Do’s and Don’ts

### Do:
*   **Do** embrace white space. If a layout feels "full," increase the padding using the `xl` (3rem) scale.
*   **Do** use asymmetrical layouts for health insights. A large "85% Health Score" on the left balanced by a small "Pro Tip" on the right feels more premium than a centered layout.
*   **Do** use minimalist line icons with a `1.5px` stroke weight to match the Inter typography.

### Don’t:
*   **Don't** use 100% opaque borders. They break the "Living Vitality" organic feel.
*   **Don't** use default Material Design "Drop Shadows." They look dated and heavy.
*   **Don't** cram information. If a food item has 20 ingredients, use a "See All" progressive disclosure pattern to maintain the editorial look.
*   **Don't** use pure black (#000000). Always use `on-surface` (#191C1E) for text to maintain a soft, premium contrast.