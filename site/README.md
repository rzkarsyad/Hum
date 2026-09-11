# Hum — landing page

The marketing site for [Hum](https://github.com/rzkarsyad/Hum), the floating
karaoke lyrics app for macOS. Next.js 16 (App Router) + TypeScript + Tailwind v4,
built as a fully static export — no server, no database, no analytics.

## Develop

```bash
npm --prefix site install
npm --prefix site run dev
```

## Build

```bash
npm --prefix site run build
```

`output: "export"` writes a static site to `site/out/`, which drops straight into
GitHub Pages, Vercel, Netlify or any bucket. For GitHub Pages under a repo path,
add `basePath: "/Hum"` to `next.config.ts` first.

## How it's put together

| Path | What it does |
| --- | --- |
| `lib/site.ts` | Version, download links, Homebrew command. Update here when you ship a release. |
| `lib/demo.ts` | The demo track driving the hero. Original filler lyrics, never real song lyrics. |
| `components/LyricsWindow.tsx` | An HTML/CSS rebuild of Hum's floating panel, animating live. |
| `components/DesktopScene.tsx` | The stylised Mac desktop the window floats over. Flat fill, no gradient. |
| `components/Intro.tsx` | CSS-only entrance for above-the-fold content. |
| `components/Reveal.tsx` | Scroll-triggered entrance for everything below it. |

### The hero window is a recreation, not a screenshot

`LyricsWindow` mirrors the real app closely enough that the two should be changed
together. The values it copies from Swift:

- the `0.3 / 0.45 / 0.28 / 0.15` distance-from-active opacities, and the
  full-white reveal layered over the active line — `KaraokeView.lineOpacity`
- per-character easing in from blur and a slight rise, spread across the line's
  whole duration — `AppearanceEffectRenderer` in `TextEffects.swift`
- `dotFill(i, progress) = clamp(progress * 3 - i, 0, 1)` for the instrumental
  dots — `KaraokeItem.swift`
- the 60px header height and 16px corner radius — `HumLayout`

It pauses itself when scrolled out of view and freezes on a still frame under
`prefers-reduced-motion`.

The page uses flat colour throughout — no gradients. The one `linear-gradient`
left in the codebase is the lyrics viewport's edge-fade mask, which is an opacity
ramp rather than a colour blend and mirrors `KaraokeView`'s own `.mask(...)`.
Drop it and the lyrics hard-clip at the window edges.

### Typography

The page asks for SF Pro Rounded, which cannot legally be served as a webfont.
Instead the stack leans on the `ui-rounded` generic family:

```
ui-rounded, "SF Pro Rounded", Nunito, system-ui, sans-serif
```

On macOS and iOS — Safari and Chromium alike — `ui-rounded` resolves to the real
SF Pro Rounded and no webfont is downloaded at all. Everywhere else it falls
through to Nunito, self-hosted by `next/font`, which only gets fetched when it's
actually needed.

### Content that goes stale

`lib/site.ts` carries the version number and the "about 2.5 MB" figure, and
`components/Hero.tsx` has a release badge pointing at the changelog. Those three
are worth a glance whenever you cut a release.
