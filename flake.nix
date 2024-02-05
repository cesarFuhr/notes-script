{
  description = "A very basic note taking script";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        my-name = "notes";
        my-buildInputs = with pkgs; [ coreutils ];
        my-script = (pkgs.writeScriptBin my-name (builtins.readFile ./notes.sh)).overrideAttrs (old: {
          buildCommand = "${old.buildCommand}\n patchShebangs $out";
        });
      in
      rec {
        defaultPackage = packages.notes;
        packages.notes = pkgs.symlinkJoin {
          name = my-name;
          paths = [ my-script ] ++ my-buildInputs;
          buildInputs = [ pkgs.makeWrapper ];
          postBuild = "wrapProgram $out/bin/${my-name} --prefix PATH : $out/bin";
        };
      }
    );
}
