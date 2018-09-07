{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.ratbagd;
in

{

  ###### interface

  options = {
    services.ratbagd = {
      enable = mkOption {
        default = false;
        description = ''
          Whether to enable ratbagd for configuring gaming mice.
        '';
      };
    };
  };

  ###### implementation

  config = mkIf cfg.enable {
    services.dbus.packages = [ pkgs.libratbag ];

    # Give users access to the "ratbagctl" tool
    environment.systemPackages = [ pkgs.libratbag ];

    systemd.services.ratbagd = {
      description = "Daemon to introspect and modify configurable mice";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.libratbag}/bin/ratbagd";
      };
    };
  };
}
