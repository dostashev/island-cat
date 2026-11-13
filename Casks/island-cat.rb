cask "island-cat" do
  version "0.1.0"
  sha256 "5a591c6671c589ddead5c7adff05c6acf6f9d829b5ff45843eb7397b63dadb7c"

  url "https://github.com/dostashev/island-cat/releases/download/v#{version}/Island-Cat-#{version}.zip"
  name "Island Cat"
  desc "Turns the MacBook camera island into a cat"
  homepage "https://github.com/dostashev/island-cat"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :sonoma

  app "Island Cat.app"

  uninstall quit: "com.dostashev.IslandCat"

  zap trash: "~/Library/Preferences/com.dostashev.IslandCat.plist"

  caveats <<~EOS
    Island Cat is not notarized, so macOS blocks it the first time you open it.
    Open it once, then allow it in System Settings > Privacy & Security
    ("Island Cat" was blocked > Open Anyway).
  EOS
end
