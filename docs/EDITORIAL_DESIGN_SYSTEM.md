# KAMLOKA Editorial Design System

**Version:** 1.0  
**Status:** Active  
**Direction:** Editorial Monochrome / Immersive Camera

## Design principles

1. Photography is the primary content. Camera controls must remain secondary and unobtrusive.
2. Use black, white, and neutral grays as the visual identity. Avoid decorative green and gold accents.
3. Use contrast, spacing, typography, and image composition to establish hierarchy rather than decorative cards.
4. Preserve clear semantic states for success, warning, error, and disabled controls.
5. Keep camera capture, GPS, EXIF, physical orientation, watermark, persistence, and billing behavior independent from visual refactors.

## Color tokens

| Token | Value | Usage |
|---|---|---|
| Background | #F4F4F2 | Main light canvas |
| Surface | #FFFFFF | Cards and sheets |
| Primary / brand neutral | #171717 | Primary actions and headings |
| Secondary text | #737373 | Supporting copy |
| Border | #E4E4E4 | Dividers and outlines |
| Neutral highlight | #D8D8D8 | Selected and premium-neutral states |
| Camera background | #080808 | Camera and photo preview |
| Success | #4A4A4A | Neutral success indicator |
| Danger | #B3261E | Destructive/error state only |

The shared Flutter implementation lives in `lib/modules/pro/theme/pro_theme.dart`. The historical `brandGreen` token name is retained temporarily for source compatibility; its value is neutral black.

## Typography

- Use a strong, compact title hierarchy for editorial headings.
- Use 12–14sp for secondary information and metadata.
- Avoid long all-caps labels; reserve letter spacing for short overlines and metadata.
- Keep body copy comfortably readable with line height around 1.4–1.5.

## Shape and spacing

- Base spacing: 4 / 8 / 12 / 16 / 24 / 32.
- Standard card radius: 16–20.
- Compact control radius: 10–14.
- Use thin neutral borders before adding shadows.
- Keep touch targets at least 44 logical pixels where practical.

## Camera experience

- Full-screen viewfinder with restrained top and bottom scrims.
- Top row contains only high-value navigation and documentation actions.
- Camera controls are translucent and collapsible.
- Shutter remains the most prominent control and stays within the lower thumb zone.
- Zoom status is placed near the top of the viewfinder to avoid colliding with the bottom toolbar.
- Avoid fixed vertical offsets tied to a single device size; validate on short and tall screens.

## Photo preview

- Full-bleed image on a near-black canvas.
- Minimal header with back navigation and share action.
- Primary actions are grouped at the bottom with clear labels.
- Destructive actions require confirmation.

## Editorial archive and Pro modules

- Use the shared theme for trips, locations, settings, and premium screens.
- Prefer photo-led sections, concise metadata, and clear section labels.
- Premium presentation must not rely on gold gradients or decorative badges.
- Preserve existing database models, queries, billing flows, and export behavior.

## Accessibility and QA

- Maintain readable contrast over photos using scrims behind controls.
- Provide tooltips for icon-only actions.
- Keep text labels on important destructive and primary actions.
- Verify portrait layouts on compact and large screens.
- Verify camera initialization, camera switching, focus/exposure, timer, flash, aspect ratios, capture, preview, share, delete, GPS status, and Pro documentation flows after visual changes.
