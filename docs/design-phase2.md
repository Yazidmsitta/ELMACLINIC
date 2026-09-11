# ELMA shell — Phase 2

Reference: [Elmaclinic app, Figma Make](https://www.figma.com/make/kIkeh84KnP84ySK7fjn3VE/Elmaclinic-app), Version 19, inspected 9 September 2026.

The connected Figma `get_design_context` call returned the Make source inventory. Its resource links could not be read through the resource adapter. Implementation therefore uses the previously inspected Make source files plus a fresh signed-in browser preview. The original PNG and SVG logo files were exported from the live preview's asset inventory. SVG icons retain the exact geometry from `src/icons.tsx`; no replacement icon set was drawn.

## Implemented mapping

| Reference | Flutter implementation |
| --- | --- |
| `index.css` | Central `ElmaColors`, `ElmaType`, `ElmaSpace`, `ElmaRadii`, `ElmaDecor` and application theme |
| `Login.tsx` | Olive gradient, original logo, serif welcome, rounded white form panel, uppercase labels, password visibility, session preference and busy/error states |
| `App.tsx` | Five-tab bottom navigation, outlined glyphs and selected Home variant, Android safe areas/back behavior |
| `Dashboard.tsx` | Header, two-column metric cards, website booking notice, primary CTA, schedule cards, ADMIN revenue area and quick actions |
| `More.tsx` | Clinic identity card, grouped menus, role-specific entries and account/logout card |

The Make SVG logo is a raster-pattern crop. Flutter SVG does not render that pattern fill, so `ElmaBrandMark` reproduces its original 125×184 viewport and -345px source offset using the unchanged original PNG. This is the same logo geometry, not a newly drawn mark.

Fonts are bundled for offline use: [Plus Jakarta Sans and DM Serif Display](https://github.com/google/fonts) and [Noto Color Emoji](https://github.com/googlefonts/noto-emoji) for the reference's emoji indicators. Their upstream license files are included alongside the fonts. Branding remains user-supplied clinic artwork.

## Required deviations from the prototype

- Real Supabase authentication; no email-derived roles or guest fallback.
- Real API dashboard results; fixture people, revenues, booking counts and growth percentages exist only in tests.
- USER sees no revenue cards, charts, Reports, user management or clinic settings. The dashboard RPC itself omits financial keys for USER.
- Labels use Clients and Praticiennes. Website and manual sources display Site web and Manuel.
- No fake iPhone frame, clock, Dynamic Island or home indicator. Native Android insets are respected.
- Forgot-password currently explains how to contact the administrator. It does not claim to send email.
- Deferred modules and writes open an honest availability sheet. This phase does not implement catalog CRUD, booking synchronization or appointment forms.
- Status, loading, empty and retry layouts use the same palette/components. No data is converted to zero on a failed request.

## Visual verification

Windows Flutter render baselines are in `mobile/test/goldens/`: login, ADMIN/USER dashboard, ADMIN/USER Plus, empty and error. Fonts and logo bytes are loaded before capture. These are native Flutter test renders, not Android emulator screenshots. Data in populated renders is explicitly synthetic.

Run on the pinned Flutter version:

```sh
flutter test --exclude-tags visual
flutter test --tags visual
```

Visual baselines were generated on Windows with real shadows; CI runs them on Windows to avoid platform raster differences. Standard functional tests also run on Linux. Tests cover 390px reference width, 360px empty/error states and a 320px login with 1.5× text and a 300px keyboard inset. A physical Android visual review is still required before release.
