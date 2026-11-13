# Island Cat

A tiny menu bar app that turns your MacBook's camera island into a black cat.
It draws ears, whiskers and a tail around the Dynamic Island, as if the island
were the cat's body. The tail sways and an ear flicks now and then; bring the
pointer close and the cat perks up.

- Sits above the menu bar on every desktop, including full-screen apps, and
  stays on the island while you swipe between desktops or open Mission
  Control. (It lives in its own WindowServer space above the desktops, set up
  with private SkyLight calls; if a macOS release drops them, the cat still
  shows on every desktop but slides with each swipe.)
- Never takes a click: the pointer passes straight through to the menu bar.
- Follows Reduce Motion (System Settings › Accessibility › Display).
- On a notched Mac the notch becomes the cat's body.
- Screens without a camera get no cat.

## Install

Requires macOS 14 or later and the Xcode Command Line Tools (`xcode-select --install`).

```sh
scripts/bundle.sh --install   # builds "Island Cat.app" into /Applications and opens it
```

The cat icon in the menu bar has **Show Cat**, **Open at Login** and **Quit**.

`scripts/bundle.sh` alone builds a universal app into `build/`. It signs it
with "Island Cat Local Signing" when that identity exists
(`scripts/make-signing-identity.sh` creates a self-signed one), so macOS keeps
its permissions across rebuilds; otherwise it signs ad hoc. It is not
notarized, so on another Mac open it once with right-click › Open.

**Walk When Switching Desktops** (off by default) has the cat step in
place while you swipe between desktops, following your fingers. Seeing the
swipe as it happens needs Input Monitoring permission (System Settings ›
Privacy & Security › Input Monitoring); the app asks for it.

## Develop

```sh
swift run            # run straight from the package
scripts/test.sh      # geometry and layout tests
swift scripts/measure-island.swift 60   # record how the island grows under the pointer
```

- `Sources/IslandCatCore` finds the island from what `NSScreen` reports (the
  areas beside the camera, the safe-area inset and the menu bar's height) and
  holds the cat's art and motion.
- `Sources/IslandCat` is the app: a click-through panel per screen, drawn with
  Core Animation shape layers, and the menu bar item.

## License

MIT
