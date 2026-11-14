# Island Cat

![Island Cat](docs/hero.png)

<table>
  <tr>
    <td><img src="docs/pet.png" alt="Petting the cat"><br>Rest the pointer on it to pet it</td>
    <td><img src="docs/walk.png" alt="The cat walking"><br>Walks along as you swipe between desktops</td>
  </tr>
  <tr>
    <td><img src="docs/nyan.png" alt="Nyan mode"><br>Nyan mode</td>
    <td><img src="docs/skates.png" alt="Roller skates"><br>Glides on roller skates…</td>
  </tr>
  <tr>
    <td><img src="docs/skateboard.png" alt="Skateboard"><br>…or a skateboard</td>
    <td></td>
  </tr>
</table>

A menu bar app that turns your MacBook's camera island into a cat. Pet it by
resting the pointer on it, and it walks along when you swipe between desktops.

Made for the MacBook Pro models with a Dynamic Island (PROLED), where the
island becomes the cat's body. MacBooks with a notch work too: the cat sits
in the menu bar just left of the notch.

## Install

```sh
brew tap dostashev/island-cat https://github.com/dostashev/island-cat
brew trust dostashev/island-cat
brew install --cask island-cat
```

Or download the zip from the [latest release](https://github.com/dostashev/island-cat/releases/latest).

To walk along when you swipe between desktops, the cat needs Input
Monitoring permission (System Settings › Privacy & Security › Input
Monitoring); the app asks for it.

## Build

```sh
scripts/bundle.sh --install
```

## License

[MIT](LICENSE)
