{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    theos = {
      url = "git+https://github.com/theos/theos?ref=master&submodules=1";
      flake = false;
    };
    theos-roothide = {
      url = "git+https://github.com/roothide/theos?ref=master&submodules=1";
      flake = false;
    };
    sdks = {
      url = "github:theos/sdks";
      flake = false;
    };
  };

  outputs = inputs @ {
    nixpkgs,
    theos,
    sdks,
    ...
  }: let
    forAllSystems = nixpkgs.lib.genAttrs ["aarch64-darwin"];
    config = import ./tweak-config.nix;
    profileNames = ["rootful" "rootless" "roothide"];
    defaultProfile =
      if config.packageScheme == ""
      then "rootful"
      else if builtins.elem config.packageScheme profileNames
      then config.packageScheme
      else throw "packageScheme must be rootful, rootless, roothide, or an empty string (rootful)";
    perSystem = system: let
      pkgs = import nixpkgs {inherit system;};
      inherit (pkgs) lib;
      llvm = pkgs.llvmPackages_21;
      mkTheos = source:
        pkgs.stdenvNoCC.mkDerivation {
          pname = "theos";
          version = source.shortRev or "locked";
          src = source;
          nativeBuildInputs = [pkgs.perl];
          dontBuild = true;
          dontCheckForBrokenSymlinks = true;
          installPhase = ''
            runHook preInstall
            mkdir -p "$out/share/theos"
            cp -R . "$out/share/theos/"
            chmod -R u+w "$out/share/theos"
            substituteInPlace "$out/share/theos/makefiles/master/rules.mk" \
              --replace-fail '$(THEOS_VENDOR_INCLUDE_PATH)/.git' '$(THEOS_VENDOR_INCLUDE_PATH)/substrate.h' \
              --replace-fail '$(THEOS_VENDOR_LIBRARY_PATH)/.git' '$(THEOS_VENDOR_LIBRARY_PATH)/libsubstrate.tbd'
            substituteInPlace "$out/share/theos/bin/swift-bootstrapper.pl" \
              --replace-fail '$swift_command build -c release' '$swift_command build --disable-sandbox -c release'
            patchShebangs "$out/share/theos"
            runHook postInstall
          '';
        };
      upstreamTheos = mkTheos theos;
      rootHideTheos = mkTheos inputs.theos-roothide;
      profiles = {
        rootful = {
          scheme = "";
          architecture = "iphoneos-arm";
          theos = upstreamTheos;
        };
        rootless = {
          scheme = "rootless";
          architecture = "iphoneos-arm64";
          theos = upstreamTheos;
        };
        roothide = {
          scheme = "roothide";
          architecture = "iphoneos-arm64e";
          theos = rootHideTheos;
        };
      };
      tools = with pkgs; [
        bash
        coreutils
        findutils
        gnused
        gnugrep
        gawk
        gnumake
        perl
        file
        rsync
        git
        dpkg
        xz
        gzip
        bzip2
        zstd
        unzip
        which
        llvm.clang-unwrapped
        llvm.llvm
        cctools
        cctools.libtool
        ld64
        ldid
      ];
      dpkgDeb = pkgs.writeShellScriptBin "theos-dpkg-deb" ''
        exec ${pkgs.dpkg}/bin/dpkg-deb --root-owner-group "$@"
      '';
      makeArgs = name: let
        profile = profiles.${name};
      in [
        "THEOS=${profile.theos}/share/theos"
        "THEOS_SDKS_PATH=${sdks}"
        "PL_PRIVATE_SDK=${sdks}/iPhoneOS${config.sdkVersion}.sdk"
        "TARGET_PRIVATE_FRAMEWORK_PATH=${sdks}/iPhoneOS${config.sdkVersion}.sdk/System/Library/PrivateFrameworks"
        "TARGET=iphone:clang:${config.sdkVersion}:${config.deploymentTarget}"
        "ARCHS=${lib.concatStringsSep " " config.archs}"
        "SCHEME=${name}"
        "THEOS_PACKAGE_SCHEME=${profile.scheme}"
        "THEOS_PACKAGE_ARCH=${profile.architecture}"
        "_THEOS_RELATIVE_DATA_DIR=.theos/${name}"
        "THEOS_PACKAGE_DIR=packages/${name}"

        "TARGET_LD=${llvm.clang-unwrapped}/bin/clang"
        "TARGET_LIPO=${pkgs.cctools}/bin/lipo"
        "TARGET_STRIP=${pkgs.cctools}/bin/strip"
        "TARGET_LIBTOOL=${pkgs.cctools.libtool}/bin/libtool"
        "TARGET_CODESIGN=${pkgs.ldid}/bin/ldid"
        "TARGET_CODESIGN_ALLOCATE=${pkgs.cctools}/bin/codesign_allocate"
        "TARGET_DSYMUTIL=${llvm.llvm}/bin/dsymutil"

        "ADDITIONAL_LDFLAGS=-fuse-ld=${pkgs.ld64}/bin/ld"
        "_THEOS_PLATFORM_HAS_XCODE="
        "THEOS_PLATFORM_NAME=macosx"
        "_THEOS_PLATFORM_GET_LOGICAL_CORES=echo 1"
        "THEOS_PLATFORM_DEB_COMPRESSION_TYPE=xz"
        "_THEOS_PLATFORM_DPKG_DEB=${dpkgDeb}/bin/theos-dpkg-deb"
        "FINALPACKAGE=1"
      ];
      mkMake = name:
        pkgs.writeShellApplication {
          name = "theos-make";
          runtimeInputs = tools;
          text = ''
            export SHELL=${pkgs.bash}/bin/bash
            export PATH="$PATH:/usr/bin:/bin:/usr/sbin:/sbin"
            export DEVELOPER_DIR="''${DEVELOPER_DIR:-$(/usr/bin/xcode-select -p)}"
            sdk=$(/usr/bin/xcrun --sdk iphoneos --show-sdk-path)
            clang=$(/usr/bin/xcrun --sdk iphoneos --find clang)
            clangxx=$(/usr/bin/xcrun --sdk iphoneos --find clang++)
            swift=$(/usr/bin/xcrun --find swift)
            swiftc=$(/usr/bin/xcrun --find swiftc)
            swift_support=$(mktemp -d)
            cp -R ${profiles.${name}.theos}/share/theos/vendor/swift-support/. "$swift_support/"
            cp -R ${profiles.${name}.theos}/share/theos/lib "$swift_support/theos-lib"
            chmod -R u+w "$swift_support"
            generated=()
            cleanup() {
              rm -rf -- "$swift_support"
              if (( ''${#generated[@]} )); then
                rm -f -- "''${generated[@]}"
              fi
            }
            trap cleanup EXIT

            for metadata in control Filter.plist; do
              if [[ -f "res/$metadata" ]]; then
                if [[ -e "$metadata" || -L "$metadata" ]]; then
                  echo "Both res/$metadata and $metadata exist; refusing to overwrite $metadata." >&2
                  exit 1
                fi
                generated+=("$metadata")
                cp -- "res/$metadata" "$metadata"
              fi
            done
            export TARGET_CC="$clang" TARGET_CXX="$clangxx"
            make ${lib.escapeShellArgs (makeArgs name)} \
              "ISYSROOT=$sdk" "SYSROOT=$sdk" \
              "TARGET_LD=$clang" \
              "_THEOS_TARGET_SWIFT_LDPATHS=${sdks}/iPhoneOS${config.sdkVersion}.sdk/usr/lib/swift $(dirname "$swiftc")/../lib/swift/iphoneos $sdk/usr/lib/swift" \
              "TARGET_SWIFTC=$swiftc" "_THEOS_PLATFORM_SWIFT=$swift" \
              "THEOS_VENDOR_SWIFT_SUPPORT_PATH=$swift_support" \
              "THEOS_LIBRARY_PATH=$swift_support/theos-lib" "$@"
          '';
        };
      source = lib.cleanSourceWith {
        src = ./.;
        filter = path: type: let
          name = baseNameOf path;
        in
          !(builtins.elem name [".git" ".theos" "packages" "result"])
          && !(lib.hasPrefix "result-" name)
          && lib.cleanSourceFilter path type;
      };
      mkTweak = name:
        pkgs.stdenvNoCC.mkDerivation {
          pname = "theos-tweak-${name}";
          version = "1";
          src = source;
          nativeBuildInputs = tools ++ [(mkMake name)];
          dontConfigure = true;
          buildPhase = ''
            runHook preBuild
            export HOME="$TMPDIR/home"
            mkdir -p "$HOME"
            theos-make package
            runHook postBuild
          '';
          installPhase = ''
            runHook preInstall
            mkdir -p "$out"
            for deb in packages/${name}/*.deb; do
              actual=$(dpkg-deb --field "$deb" Architecture)
              if [[ "$actual" != ${lib.escapeShellArg profiles.${name}.architecture} ]]; then
                echo "Unexpected package architecture: $actual" >&2
                exit 1
              fi
              cp "$deb" "$out/"
            done
            runHook postInstall
          '';
          dontFixup = true;
        };
      tweaks = lib.genAttrs profileNames mkTweak;
      mkInstaller = name:
        pkgs.writeShellApplication {
          name = "install-tweak";
          excludeShellChecks = ["SC2016"];
          runtimeInputs = [pkgs.openssh pkgs.coreutils (mkMake name)];
          text = ''
            host=${lib.escapeShellArg (config.device.host or "")}
            port=${lib.escapeShellArg (toString (config.device.port or 22))}
            user=${lib.escapeShellArg (config.device.user or "root")}
            host="''${THEOS_DEVICE_IP:-$host}"
            port="''${THEOS_DEVICE_PORT:-$port}"
            user="''${THEOS_DEVICE_USER:-$user}"
            if [[ -z "$host" ]]; then
              echo 'Set device.host in tweak-config.nix or export THEOS_DEVICE_IP.' >&2
              exit 1
            fi
            destination="$user@$host"
            ssh_command="''${THEOS_SSH:-/usr/bin/ssh}"
            package_dir=$(mktemp -d)
            trap 'rm -rf -- "$package_dir"' EXIT
            theos-make package "THEOS_PACKAGE_DIR=$package_dir"
            shopt -s nullglob
            packages=("$package_dir"/*.deb)
            if (( ''${#packages[@]} == 0 )); then
              echo 'Build produced no Debian packages.' >&2
              exit 1
            fi
            for deb in "''${packages[@]}"; do
              "$ssh_command" -p "$port" "$destination" \
                ${lib.escapeShellArg "set -eu; package=$(mktemp /tmp/theos.XXXXXXXX); trap 'rm -f \"$package\"' EXIT; cat > \"$package\"; dpkg -i \"$package\""} < "$deb"
            done
            ${lib.optionalString ((config.device.restartCommand or "") != "") ''
              "$ssh_command" -p "$port" "$destination" ${lib.escapeShellArg config.device.restartCommand}
            ''}
          '';
        };
      installApp = name: {
        type = "app";
        program = "${mkInstaller name}/bin/install-tweak";
        meta.description = "Build and install the ${name} package over SSH";
      };
      mkShell = name:
        pkgs.mkShellNoCC {
          packages = tools ++ [(mkMake name)];
          THEOS = "${profiles.${name}.theos}/share/theos";
          THEOS_SDKS_PATH = "${sdks}";
          PL_PRIVATE_SDK = "${sdks}/iPhoneOS${config.sdkVersion}.sdk";
        };
    in {
      packages =
        tweaks
        // {
          default = tweaks.${defaultProfile};
          all = pkgs.linkFarm "theos-tweak-all" (map (name: {
              inherit name;
              path = tweaks.${name};
            })
            profileNames);
        };
      checks = tweaks;
      apps =
        lib.listToAttrs (map (name: {
            name = "install-${name}";
            value = installApp name;
          })
          profileNames)
        // {install = installApp defaultProfile;};
      devShells = lib.genAttrs profileNames mkShell // {default = mkShell defaultProfile;};
    };
  in {
    packages = forAllSystems (system: (perSystem system).packages);
    checks = forAllSystems (system: (perSystem system).checks);
    apps = forAllSystems (system: (perSystem system).apps);
    devShells = forAllSystems (system: (perSystem system).devShells);
  };
}
