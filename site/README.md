# Hum landing page

The marketing site for [Hum](https://github.com/rzkarsyad/Hum), the floating
karaoke lyrics app for macOS. Next.js 16 (App Router) + TypeScript + Tailwind v4,
built as a fully static export, with no server, no database and no analytics.

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

## Deploy

Live at <https://hum-rzkarsyads-projects.vercel.app>, on the Vercel project
`rzkarsyads-projects/hum`. Run from the **repo root**, not from `site/`, because the
project's Root Directory is set to `site`, and `.vercelignore` keeps the Xcode
build artifacts out of the upload:

```bash
vercel deploy --prod
```

The Git integration is deliberately disconnected: `site/` is gitignored (commit
`8388cf3`), so Vercel would have nothing to build from. Deploys are CLI-only.

### If `npm install` ever fails with `Invalid Version:`

`create-next-app` can emit a lockfile entry with no `version`, `resolved` or
`integrity`. Seen once as a nested stub for `@next/swc-win32-x64-msvc` while
every other platform binary sat correctly at the top level. `npm` only trips on
it when it rebuilds the ideal tree, so `dev` and `build` keep working locally
while any fresh `npm install` (Vercel included) dies in arborist's `canDedupe`.

```bash
# find it
python3 -c "import json;p=json.load(open('package-lock.json'))['packages'];print([k for k,v in p.items() if k and not v.get('version')])"
# fix it
rm package-lock.json && npm install --package-lock-only
```

## How it's put together

| Path | What it does |
| --- | --- |
| `lib/site.ts` | Version, download links, Homebrew command. Update here when you ship a release. |
| `lib/demo.ts` | The demo track driving the hero. Original filler lyrics, never real song lyrics. |
| `lib/icons.ts` | Generated brand marks for the "works with" row. |
| `components/LyricsWindow.tsx` | An HTML/CSS rebuild of Hum's floating panel, animating live. |
| `components/DesktopScene.tsx` | The Mac desktop the window floats over, plus `CompactScene` for phones. |
| `components/MacChrome.tsx` | The macOS menu bar and Dock. |
| `components/Specs.tsx` | The four spec tables that make up everything below the fold. |
| `components/Intro.tsx` | CSS-only entrance for above-the-fold content. |
| `components/Reveal.tsx` | Scroll-triggered entrance for everything below it. |

### Layout

The hero and its product visual run wide (896px). Everything below sits in a
600px centred column, so the page reads as one narrow ribbon. The nav is
full-bleed, so it frames the page rather than becoming a third mismatched
column on wide screens.

### The MacBook

`DesktopScene` wraps everything in a MacBook body. The screen is `aspect-[20/13]`,
which is the real MacBook Air 13" panel (2560x1664 = 1.538), not the 16/9 it
started as. The lid face is one flat near-black piece because that is how a
modern MacBook actually looks head on: black glass edge to edge with only a thin
aluminium rim. The notch is 12.18% of screen width and exactly the menu bar's
height, so it lines up instead of floating; it sits between the menu titles and
the status items, so it never covers either. Both numbers are measured, not
guessed: `NSScreen` on a MacBook Air 13.6" reports a 1470x956pt panel with
`auxiliaryTopLeftArea`/`auxiliaryTopRightArea` 645.5pt each, leaving a 179pt
notch, and a `safeAreaInsets.top` of 32pt. macOS grows the menu bar to that same
32pt on notched Macs, which is why the two heights are tied together here.

Both are sized as `h-[3.35%]` of the screen, not a fixed pixel value: 32pt of a
956pt panel. A fixed height was tuned for one scene size and came out 60% too
tall, which made the notch look wrong even though its width was right. The
percentage keeps them correct at every breakpoint. The aluminium bar underneath is the
base edge, with the finger groove cut out of the front.

### The Dock and menu bar

`components/MacChrome.tsx` draws the menu bar by hand and lays out a real Dock.
The Dock icons are not recreations: they are the actual artwork from each app
bundle on macOS 27, pulled out of the `.icns` and converted to WebP. Nineteen
icons, about 63 KB in total.

Two traps if you regenerate them. `NSWorkspace.icon(forFile:)` looks like the
obvious route but hands back whatever variant matches the *current* system
appearance, so on a Mac in Dark Mode every icon comes out dark and monochrome,
even if you force an Aqua `NSAppearance` on the drawing context. Reading
`Contents/Resources/AppIcon.icns` directly sidesteps that and always gives the
colour artwork. Trash and the Downloads folder are not apps, so they come from
`CoreTypes.bundle` instead.

```bash
# per app; AppIcon comes from CFBundleIconFile in the app's Info.plist
sips -s format png -Z 128 "<App>.app/Contents/Resources/AppIcon.icns" --out out.png

# the two non-apps
CT=/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources
sips -s format png -Z 128 "$CT/TrashIcon.icns"       --out trash.png
sips -s format png -Z 128 "$CT/DownloadsFolder.icns" --out downloads.png

cwebp -q 90 -alpha_q 100 out.png -o public/dock/<name>.webp
```

Sizing is proportional, not fixed: the Dock is 64% of the scene width and each
icon is a flex child, so an icon lands at 3.0% of screen width, which is what a
real Dock measures. `Apps` is the macOS 26 replacement for Launchpad.

### Wallpaper

`public/wallpaper.webp` is a macOS wallpaper resized to 1792px and converted to
WebP: 23 MB down to 32 KB, because smooth gradients compress extremely well.
Regenerate with `sips -Z 1792 src.png --out tmp.png && cwebp -q 82 tmp.png -o public/wallpaper.webp`.

### Brand marks

`lib/icons.ts` is generated, not hand-written. The path data came from
[Simple Icons](https://simpleicons.org) (CC0), extracted at build time so the
page carries no runtime dependency on the package. Microsoft Edge has no Simple
Icons mark, so `BrandMark` falls back to a neutral globe rather than
approximating the real logo. The marks render monochrome so the row reads as one
set; they are trademarks of their owners and appear only to say what Hum reads.

### The hero window is a recreation, not a screenshot

`LyricsWindow` mirrors the real app closely enough that the two should be changed
together. The values it copies from Swift:

- the `0.3 / 0.45 / 0.28 / 0.15` distance-from-active opacities, and the
  full-white reveal layered over the active line (`KaraokeView.lineOpacity`)
- per-character easing in from blur and a slight rise, spread across the line's
  whole duration (`AppearanceEffectRenderer` in `TextEffects.swift`)
- `dotFill(i, progress) = clamp(progress * 3 - i, 0, 1)` for the instrumental
  dots (`KaraokeItem.swift`)
- the 60px header height and 16px corner radius (`HumLayout`)

It pauses itself when scrolled out of view and freezes on a still frame under
`prefers-reduced-motion`.

The page uses flat colour throughout, with no gradients. The one `linear-gradient`
left in the codebase is the lyrics viewport's edge-fade mask, which is an opacity
ramp rather than a colour blend and mirrors `KaraokeView`'s own `.mask(...)`.
Drop it and the lyrics hard-clip at the window edges.

### Typography

The page asks for SF Pro Rounded, which cannot legally be served as a webfont.
Instead the stack leans on the `ui-rounded` generic family:

```
ui-rounded, "SF Pro Rounded", Nunito, system-ui, sans-serif
```

On macOS and iOS, in Safari and Chromium alike, `ui-rounded` resolves to the real
SF Pro Rounded and no webfont is downloaded at all. Everywhere else it falls
through to Nunito, self-hosted by `next/font`, which only gets fetched when it's
actually needed.

### Content that goes stale

`lib/site.ts` carries the version number and the "about 2.5 MB" figure, and
`components/Hero.tsx` has a release badge pointing at the changelog. Those three
are worth a glance whenever you cut a release.
