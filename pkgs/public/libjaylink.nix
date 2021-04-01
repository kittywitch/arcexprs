{ stdenv, fetchgit, autoreconfHook, pkgconfig, libusb1 }: stdenv.mkDerivation {
  pname = "libjaylink";
  version = "2021-03-14";
  nativeBuildInputs = [ pkgconfig autoreconfHook ];
  buildInputs = [ libusb1 ];

  src = fetchgit {
    #url = "git://git.zapb.de/libjaylink.git"; # appears to be down?
    url = "git://repo.or.cz/libjaylink.git";
    rev = "6654e2be5e7a6ae3eb9d66174f965a0db19d1172";
    sha256 = "0s8x67qsl86lalc765rrwa9xr9q0qcj8ss01f8raka4rdv1iv1cp";
  };
}
