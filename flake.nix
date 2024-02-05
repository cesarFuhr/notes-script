{
  description = "A very basic note taking scripts";

  outputs = { self, nixpkgs }: {
    packages.x86_64-linux.default = self.packages.x86_64-linux.my-script;

    packages.x86_64-linux.notes =
      let
        pkgs = import nixpkgs { system = "x86_64-linux"; };

        my-name = "my-script";
        my-script = (pkgs.writeScriptBin my-name (builtins.readFile ./notes.sh)).overrideAttrs (old: {
          buildCommand = "${old.buildCommand}\n patchShebangs $out";
        });

        my-buildInputs = with pkgs; [ coreutils ];
      in
      pkgs.symlinkJoin {
        name = my-name;
        paths = [ my-script ] ++ my-buildInputs;
        buildInputs = [ pkgs.makeWrapper ];
        postBuild = "wrapProgram $out/bin/${my-name} --prefix PATH : $out/bin";
      };
  };
}
