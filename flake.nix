{
  description = "A very basic note taking script";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
  };

  outputs =
    inputs@{ self, nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
    in
    {
      homeManagerModules.default = import ./hm-module.nix self;

      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          pack =
            {
              packageName,
              buildInputs,
            }:
            let
              script =
                (pkgs.writeScriptBin packageName (builtins.readFile ./${packageName}.sh)).overrideAttrs
                  (old: {
                    buildCommand = "${old.buildCommand}\n patchShebangs $out";
                  });
            in
            pkgs.symlinkJoin {
              name = packageName;
              paths = [ script ] ++ buildInputs;
              buildInputs = [ pkgs.makeWrapper ];
              postBuild = "wrapProgram $out/bin/${packageName} --prefix PATH : $out/bin";
            };
        in
        rec {
          default = notes;
          notes = pack {
            packageName = "notes";
            buildInputs = [
              pkgs.bash
              pkgs.coreutils
              pkgs.findutils
              pkgs.fzf
              pkgs.git
              pkgs.openssh
              pkgs.ripgrep
              pkgs.tre
            ]
            ++ pkgs.lib.optional pkgs.stdenv.isLinux pkgs.util-linux;
          };
        }
      );
    };
}
