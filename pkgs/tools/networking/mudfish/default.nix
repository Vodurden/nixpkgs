{ stdenv, fetchurl, makeWrapper

  # For patchelf
  , openssl, ncurses5, dhcp
}:

# This breaks internet resolution at the moment, so don't use it!
stdenv.mkDerivation rec {
  name = "mudfish-4.4.6";

  buildInputs = [ makeWrapper ];

  src = fetchurl {
    url = "https://mudfish.net/releases/mudfish-4.4.6-linux-x86_64.sh";
    sha256 = "0536vjd4qm0pipkwbh6mszwn1bvqsgz6ghyzqqz7q3alsjd4yvfq";
    executable = true;
  };

  buildCommand = ''
    # Extract files from installer
    ${src} --noexec --keep

    # Move extracted files into the Nix store
    mkdir -p $out/bin
    mv 4.4.6/bin/* $out/bin
    cd $out/bin

    # Remove obsolete setup files
    rm pkg_linux_setup.sh

    # Patch ELF binaries
    patchelf --set-interpreter ${stdenv.glibc}/lib/ld-linux-x86-64.so.2 \
             --set-rpath ${stdenv.lib.makeLibraryPath [stdenv.glibc]} \
             $out/bin/mudadm

    patchelf --set-interpreter ${stdenv.glibc}/lib/ld-linux-x86-64.so.2 \
             --set-rpath ${stdenv.lib.makeLibraryPath [stdenv.glibc]} \
             $out/bin/muddiag

    patchelf --set-interpreter ${stdenv.glibc}/lib/ld-linux-x86-64.so.2 \
             --set-rpath ${stdenv.lib.makeLibraryPath [stdenv.glibc]} \
             $out/bin/muddnsc

    patchelf --set-interpreter ${stdenv.glibc}/lib/ld-linux-x86-64.so.2 \
             --set-rpath ${stdenv.lib.makeLibraryPath [stdenv.glibc]} \
             $out/bin/mudfish

    patchelf --set-interpreter ${stdenv.glibc}/lib/ld-linux-x86-64.so.2 \
             --set-rpath ${stdenv.lib.makeLibraryPath [stdenv.glibc]} \
             $out/bin/mudflow

    patchelf --set-interpreter ${stdenv.glibc}/lib/ld-linux-x86-64.so.2 \
             --set-rpath ${stdenv.lib.makeLibraryPath [stdenv.glibc openssl]} \
             $out/bin/mudhttpc

    patchelf --set-interpreter ${stdenv.glibc}/lib/ld-linux-x86-64.so.2 \
             --set-rpath ${stdenv.lib.makeLibraryPath [stdenv.glibc openssl]} \
             $out/bin/mudlog

    patchelf --set-interpreter ${stdenv.glibc}/lib/ld-linux-x86-64.so.2 \
             --set-rpath ${stdenv.lib.makeLibraryPath [stdenv.glibc openssl]} \
             $out/bin/mudrun

    patchelf --set-interpreter ${stdenv.glibc}/lib/ld-linux-x86-64.so.2 \
             --set-rpath ${stdenv.lib.makeLibraryPath [stdenv.glibc ncurses5]} \
             $out/bin/mudstat

    # Wrap all binaries such that:
    #
    # - dhclient is available on the PATH
    # - /opt/mudfish/4.4.6/bin is mapped to the nix store
    # - /opt/mudfish/4.4.6/var is mapped to /var/mudfish/4.4.6/
    for f in $out/bin/*; do
      mv $f $f-wrapped
      makeWrapper $f-wrapped $f-wrapper \
        --run "mkdir -p /opt/mudfish/4.4.6/bin" \
        --run "mkdir -p /opt/mudfish/4.4.6/var" \
        --run "mount --bind $out/bin /opt/mudfish/4.4.6/bin" \
        --run "mount --bind /var/mudfish/4.4.6/ /opt/mudfish/4.4.6/var" \
        --prefix PATH : ${stdenv.lib.makeBinPath [dhcp]}

      echo "#! $SHELL -e" > "$f"
      echo unshare --mount \""$f-wrapper"\" >> "$f"
      chmod +x "$f"
    done
  '';

  dontInstall = true;

  meta = {
    homepage = https://mudfish.net;
    description = "Network Booster for Games & Streaming";
    platforms = stdenv.lib.platforms.linux;
    license = stdenv.lib.licenses.unfree;
  };
}
