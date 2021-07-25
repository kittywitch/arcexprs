{ fetchpatch }: {
  singlethread = fetchpatch {
    url = "https://github.com/arcnmx/LookingGlass/commit/f654f19606219157afe03ab5c5b965a28d3169ef.patch";
    sha256 = "0g532b0ckvb3rcahsmmlq3fji6zapihqzd2ch0msj0ygjzcgkabw";
  };
  cmake-obs-installdir = ./obs-installdir.patch;
}
