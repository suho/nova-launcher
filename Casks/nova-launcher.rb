cask "nova-launcher" do
  version :latest
  sha256 :no_check

  url "git@github.com:suho/nova-launcher.git",
      using:  :git,
      branch: "main"
  name "Nova Launcher"
  desc "Keyboard-first launcher for local applications"
  homepage "https://github.com/suho/nova-launcher"

  depends_on macos: ">= :tahoe"

  app "dist/NovaLauncher.app"

  preflight do
    system_command "/bin/bash",
                   args: [
                     "-c",
                     "cd \"$1\" && ./script/build_and_run.sh --bundle",
                     "nova-launcher-build",
                     staged_path.to_s,
                   ]
  end

  uninstall quit: "dev.suho.NovaLauncher"

  zap trash: "~/Library/Preferences/dev.suho.NovaLauncher.plist"
end
