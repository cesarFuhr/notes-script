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
      packages = builtins.listToAttrs
        (builtins.map
          (system:
            let
              p = import nixpkgs { system = system; };

              pack = ({ packageName, buildInputs }:
                let
                  script = (p.writeScriptBin packageName (builtins.readFile ./${packageName}.sh)).overrideAttrs (old: {
                    buildCommand = "${old.buildCommand}\n patchShebangs $out";
                  });
                in
                p.symlinkJoin {
                  name = packageName;
                  paths = [ script ] ++ buildInputs;
                  buildInputs = [ p.makeWrapper ];
                  postBuild = "wrapProgram $out/bin/${packageName} --prefix PATH : $out/bin";
                });
            in
            {
              name = system;
              value = rec {
                default = notes;
                notes = pack { packageName = "notes"; buildInputs = [ p.coreutils ]; };
                todo = pack { packageName = "todo"; buildInputs = [ p.coreutils p.ripgrep ]; };
                todo-done = pack { packageName = "todo-done"; buildInputs = [ p.coreutils p.ripgrep ]; };
              };
            })
          systems);
    };
}

