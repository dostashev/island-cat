# Island Cat

![Island Cat stays centered and walks as desktops, menus, and browser windows slide underneath](docs/hero.png)

## Dy*Nyaa*Mic Island

A menu bar app that turns your MacBook's dynamic island into a cat.

<table>
  <tr>
    <td><img src="docs/pet.png" alt="Petting the cat"><br>Will mrr if you pet it</td>
    <td><img src="docs/walk.png" alt="The cat walking"><br>Walks along as you swipe between desktops</td>
  </tr>
  <tr>
    <td><img src="docs/nyan.png" alt="Nyan mode"><br>Nyan mode</td>
    <td><img src="docs/skates.png" alt="Roller skates"><br>When you swipe fast - glides on roller skates…</td>
  </tr>
  <tr>
    <td><img src="docs/skateboard.png" alt="Skateboard"><br>…or a skateboard</td>
    <td><img src="docs/notch.png" alt="Coming out of the notch"><br>Uses the notch as a cat house on older Macs (click to enter)</td>
  </tr>
</table>


Made for the MacBook Pro models with a Dynamic Island (PROLED XDR).

MacBooks with a notch work too: the cat sits in the menu bar just left of the notch.

## Install

```sh
brew tap dostashev/island-cat https://github.com/dostashev/island-cat
brew trust dostashev/island-cat
brew install --cask island-cat
```

Or download the zip from the [latest release](https://github.com/dostashev/island-cat/releases/latest).

To walk along when you swipe between desktops, **the cat needs Input
Monitoring permission** (System Settings › Privacy & Security › Input
Monitoring); the app asks for it.

## Build

```sh
scripts/bundle.sh --install
```

## License

[MIT](LICENSE)
