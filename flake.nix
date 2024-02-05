{
  description = "A very basic note taking script";

  outputs = { self, nixpkgs }: {
    packages.x86_64-linux.default = self.packages.x86_64-linux.notes;

    packages.x86_64-linux.notes =
      let
        pkgs = import nixpkgs { system = "x86_64-linux"; };

        my-name = "notes";
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
