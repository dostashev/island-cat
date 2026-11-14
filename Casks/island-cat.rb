cask "island-cat" do
  version "0.1.1"
  sha256 "49301b3762460d8fa0193beeae898e58e543c8e1e8716f5e1a13323152925f0a"

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
