# PreferenceLoader

this is a quick fork of the most updated preferenceloader version i could find that hacks in support for ios 27+.
this has only been tested on an iphone on 27.0 with a few preference bundles so i am unsure about ipad support or anything else.

## building

i use nix-darwin, with xcode set up on my mac (the build isn't completely self-contained in the nix flake).
you can probably skip the nix stuff if you set up your environment correctly and just use `make`.

for lsp support (optional):
```sh
nix develop -c theos-make commands
```

build:
```sh
nix build
```

build and install to device:
```sh
nix run .#install
```
note you can either set `THEOS_DEVICE_IP` as usual, or edit `tweak-config.nix` and set `device.host`.

the default building scheme is for roothide jailbreaks, but you can update `packageScheme` in `tweak-config.nix`, or e.g. `nix run .#install-rootless`.

## license

the original license, GNU Lesser General Public License (LGPL), version 3, is retained.
