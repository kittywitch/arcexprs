{
  i3gopher = import ./i3gopher;
  paswitch = import ./paswitch.nix;
  base16-shell = import ./base16-shell.nix;
  clip = import ./clip.nix;
  nvflash = import ./nvflash.nix;
  nvidia-vbios-vfio-patcher = import ./nvidia-vbios-vfio-patcher;
  nvidia-capture-sdk = import ./nvidia-capture-sdk.nix;
  edfbrowser = import ./edfbrowser;
  mdloader = import ./mdloader.nix;
  muFFT = import ./mufft.nix;
  libjaylink = import ./libjaylink.nix;
  openocd-git = import ./openocd-git.nix;
  gst-plugin-cedar = import ./gst-plugin-cedar;
  gst-jpegtrunc = import ./gst-jpegtrunc.nix;
  gst-protectbuffer = import ./gst-protectbuffer.nix;
  gst-rtsp-launch = import ./gst-rtsp-launch;
  vocoder-ladspa = import ./vocoder-ladspa.nix;
  zsh-completions-abduco = import ./zsh-completions-abduco.nix;
  wireplumber = import ./wireplumber.nix;
}
// (import ./droid.nix)
// (import ./weechat)
// (import ./looking-glass)
// (import ./crates)
// (import ./linux)
// (import ./ryzen-smu)
// (import ./matrix)
// (import ./firefox)
// (import ./pass)
// (import ../git)
