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
            mkdir -p $out/bin
            mkdir -p $out/opt/xmcl
            cp -r ./* $out/opt/xmcl/
            chmod +x $out/opt/xmcl/xmcl

            # --- Resources Setup ---
            mkdir -p $out/share/{applications,icons/hicolor,fontconfig/conf.d}

            # Font configuration
            if [ -f "${./assets/fonts.conf}" ]; then
              cp ${./assets/fonts.conf} $out/share/fontconfig/conf.d/10-xmcl-fonts.conf
            else
              touch $out/share/fontconfig/conf.d/10-xmcl-fonts.conf
            fi

            # --- Icons Setup ---
            if [ -d "${./assets/icons/hicolor}" ]; then
              for size in 16 24 32 48 64 128 256 512; do
                icon_path="${./assets/icons}/hicolor/''${size}x''${size}/apps/xmcl.png"
                if [ -f "$icon_path" ]; then
                  mkdir -p "$out/share/icons/hicolor/''${size}x''${size}/apps"
                  cp "$icon_path" "$out/share/icons/hicolor/''${size}x''${size}/apps/xmcl.png"
                fi
              done
            fi

            # --- Wrapper Setup ---
            makeWrapper $out/opt/xmcl/xmcl $out/bin/xmcl \
              --prefix LD_LIBRARY_PATH : ${pkgs.lib.makeLibraryPath runtimeDeps} \
              --set FONTCONFIG_PATH "$out/share/fontconfig" \
              --set FONTCONFIG_FILE "$out/share/fontconfig/conf.d/10-xmcl-fonts.conf" \
              --set GTK_USE_PORTAL 1 \
              --set ELECTRON_NO_UPDATER 1 \
              --set XMCL_NO_SELF_UPDATE 1 \
              --set ELECTRON_RUN_AS_NODE "" \
              --unset JAVA_HOME \
              --add-flags "--no-update-check"

            # --- Desktop Entry Setup ---
            if [ -f "${./assets/xmcl.desktop}" ]; then
              cp ${./assets/xmcl.desktop} $out/share/applications/xmcl.desktop
              sed -i "s|^Exec=.*|Exec=$out/bin/xmcl|" $out/share/applications/xmcl.desktop
              sed -i "s|^Icon=.*|Icon=xmcl|" $out/share/applications/xmcl.desktop
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
