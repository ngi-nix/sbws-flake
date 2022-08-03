{ config, lib, pkgs, ... }:
let
  cfg = config.services.sbws;
  config_format = pkgs.formats.ini { };
  swbs_config = config_format.generate "swbs-config" ({
    generic = {
      data_period = cfg.sbws.general.data_period;
      http_timeout = cfg.sbws.general.http_timeout;
      circuit_timeout = cfg.sbws.general.circuit_timeout;
      reset_bw_ipv4_changes = cfg.sbws.general.reset_bw_ipv4_changes;
    };
  });
    
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
          default = "off";
          type = types.attrsOf ["on" "off"];
          
        };
      };
      # --- Paths ---
      paths = {
        sbws_home = lib.mkOption {
          description = "sbws home directory.";
          example = "~/.sbws";
          default = "~/.sbws";
          type = lib.types.str;
        };

        datadir = lib.mkOption {
          description = "Directory where sbws stores temporal bandwidth results files.";
          example = "~/.sbws/datadir";
          default = "~/.sbws/datadir";
          type = lib.types.str;
        };

        v3bw_dname = lib.mkOption {
          description = "Directory where sbws stores the bandwidth list files. These are the files to be read by the Tor Directory Authorities.";
          example = "~/.sbws/v3bw";
          default = "~/.sbws/v3bw";
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
          example = "~/.sbws/state.dat";
          default = "~/.sbws/state.dat";
          type = lib.types.str;
        };

        log_dname = lib.mkOption {
          description = "Directory where to store log files when logging to files is enabled.";
          example = "~/.sbws/log";
          default = "~/.sbws/log";
          type = lib.types.str;
        };
      };

      # --- Destinations ---
      destinations = lib.mkOption {
        description = "It is required to set at least one destination for the scanner to run. It is recommended to set several destinations so that the scanner can continue if one fails.";
        default = { };
        type = with types; attrsOf
          (submodule {
            options = {
              # name = lib.mkOption {
              #   description = "Name of destination. It is a name for the Web server from where to download files in order to measure bandwidths.";
              #   example = "dest1";
              #   default = "";
              #   type = lib.types.str;
              # };
              str = lib.mkOption {
                description = "Is the destination active?";
                default = "off";
                type = types.attrsOf ["on" "off"];
              };

              usability_test_interval = lib.mkOption {
                description = "How often to check if a destination is usable.";
                default = 300;
                type = lib.types.int;
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
                description = "ISO 3166-1 alpha-2 country code. Use ZZ if the destination URL is a domain name and it is in a CDN.";                example = "https://releases.nixos.org/nix/nix-1.3/manual.pdf";
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
          default = "off";
          type = types.attrsOf ["on" "off"];
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
        to_file = {
          description = "Whether or not to log to a rotating file the directory paths.log_dname.";
          default = "yes";
          type = types.attrsOf ["yes" "no"];
        };
        to_stdout = {
          description = "Whether or not to log to stdout.";
          default = "yes";
          type = types.attrsOf ["yes" "no"];
        };
        to_syslog = {
          description = "Whether or not to log to syslog. NOTE that when sbws is launched by systemd, stdout goes to journal and syslog.";
          default = "yes";
          type = types.attrsOf ["yes" "no"];
        };
        to_file_max_bytes = {
          description = "If logging to file, how large (in bytes) should the file be allowed to get before rotating to a new one. 10485760 is 10 MiB. If zero or number of backups is zero, never rotate the log file.";
          default = 10485760;
          type = lib.types.int;
        };
        to_file_num_backups = {
          description = "If logging to file, how many backups to keep. If zero or max bytes is zero, never rotate the log file.";
          default = 50;
          type = lib.types.int;
        };
        level = {
          description = "Level to log at. (debug, info, warning, error, critical)";
          example = "debug";
          default = "debug"; 
          type = types.attrsOf ["debug" "info" "warning" "error" "critical"];
        };
        to_file_level = {
          description = "Level to log at when using files. (debug, info, warning, error, critical)";
          example = "debug";
          default = "debug";
          type = types.attrsOf ["debug" "info" "warning" "error" "critical"];
        };
        to_stdout_level = {
          description = "Level to log at when using stdout. (debug, info, warning, error, critical)";
          example = "debug";
          default = "debug";
          type = types.attrsOf ["debug" "info" "warning" "error" "critical"];
        };
        to_syslog_level = {
          description = "Level to log at when using syslog. (debug, info, warning, error, critical)";
          example = "debug";
          default = "debug";
          type = types.attrsOf ["debug" "info" "warning" "error" "critical"];
        };
        format = {
          description = "Format string to use when logging.";
          example = "%(asctime)s %(module)s[%(process)s]: <%(levelname)s> %(message)s";
          default = "%(asctime)s %(module)s[%(process)s]: <%(levelname)s> %(message)s"; 
          type = lib.types.str;
        };
        to_stdout_format = {
          description = "Format string to use when logging to stdout.";
          example = "%(asctime)s %(module)s[%(process)s]: <%(levelname)s> %(message)s";
          default = "%(asctime)s %(module)s[%(process)s]: <%(levelname)s> %(message)s"; 
          type = lib.types.str;
        };
        to_syslog_format = {
          description = "Format string to use when logging to syslog.";
          example = "%(asctime)s %(module)s[%(process)s]: <%(levelname)s> %(message)s";
          default = "%(asctime)s %(module)s[%(process)s]: <%(levelname)s> %(message)s"; 
          type = lib.types.str;
        };
        to_file_format = {
          description = "Format string to use when logging to files.";
          example = "%(asctime)s %(module)s[%(process)s]: <%(levelname)s> %(message)s";
          default = "%(asctime)s %(module)s[%(process)s]: <%(levelname)s> %(message)s"; 
          type = lib.types.str;
        };
      };
    };
  };
}
  
