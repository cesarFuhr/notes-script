{
  description = "A very basic note taking script";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
  };

  outputs =
    inputs@{ nixpkgs, ... }:
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
            buildInputs = [ pkgs.coreutils ];
          };
          todo = pack {
            packageName = "todo";
            buildInputs = [
              pkgs.coreutils
              pkgs.ripgrep
            ];
          };
          todo-done = pack {
            packageName = "todo-done";
            buildInputs = [
              pkgs.coreutils
              pkgs.ripgrep
            ];
          };
        }
      );
    };
}
