{ config, lib, pkgs, ... }:
let
  cfg = config.services.sbws;
  
  config_file = pkgs.writeText "sbws.ini" (lib.generators.toINI {} ({
    general = {
      data_period = cfg.general.data_period;
      http_timeout = cfg.general.http_timeout;
      circuit_timeout = cfg.general.circuit_timeout;
      reset_bw_ipv4_changes = if cfg.general.reset_bw_ipv4_changes then "on" else "off";
    };
    
    paths = {
      sbws_home = cfg.paths.sbws_home;
      datadir = cfg.paths.sbws_home + "/" + cfg.paths.datadir;
      v3bw_dname = cfg.paths.sbws_home + "/" + cfg.paths.v3bw_dname;
      v3bw_fname = cfg.paths.sbws_home + "/" + cfg.paths.v3bw_dname + "/" + cfg.paths.v3bw_fname + ".v3bw";
      state_fname = cfg.paths.sbws_home + "/" + cfg.paths.state_fname;
      log_dname = cfg.paths.sbws_home + "/" + cfg.paths.log_dname;
    };
    
    scanner = lib.mapAttrs (_: value: value) cfg.scanner;
    cleanup = lib.mapAttrs (_: value: value) cfg.cleanup;
    relayprioritizer = {
      measure_authorities = if cfg.relayprioritizer.measure_authorities then "on" else "off";
      fraction_relays = cfg.relayprioritizer.fraction_relays;
      min_relays = cfg.relayprioritizer.min_relays;
    };

    logging = {
      to_file = if cfg.logging.to_file then "on" else "off";
      to_stdout = if cfg.logging.to_stdout then "on" else "off";
      to_syslog = if cfg.logging.to_syslog then "on" else "off";
      to_file_max_bytes = cfg.logging.to_file_max_bytes;
      to_file_num_backups = cfg.logging.to_file_num_backups;
      level = cfg.logging.level;
      to_file_level = cfg.logging.to_file_level;
      to_stdout_level = cfg.logging.to_stdout_level;
      to_syslog_level = cfg.logging.to_syslog_level;
      format = cfg.logging.format;
      to_file_format = cfg.logging.to_file_format;
      to_stdout_format = cfg.logging.to_stdout_format;
      to_syslog_format = cfg.logging.to_syslog_format;
    };

    # lib.mapAttrs' for destination headers
    destinations = lib.mapAttrs (_: config: if config.enable then "on" else "off") cfg.destinations //
                   {usability_test_interval = cfg.usability_test_interval;};
  } // (lib.mapAttrs' (name: config: lib.attrsets.nameValuePair ("destinations." + name) (lib.attrsets.filterAttrs (n: v: n != "enable") config)) cfg.destinations)
  ));

  
  log_levels = ["debug" "info" "warning" "error" "critical"];

  # sbws_path = with pkgs; [ sbws ];
