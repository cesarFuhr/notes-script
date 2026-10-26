self:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.notes;
in
{
  options.programs.notes = {
    enable = lib.mkEnableOption "the notes script";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.notes;
      description = "The notes package to use.";
    };

    root = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/.notes";
      description = "Directory holding the notes git repository.";
    };

    sync = {
      enable = lib.mkEnableOption "periodic git sync of the notes repository";

      interval = lib.mkOption {
        type = lib.types.str;
        default = "15min";
        description = "How often to sync, as a systemd time span.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];
    home.sessionVariables.NOTES_ROOT = cfg.root;

    systemd.user.services.notes-sync = lib.mkIf cfg.sync.enable {
      Unit.Description = "Sync notes repository";
      Service = {
        Type = "oneshot";
        Environment = [ "NOTES_ROOT=${cfg.root}" ];
        ExecStart = "${cfg.package}/bin/notes sync";
      };
    };

    systemd.user.timers.notes-sync = lib.mkIf cfg.sync.enable {
      Unit.Description = "Sync notes repository periodically";
      Timer = {
        OnStartupSec = "2min";
        OnUnitActiveSec = cfg.sync.interval;
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
