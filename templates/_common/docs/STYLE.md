# Style & Brand - <project>

<!-- The VISUAL contract. DESIGN/TEDD pin what the app DOES and its data shapes; this pins how it LOOKS and
     FEELS to use. The aesthetic is HUMAN-OWNED - /design proposes defaults from the domain, you decide.
     ux-agent reviews every visible surface against this; doc-stats reads the Palette hexes below and flags
     CSS colors that are NOT here, so the contract cannot silently drift. Fill the <...> in; delete a row
     that does not apply. An UNFILLED palette (still <hex>) is ignored - no false findings on a fresh doc. -->

## Vibe
- Mood: <2-4 words - e.g. earth-toned, saturated, naturalistic, calm, high-readability>
- Audience + context: <who uses this, and where>
- Reference: <a site/app whose feel you want, or "none">

## Palette
<!-- Name each color and give a 6-digit HEX. doc-stats extracts these and WARNs when project CSS uses colors
     outside this set. Keep it small - a real palette is ~6-10 colors, not a rainbow. -->
| Token   | Hex     | Use                          |
|---------|---------|------------------------------|
| bg      | <hex>   | page background              |
| surface | <hex>   | cards / panels               |
| text    | <hex>   | body text                    |
| muted   | <hex>   | secondary text               |
| primary | <hex>   | primary actions / links      |
| accent  | <hex>   | highlights                   |
| danger  | <hex>   | destructive actions          |
| border  | <hex>   | dividers / input outlines    |

## Typography
- Font (UI): <stack>    Font (headings): <stack, or same as UI>
- Scale (px): <e.g. 14 / 16 / 20 / 28 / 40>    Body line-height: <e.g. 1.6>
- Reading width: <e.g. prose capped at 70ch>

## Layout & density
- Spacing scale (px): <e.g. 4 / 8 / 16 / 24 / 32>
- Density: <compact | comfortable>    Corner radius: <px>
- Breakpoints (px): <e.g. 360 / 768 / 1200>

## Components (conventions - so surfaces stay consistent)
- Buttons: <how primary / secondary / destructive differ>
- Forms: <label placement, required marker, error style>
- Nav: <where it lives, what it links, how the active item reads>
- States: <what EMPTY / LOADING / ERROR look like>

## Branding
- Logo: <path, or "none yet - wordmark: <name>">
- Voice: <e.g. plain, warm, no jargon>

## Accessibility floor (non-negotiable)
- WCAG AA contrast on text; a visible focus ring on every control; hit targets >= 44px; honor
  `prefers-reduced-motion`. ux-agent and (for web) the a11y build gate hold this line.
