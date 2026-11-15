# Island Cat

![Island Cat stays centered and walks as desktops, menus, and browser windows slide underneath](docs/hero.png)

## Dy*Nyaa*Mic Island

A menu bar app that turns your MacBook's dynamic island into a cat.

<table>
  <tr>
    <td width="50%" align="center"><img src="docs/pet.png" alt="Hovering over the cat makes it mrr in an animated bubble"><br>Will mrr if you pet it</td>
    <td width="50%" align="center"><img src="docs/nyan.png" alt="The walking cat trails a rainbow that switches sides when it turns"><br>Nyan mode</td>
  </tr>
  <tr>
    <td colspan="2" align="center"><img src="docs/notch.png" width="340" alt="Clicking the cat sends it through the notch door, then it comes back out"><br>Uses the notch as a cat house on older Macs (click to enter)</td>
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
