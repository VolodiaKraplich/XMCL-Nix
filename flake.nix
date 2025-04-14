{
  description = "X Minecraft Launcher (XMCL) - A modern Minecraft launcher";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # --- Version ---
        xmclVersion = "0.49.3";

        # --- Dependencies ---
        runtimeDeps = with pkgs; [
          stdenv.cc.cc.lib
          alsa-lib
          atk
          cairo
          cups
          dbus
          expat
          gdk-pixbuf
          glib
          gobject-introspection
          gtk3
          freetype
          fontconfig
          libdrm
          libGL
          libglvnd
          mesa
          xorg.libxcb
          xorg.libxshmfence
          nss
          nspr
          pango
          udev
          vulkan-loader
          xorg.libX11
          xorg.libXcomposite
          xorg.libXcursor
          xorg.libXdamage
          xorg.libXext
          xorg.libXfixes
          xorg.libXi
          xorg.libXrandr
          xorg.libXrender
          xorg.libXtst
          xorg.libxcb
          xorg.libXxf86vm
        ];
      in
      {
        packages.xmcl = pkgs.stdenv.mkDerivation {
          pname = "xmcl";
          version = xmclVersion;

          src = pkgs.fetchurl {
            url = "https://github.com/Voxelum/x-minecraft-launcher/releases/download/v${xmclVersion}/xmcl-${xmclVersion}-x64.tar.xz";
            sha256 = "562df63d78308ee0a9223baf150e13a008aa7627475a4fe8e010fd7426110e00";
          };

          nativeBuildInputs = with pkgs; [
            autoPatchelfHook
            makeWrapper
          ];

          buildInputs = runtimeDeps;

          installPhase = ''
            runHook preInstall

            # --- Basic Setup ---
            mkdir -p $out/{bin,opt/xmcl,share/{applications,icons/hicolor,fontconfig/conf.d}}
            cp -r ./* $out/opt/xmcl/
            chmod +x $out/opt/xmcl/xmcl

            # Font configuration
            if [ -f "${./assets/fonts.conf}" ]; then
              cp ${./assets/fonts.conf} $out/share/fontconfig/conf.d/10-xmcl-fonts.conf
            else
              touch $out/share/fontconfig/conf.d/10-xmcl-fonts.conf
            fi

            # --- Icons Setup ---
            if [ -d "${./assets/icons/hicolor}" ]; then
              cp -r ${./assets/icons/hicolor}/* $out/share/icons/hicolor/
            fi

            # --- Wrapper Setup ---
            makeWrapper $out/opt/xmcl/xmcl $out/bin/xmcl \
              --prefix LD_LIBRARY_PATH : ${pkgs.lib.makeLibraryPath runtimeDeps} \
              --set FONTCONFIG_PATH "$out/share/fontconfig" \
              --set FONTCONFIG_FILE "$out/share/fontconfig/conf.d/10-xmcl-fonts.conf" \
              --set GTK_USE_PORTAL 1 \
              --set APPIMAGE 1 \
              --unset JAVA_HOME \
              ${
                pkgs.lib.optionalString (builtins.getEnv "XDG_SESSION_TYPE" == "wayland") ''
                  --add-flags "--enable-features=UseOzonePlatform" \
                  --add-flags "--ozone-platform=wayland"
                ''
              } \
              --add-flags "--enable-webrtc-pipewire-capturer"

            # --- Desktop Entry Setup ---
            if [ -f "${./assets/xmcl.desktop}" ]; then
              cp ${./assets/xmcl.desktop} $out/share/applications/xmcl.desktop
              substituteInPlace $out/share/applications/xmcl.desktop \
                --replace "Exec=xmcl" "Exec=$out/bin/xmcl" \
                --replace "Icon=xmcl" "Icon=xmcl"
            fi

            runHook postInstall
          '';

          meta = with pkgs.lib; {
            description = "X Minecraft Launcher (XMCL)";
            homepage = "https://github.com/Voxelum/x-minecraft-launcher";
            license = licenses.mit;
            platforms = [ "x86_64-linux" ];
            maintainers = [
              "CI010"
              "Volodia Kraplich"
            ];
          };
        };

        packages.default = self.packages.${system}.xmcl;
      }
    );
}
