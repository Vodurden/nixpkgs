{ stdenv, lib, buildFHSUserEnv, writeScript
, cabextract, gettext, glxinfo, gnupg1compat, icoutils, imagemagick, netcat-gnu
, p7zip, python2Packages, unzip, wget, wine, xdg-user-dirs, xterm, pkgs, pkgsi686Linux
, which, curl
}:

let
  wineDependencies = [
    # needed by downloaded wine's
    pkgs.freetype
    pkgs.libcap
    pkgs.libpng
    pkgs.libjpeg
    pkgs.cups
    pkgs.lcms2
    pkgs.gettext
    pkgs.dbus
    pkgs.mpg123
    pkgs.openal
    pkgs.cairo
    pkgs.libtiff
    pkgs.unixODBC
    pkgs.samba4
    pkgs.ncurses
    pkgs.libva-full
    pkgs.libpcap
    pkgs.libv4l
    pkgs.saneBackends
    pkgs.gsm
    pkgs.libgphoto2
    pkgs.openldap
    pkgs.fontconfig
    pkgs.alsaLib
    pkgs.libpulseaudio
    pkgs.xorg.libXinerama
    pkgs.udev
    pkgs.gst_all_1.gstreamer
    pkgs.gst_all_1.gst-plugins-base
    pkgs.gst_all_1.gst-plugins-good
    pkgs.gst_all_1.gst-plugins-bad
    pkgs.gst_all_1.gst-plugins-ugly
    pkgs.gst_all_1.gst-libav
    pkgs.gtk3
    pkgs.glib
    pkgs.opencl-headers
    pkgs.ocl-icd
    pkgs.libxml2
    pkgs.libxslt
    pkgs.openssl
    pkgs.gnutls
    pkgs.libGLU
    pkgs.libGLU_combined
    pkgs.libGL.osmesa
    pkgs.libdrm

    pkgs.xorg.libX11
    pkgs.xorg.libXi
    pkgs.xorg.libXcursor
    pkgs.xorg.libXrandr
    pkgs.xorg.libXrender
    pkgs.xorg.libXxf86vm
    pkgs.xorg.libXcomposite
    pkgs.xorg.libXext
  ];

  extraLDFlags=(lib.concatStringsSep " " (map (path: "-rpath " + path) (
    map (x: "${lib.getLib x}/lib") ([ stdenv.cc.cc ] ++ wineDependencies)
    # libpulsecommon.so is linked but not found otherwise
    ++ (map (x: "${lib.getLib x}/lib/pulseaudio") [ pkgs.libpulseaudio ])
  )));

in buildFHSUserEnv {
  name = "playonlinux-fhs";

  targetPkgs = pkgs: with pkgs; [
    playonlinuxPackages.playonlinux
  ];

  multiPkgs = pkgs: with pkgs; [
    # needed by playonlinux
    wine
    xlibs.libX11
    cabextract
    python2Packages.python
    python2Packages.wxPython
    python2Packages.setuptools
    gettext
    glxinfo
    gnupg1compat
    icoutils
    imagemagick
    netcat-gnu
    p7zip
    unzip
    wget
    xdg-user-dirs
    xterm
    which
    curl
  ] ++ wineDependencies;

  profile = ''
    export NIX_LDFLAGS="${extraLDFlags} $NIX_LDFLAGS"
  '';

  runScript = writeScript "playonlinux-wrapper.sh" ''
    echo "LDFlags are:"
    echo $NIX_LDFLAGS
    exec playonlinux "$@"
  '';
}