in {
  options = {
    services.sbws = {
      enable = lib.mkEnableOption "sbws service";
      # --- General ---
      general = {
        data_period = lib.mkOption {
          description = "Days into the past that measurements are considered valid.";
          default = 5;
          type = lib.types.int;
        };
        http_timeout = lib.mkOption {
          description = "Timeout in seconds to give to the python Requests library.";
          default = 10;
          type = lib.types.int;
        };
        circuit_timeout = lib.mkOption {
          description = "Timeout in seconds to create circuits. ";
          default = 60;
          type = lib.types.int;
        };
        reset_bw_ipv4_changes = lib.mkOption {
          description = "Whether or not to reset the bandwidth measurements when the relay's IP address changes. If it changes, we only consider results for the relay that we obtained while the relay was located at its most recent IP address";
          default = false;
          type = lib.types.bool;
          # default = "off";
          # type = lib.types.attrsOf ["on" "off"];
        };
      };
      # --- Paths ---
      paths = {
        sbws_home = lib.mkOption {
          description = "sbws home directory.";
          example = "/var/lib/sbws";
          default = "/var/lib/sbws";
          type = lib.types.str;
        };

        datadir = lib.mkOption {
          description = "Directory where sbws stores temporal bandwidth results files.";
          example = "datadir";
          default = "datadir";
          type = lib.types.str;
        };

        v3bw_dname = lib.mkOption {
          description = "Directory where sbws stores the bandwidth list files. These are the files to be read by the Tor Directory Authorities.";
          example = "v3bw";
          default = "v3bw";
          type = lib.types.str;
        };

        v3bw_fname = lib.mkOption {
          description = "File names of the bandwidth list files. The latest bandwidth file is symlinked by latest.v3bw";
          example = "v3bw";
          default = "v3bw";
          type = lib.types.str;
        };
        
        state_fname = lib.mkOption {
          description = "File path to store the timestamp when the scanner was last started.";
          example = "state.dat";
          default = "state.dat";
          type = lib.types.str;
        };

        log_dname = lib.mkOption {
          description = "Directory where to store log files when logging to files is enabled.";
          example = "log";
          default = "log";
          type = lib.types.str;
        };
      };

      # --- Destinations ---
      usability_test_interval = lib.mkOption {
        description = "How often to check if a destination is usable.";
        default = 300;
        type = lib.types.int;
      };
      
      destinations = lib.mkOption {
        description = "It is required to set at least one destination for the scanner to run. It is recommended to set several destinations so that the scanner can continue if one fails.";
        
        default = { };
        type = with lib.types; attrsOf
          (submodule {
            options = {
              # name = lib.mkOption {
              #   description = "Name of destination. It is a name for the Web server from where to download files in order to measure bandwidths.";
              #   example = "dest1";
              #   default = "";
              #   type = lib.types.str;
              # };
              enable = lib.mkOption {
                description = "Is the destination active?";
                default = false;
                type = lib.types.bool;
              };

              url = lib.mkOption {
                description = "The URL to the destination. It must include a file path. It can use both http or https.";
                example = "https://releases.nixos.org/nix/nix-1.3/manual.pdf";
                default = "";
                type = lib.types.str;
              };

              verify = lib.mkOption {
                description = "Whether or not to verify the destination certificate.";
                default = true;
                type = lib.types.bool;
              };

              country = lib.mkOption {
                description = "ISO 3166-1 alpha-2 country code. Use ZZ if the destination URL is a domain name and it is in a CDN.";
                example = "FR";
                default = "ZZ";
                type = lib.types.str;
              };
            };
          });
      };

      # --- Scanner ---
      scanner = {
        nickname = lib.mkOption {
          description = "A human-readable string with chars in a-zA-Z0-9 to identify the scanner.";
          example = "IDidntEditTheSBWSConfig";
          default = "IDidntEditTheSBWSConfig";
          type = lib.types.str;
        };

        country = lib.mkOption {
          description = "ISO 3166-1 alpha-2 country code.";
          example = "FR";
          default = "AA";
          type = lib.types.str;
        };

        download_toofast = lib.mkOption {
          description = "Limits on what download times are too fast/slow/etc.";
          default = 1;
          type = lib.types.int;
        };

        download_min = lib.mkOption {
          description = "Limits on what download times are too fast/slow/etc.";
          default = 5;
          type = lib.types.int;
        };

        download_target = lib.mkOption {
          description = "Limits on what download times are too fast/slow/etc.";
          default = 6;
          type = lib.types.int;
        };

        download_max = lib.mkOption {
          description = "Limits on what download times are too fast/slow/etc.";
          default = 10;
          type = lib.types.int;
        };

        num_rtts = lib.mkOption {
          description = "How many RTT measurements to make.";
          default = 0;
          type = lib.types.int;
        };

        num_downloads = lib.mkOption {
          description = "Number of downloads with acceptable times we must have for a relay before moving on.";
          default = 5;
          type = lib.types.int;
        };

        initial_read_request = lib.mkOption {
          description = "The number of bytes to initially request from the server.";
          default = 16384;
          type = lib.types.int;
        };

        measurement_threads = lib.mkOption {
          description = "How many measurements to make in parallel.";
          default = 3;
          type = lib.types.int;
        };

        min_download_size = lib.mkOption {
          description = "Minimum number of bytes we should ever try to download in a measurement.";
          default = 1;
          type = lib.types.int;
        };

        max_download_size = lib.mkOption {
          description = "Maximum number of bytes we should ever try to download in a measurement.";
          default = 1073741824; # 1 GB
          type = lib.types.int;
        };
      };

      # --- Relay priotizer ---
      relayprioritizer = {
        measure_authorities = lib.mkOption {
          description = "Whether or not to measure authorities. ";
          default = true;
          type = lib.types.bool;
        };
        fraction_relays = lib.mkOption {
          description = "The target fraction of best priority relays we would like to return. 0.05 is 5%. In a 7000 relay network, 5% is 350 relays.";
          default = 0.05;
          type = lib.types.float;
        };
        min_relays = lib.mkOption {
          description = "The minimum number of best priority relays we are willing to return.";
          default = 50;
          type = lib.types.int;
        };
      };

      # --- Cleanup ---
      cleanup = {
        data_files_compress_after_days = lib.mkOption {
          description = "After this many days, compress data files.";
          default = 29;
          type = lib.types.int;
        };        
        data_files_delete_after_days = lib.mkOption {
          description = "After this many days, delete data files.";
          default = 57;
          type = lib.types.int;
        };
        v3bw_files_compress_after_days = lib.mkOption {
          description = "After this many days, compress v3bw files.";
          default =1 ;
          type = lib.types.int;
        };
        v3bw_files_delete_after_days = lib.mkOption {
          description = "After this many days, delete v3bw files.";
          default = 7;
          type = lib.types.int;
        };
      };

      # --- Logging ---

      logging = {
        to_file = lib.mkOption {
          description = "Whether or not to log to a rotating file the directory paths.log_dname.";
          default = true;
          type = lib.types.bool;
        };
        to_stdout = lib.mkOption {
          description = "Whether or not to log to stdout.";
          default = true;
          type = lib.types.bool;
        };
        to_syslog = lib.mkOption {
          description = "Whether or not to log to syslog. NOTE that when sbws is launched by systemd, stdout goes to journal and syslog.";
          default = true;
          type = lib.types.bool;
        };
        to_file_max_bytes = lib.mkOption {
          description = "If logging to file, how large (in bytes) should the file be allowed to get before rotating to a new one. 10485760 is 10 MiB. If zero or number of backups is zero, never rotate the log file.";
          default = 10485760;
          type = lib.types.int;
        };
        to_file_num_backups = lib.mkOption {
          description = "If logging to file, how many backups to keep. If zero or max bytes is zero, never rotate the log file.";
          default = 50;
          type = lib.types.int;
        };
        level = lib.mkOption {
          description = "Level to log at. (debug, info, warning, error, critical)";
          example = "debug";
          default = "debug";
          type = lib.types.enum log_levels;
        };
        to_file_level = lib.mkOption {
          description = "Level to log at when using files. (debug, info, warning, error, critical)";
          example = "debug";
          default = "debug";
          type = lib.types.enum log_levels;
        };
        to_stdout_level = lib.mkOption {
          description = "Level to log at when using stdout. (debug, info, warning, error, critical)";
          example = "debug";
          default = "debug";
          type = lib.types.enum log_levels;
        };
        to_syslog_level = lib.mkOption {
          description = "Level to log at when using syslog. (debug, info, warning, error, critical)";
          example = "debug";
          default = "debug";
          type = lib.types.enum log_levels;
        };
        format = lib.mkOption {
          description = "Format string to use when logging.";
          example = "%(asctime)s %(module)s[%(process)s]: <%(levelname)s> %(message)s";
          default = "%(asctime)s %(module)s[%(process)s]: <%(levelname)s> %(message)s"; 
          type = lib.types.str;
        };
        to_stdout_format = lib.mkOption {
          description = "Format string to use when logging to stdout.";
          example = "%(asctime)s %(module)s[%(process)s]: <%(levelname)s> %(message)s";
          default = "%(asctime)s %(module)s[%(process)s]: <%(levelname)s> %(message)s"; 
          type = lib.types.str;
        };
        to_syslog_format = lib.mkOption {
          description = "Format string to use when logging to syslog.";
          example = "%(asctime)s %(module)s[%(process)s]: <%(levelname)s> %(message)s";
          default = "%(asctime)s %(module)s[%(process)s]: <%(levelname)s> %(message)s"; 
          type = lib.types.str;
        };
        to_file_format = lib.mkOption {
          description = "Format string to use when logging to files.";
          example = "%(asctime)s %(module)s[%(process)s]: <%(levelname)s> %(message)s";
          default = "%(asctime)s %(module)s[%(process)s]: <%(levelname)s> %(message)s"; 
          type = lib.types.str;
        };
      };
    };
  };
  
  config = lib.mkIf cfg.enable {
    environment.etc."sbws.ini".source = config_file;
    
    systemd.services.sbws-generator = {
      description = "SBWS - Simple Bandwidth Scanner -- Generator";
      wantedBy = [
        "multi-user.target"
      ];
      # after = [
      # ];
      # inherit environment;
      path = [ pkgs.sbws ];
      serviceConfig = {
        Type = "oneshot";
        # ExecStartPre = ''
        #   sleep 10
        #   chmod g+rx "${cfg.paths.sbws_home}"
        # '';
        ExecBefore = ''
        mkdir -p ${cfg.paths.sbws_home}
        chmod -R 750 ${cfg.paths.sbws_home}
        chown -R sbws:sbws ${cfg.paths.sbws_home}
        '';
        # use environment.src
        ExecStart = ''
        ${pkgs.sbws}/bin/sbws -c /etc/sbws.ini generate
        '';

        WorkingDirectory = pkgs.sbws;
        StateDirectory = "sbws";
        RuntimeDirectory = "sbws";
        User = "sbws";
        Group = "sbws";
      };
    };

    systemd.timers.sbws-generator = {
      wantedBy = [ "timers.target" ];
      partOf = [ "sbws-generator.service" ];
      timerConfig.OnCalendar = [ "*-*-* *:35:0" ];
    };

    systemd.services.sbws-generator-cleanup = {
      description = "SBWS - Simple Bandwidth Scanner -- Generator Cleanup";
      wantedBy = [
        "multi-user.target"
      ];
      path = [ pkgs.sbws ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.sbws}/bin/sbws -c /etc/sbws.ini cleanup"; # use environment.src
        WorkingDirectory = pkgs.sbws;
        StateDirectory = "sbws";
        RuntimeDirectory = "sbws";
        User = "sbws";
        Group = "sbws";
      };
    };

    systemd.timers.sbws-generator-cleanup = {
      wantedBy = [ "timers.target" ];
      partOf = [ "sbws-generator-cleanup.service" ];
      timerConfig.OnCalendar = [ "*-*-* 12:35:00" ];
    };

    users.groups.sbws = {};
    
    users.users.sbws = {
      isSystemUser = true;
      group = "sbws";
      packages = [ pkgs.sbws ];
    };
  };
}
  
