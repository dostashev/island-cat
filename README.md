# Island Cat

A tiny menu bar app that turns your MacBook's camera island into a black cat.
It draws ears, whiskers and a tail around the island, as if the island were the
cat's body. The tail sways and an ear flicks now and then; bring the pointer
close and the cat perks up, and when the island grows under the pointer, the
cat grows with it.

- **Pet it.** Rest the pointer on the cat for a few seconds and it mrrps back.
- **Walks with you.** Swipe between desktops and the cat steps along with your
  fingers, staying on the island while the desktops slide under it. Turn on
  **Nyan Mode** for a rainbow trail, or have it glide through the rest of the
  slide on roller skates or a skateboard.
- **Counts its steps.** The menu shows how far it has walked, in meters of your
  screen.
- **Stays out of the way.** It sits above the menu bar on every desktop,
  including full-screen apps, never takes a click, and follows Reduce Motion.
- On a notched Mac the notch becomes the cat's body. Screens without a camera
  get no cat.

## Install

With [Homebrew](https://brew.sh):

```sh
brew tap dostashev/island-cat https://github.com/dostashev/island-cat
brew trust dostashev/island-cat
brew install --cask island-cat
```

Homebrew only loads casks from taps outside its own once you trust them;
`brew trust` does that for this one.

Or download `Island-Cat-<version>.zip` from the
[latest release](https://github.com/dostashev/island-cat/releases/latest),
unzip it and move **Island Cat** to Applications.

Island Cat needs macOS 14 or later. It is not notarized, so the first time you
open it macOS blocks it: open it once, then allow it in System Settings ›
Privacy & Security ("Island Cat" was blocked › Open Anyway).

The cat icon in the menu bar has the settings:

| Item | What it does |
| --- | --- |
| Show Cat | Shows or hides the cat. |
| Open at Login | Starts Island Cat when you log in. |
| Walk When Switching Desktops | Has the cat walk while you swipe between desktops (on by default). |
| Nyan Mode | Trails a rainbow behind the walking cat. |
| Glide On | What the cat glides on after you lift your fingers: roller skates, a skateboard, or nothing. |

Walking needs **Input Monitoring** (System Settings › Privacy & Security ›
Input Monitoring) to see the trackpad's desktop-swipe gesture as it happens;
Island Cat asks for it and starts walking as soon as it's on. It reads only
that gesture.

To uninstall: `brew uninstall --cask island-cat` (add `--zap` to remove its
settings too), or quit it from the menu and delete the app.

## How it works

- `Sources/IslandCatCore` finds the island from what `NSScreen` reports (the
  areas beside the camera, the safe-area inset and the menu bar's height) and
  holds the cat's art and motion: the walk, the hover timing, petting.
- `Sources/IslandCat` is the app: a click-through panel per screen, drawn with
  Core Animation shape layers, and the menu bar item.
- To stay on the island while the desktops slide, the cat lives in its own
  WindowServer space above the desktops, set up with private SkyLight calls.
  If a macOS release drops them, the cat still shows on every desktop but
  slides with each swipe.
- While macOS finishes a desktop slide after you lift your fingers, it does not
  draw any app's windows, so the cat cannot animate through that part; it
  tucks its legs away (or gets on its skates) the moment you let go.

## Build from source

Needs the Xcode Command Line Tools (`xcode-select --install`).

```sh
scripts/bundle.sh --install   # builds a universal "Island Cat.app" into /Applications and opens it
swift run                     # or run straight from the package
scripts/test.sh               # tests
```

`scripts/bundle.sh` alone builds into `build/`. It signs the app with
"Island Cat Local Signing" when that identity exists
(`scripts/make-signing-identity.sh` creates a self-signed one), so macOS keeps
permissions such as Input Monitoring across rebuilds; otherwise it signs ad
hoc.

Other scripts:

- `scripts/make-icon.sh` redraws the app icon from the menu bar icon's drawing.
- `swift scripts/measure-island.swift 60` records how the island grows under
  the pointer, frame by frame.
- `scripts/release.sh` builds the release zip for the version in
  `Resources/Info.plist` and points `Casks/island-cat.rb` at it.

## License

[MIT](LICENSE)
