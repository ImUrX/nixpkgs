{
  stdenv,
  lib,
  fetchFromGitHub,
  fetchurl,
  fetchzip,
  makeDesktopItem,
  copyDesktopItems,
  wrapGAppsHook3,
  pkg-config,
  cargo,
  rustc,
  husky,
  rustPlatform,
  openssl,
  glib-networking,
  libsoup,
  webkitgtk_4_1,
  temurin-jre-bin-17,
  # slime-server libs
  eudev,
  libusb1,
  # rpath libs of gui
  gobject-introspection,
  gst_all_1,
  withAppIndicator ? stdenv.hostPlatform.isLinux,
  libayatana-appindicator,
}:
rustPlatform.buildRustPackage rec {
  pname = "slimevr";
  version = "0.13.2";

  src = fetchFromGitHub {
    owner = "SlimeVR";
    repo = "SlimeVR-Server";
    rev = "v" + version;
    # includes the schema used for ipc between the server and the GUI
    fetchSubmodules = true;
    hash = "sha256-XQDbP+LO/brpl7viSxuV3H4ALN0yIkj9lwr5eS1txNs=";
  };

  cargoHash = "sha256-NveGaG8lJd6L/df++UshKdGXT0hUDJBh8MZ9cANwU24=";

  jar = fetchurl {
    url = "https://github.com/SlimeVR/SlimeVR-Server/releases/download/v${version}/slimevr.jar";
    hash = "sha256-s6uznJtsa1bQAM1QIdBMey+m9Q/v2OfKQPXjD5RAR78=";
  };

  guiHtml = fetchzip {
    url = "https://github.com/SlimeVR/SlimeVR-Server/releases/download/v${version}/slimevr-gui-dist.tar.gz";
    stripRoot = false;
    hash = "sha256-u1EtSG1uTGIyROo5TznzQ+Z8g6WAiU0SmDObm/w1f9k=";
  };

  nativeBuildInputs = [
    # required things for building
    cargo
    rustc
    husky
    pkg-config
    wrapGAppsHook3
    copyDesktopItems
  ];

  buildInputs = [
    openssl
    glib-networking
    libsoup
    webkitgtk_4_1

    gobject-introspection
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
  ];

  preBuild = ''
    pushd gui
    cp -r ${guiHtml} dist
    popd
  '';

  desktopItems = [
    # Based on https://github.com/SlimeVR/SlimeVR-Server/blob/main/gui/src-tauri/dev.slimevr.SlimeVR.desktop
    (makeDesktopItem {
      name = "SlimeVR";
      exec = "slimevr";
      icon = "slimevr";
      desktopName = "SlimeVR";
      comment = meta.description;
      genericName = "Full-body tracking";
      keywords = [
        "FBT"
        "VR"
        "Steam"
        "VRChat"
        "IMU"
      ];
      categories = [
        "Game"
        "Development"
        "GTK"
      ];
    })
  ];

  preInstall = ''
    install -Dm644 ${jar} $out/share/slimevr/slimevr.jar
    install -Dm644 ${src}/gui/src-tauri/icons/icon.svg $out/share/icons/hicolor/scalable/apps/slimevr.svg
  '';

  runtimeDependencies = [
    eudev
    libusb1
  ] ++ lib.optional withAppIndicator libayatana-appindicator;

  dontWrapGApps = true;

  preFixup =
    let
      libraryPath = lib.makeLibraryPath runtimeDependencies;
    in
    ''
      #JAVA_HOME needs to be set for the gui to be able to launch the slime server.
      #Same for the --add-flags.
      #The LD_LIBRARY_PATH is needed for the slime server to not crash when loading bundled hdapi libraries.
      #We can't modify them right now, because the jar is signed.
      #GST_PLUGIN_SYSTEM_PATH_1_0 is needed to hopefully fix the GStreamer plugins not being recognised.
      wrapProgram $out/bin/slimevr \
        "''${gappsWrapperArgs[@]}" \
        --set-default JAVA_HOME "${temurin-jre-bin-17.home}" \
        --prefix LD_LIBRARY_PATH : ${libraryPath} \
        --add-flags "--launch-from-path $out/share/slimevr/"
    '';

  meta = with lib; {
    homepage = "https://github.com/SlimeVR/SlimeVR-Server";
    description = "An app for facilitating full-body tracking in virtual reality";
    mainProgram = "slimevr";
    license = with licenses; [
      mit
      asl20
    ];
    maintainers = with maintainers; [ imurx ];
    # supports macOS but don't have a way to test
    platforms = with platforms; linux;
  };
}
