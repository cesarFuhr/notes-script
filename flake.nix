{
  description = "A very basic note taking script";
  outputs = inputs@{ self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

    in
    {
      packages = builtins.listToAttrs (builtins.map
        (system: {
          name = system;
          value = {
            default = self.packages.${system}.notes;
            notes =
              let
                pkgs = import nixpkgs {
                  system = system;
                };
                my-name = "notes";
                my-buildInputs = with pkgs; [ coreutils ];
                my-script = (pkgs.writeScriptBin my-name (builtins.readFile ./notes.sh)).overrideAttrs (old: {
                  buildCommand = "${old.buildCommand}\n patchShebangs $out";
                });
              in
              pkgs.symlinkJoin {
                name = my-name;
                paths = [ my-script ] ++ my-buildInputs;
                buildInputs = [ pkgs.makeWrapper ];
                postBuild = "wrapProgram $out/bin/${my-name} --prefix PATH : $out/bin";
              };
          };
        })
        systems
      );
    };
}
