{ fetchFromGitHub, yarn2nix, yarn, vimUtils, nodePackages }: let
  pname = "coc-git";
  version = "1.7.7";
  src = fetchFromGitHub {
    owner = "neoclide";
    repo = pname;
    rev = version;
    sha256 = "1qg3mk43wl8shx66nydykdr1vsfx4n5lmgngndwnjjkf1csppg9q";
  };
  deps = yarn2nix.mkYarnModules rec {
    inherit pname version;
    name = "${pname}-modules-${version}";
    packageJSON = src + "/package.json";
    yarnLock = src + "/yarn.lock";
    yarnNix = ./yarn.nix;
  };
in vimUtils.buildVimPluginFrom2Nix {
  inherit version pname src;

  nativeBuildInputs = with nodePackages; [ webpack-cli yarn ];
  NODE_PATH = "${nodePackages.webpack}/lib/node_modules";

  configurePhase = ''
    mkdir -p node_modules
    ln -s ${deps}/node_modules/* node_modules/
    ln -s ${deps}/node_modules/.bin node_modules/
  '';

  buildPhase = ''
    yarn build

    webpack-cli
    rm -r node_modules
  '';

  meta.broken = !(builtins.tryEval yarn2nix).success || yarn.stdenv.isDarwin;
}
