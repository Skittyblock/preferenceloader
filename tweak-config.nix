{
  sdkVersion = "16.5";
  deploymentTarget = "15.0";
  archs = ["arm64" "arm64e"];
  packageScheme = "roothide"; # rootful, rootless, or roothide.

  device = {
    restartCommand = "killall Preferences || true";
  };
}
