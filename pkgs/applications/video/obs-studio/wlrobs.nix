# (the following is somewhat lifted from ./linuxbrowser.nix)
# We don't have a wrapper which can supply obs-studio plugins so you have to
# somewhat manually install this:

# nix-env -f . -iA obs-wlrobs
# mkdir -p ~/.config/obs-studio/plugins/wlrobs/bin/64bit
# ln -s ~/.nix-profile/share/obs/obs-plugins/wlrobs/bin/64bit/libwlrobs.so ~/.config/obs-studio/plugins/wlrobs/bin/64bit
{ stdenv, fetchhg, wayland, obs-studio
, meson, ninja, pkg-config, libX11
, dmabufSupport ? false, libdrm ? null, libGL ? null, lib}:

assert dmabufSupport -> libdrm != null && libGL != null;

stdenv.mkDerivation {
  pname = "obs-wlrobs";
  version = "20210105";

  src = fetchhg {
    url = "https://hg.sr.ht/~scoopta/wlrobs";
    rev = "02e7fd0062aff91c02a1915f0ca29e906877a01d";
    sha256 = "193xrm04hk2s2hlg2g6wcsvq3ava7jycfsr7a25mv3dz4k7r6kzi";
  };

  buildInputs = [ libX11 libGL libdrm meson ninja pkg-config wayland obs-studio ];

  installPhase = ''
    mkdir -p $out/share/obs/obs-plugins/wlrobs/bin/64bit
    cp ./libwlrobs.so $out/share/obs/obs-plugins/wlrobs/bin/64bit/
  '';

  mesonFlags = [
    "-Duse_dmabuf=${lib.boolToString dmabufSupport}"
  ];

  meta = with lib; {
    description = "An obs-studio plugin that allows you to screen capture on wlroots based wayland compositors";
    homepage = "https://hg.sr.ht/~scoopta/wlrobs";
    maintainers = with maintainers; [ grahamc ];
    license = licenses.gpl3;
    platforms = [ "x86_64-linux" ];
  };
}
