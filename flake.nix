{
  description = "A very basic note taking script";

  outputs = inputs@{ self, nixpkgs }:
    let
      forAllSystems = function:
        nixpkgs.lib.genAttrs [
          "x86_64-linux"
          "aarch64-linux"
          "x86_64-darwin"
          "aarch64-darwin"
        ]
          (system: function nixpkgs.legacyPackages.${system});
    in
    {
      defaultPackage.x86_64-linux = self.packages.x86_64-linux.notes;
      packages.x86_64-linux.notes =
        let
          pkgs = import nixpkgs { system = "x86_64-linux"; };

          pkg-name = "notes";
          pkg-buildInputs = with pkgs; [ coreutils ];
          pkg-script = (pkgs.writeScriptBin pkg-name (builtins.readFile ./notes.sh)).overrideAttrs (old: {
            buildCommand = "${old.buildCommand}\n patchShebangs $out";
          });
        in
        pkgs.symlinkJoin {
          name = pkg-name;
          paths = [ pkg-script ] ++ pkg-buildInputs;
          buildInputs = [ pkgs.makeWrapper ];
          postBuild = "wrapProgram $out/bin/${pkg-name} --prefix PATH : $out/bin";
        };
    };
}
