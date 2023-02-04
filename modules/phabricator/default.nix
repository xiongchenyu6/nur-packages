# based on https://gist.github.com/thoughtpolice/1faff37f0a17e1ab291d
# updated for nixos-16.09

/* Example usage (in configuration.nix):
   services.phabricator = {
   enable = true;
   baseURI      = "https://phabricator.example.org";
   baseFilesURI = config.services.phabricator.baseURI;
   rootDir = "/var/phabricator";
   extensions.sprint = "git://github.com/wikimedia/phabricator-extensions-Sprint.git";
   extraConfig = [
   '' set load-libraries '{"sprint": "${config.services.phabricator.rootDir}/sprint/src"}' ''
   ];
   preamble = ''
   $_SERVER['HTTPS'] = true;
   '';
   };
*/

{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.services.phabricator;

  inherit (pkgs) php;

  mysqlStopwords = pkgs.fetchurl {
    url =
      "https://raw.githubusercontent.com/phacility/phabricator/e616f166ae9ffaf350468e510fb21d16b36060a5/resources/sql/stopwords.txt";
    sha256 = "14bi5dah7nx6bd8h525alqxgs0dxqfaanpyhqys1pssa4bg4pvjk";
  };

in {
  options = {
    services.phabricator = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "If enabled, enable Phabricator with php-fpm.";
      };

      src = mkOption {
        type = types.attrsOf types.str;
        description = "Location of Phabricator source repositories.";
        default = {
          libphutil = "https://github.com/phacility/libphutil.git";
          arcanist = "https://github.com/phacility/arcanist.git";
          phabricator = "https://github.com/phacility/phabricator.git";
        };
      };

      rootDir = mkOption {
        type = types.path;
        default = "/var/phabricator";
      };

      extensions = mkOption {
        type = types.attrsOf types.str;
        description = "List of Phabricator extensions to clone/update";
        default = { };
      };

      baseURI = mkOption {
        type = types.str;
        description =
          "The FQDN of your installation, e.g. <literal>reviews.examplecorp.com</literal>";
      };

      baseFilesURI = mkOption {
        type = types.str;
        description =
          "The FQDN of your file hosting URI that points to the same server (e.g. <literal>phabricator.examplecorpcdncontent.com</literal>)";
      };

      uploadLimit = mkOption {
        type = types.str;
        default = "64M";
        description = ''
          Limit for file size upload chunks, used to set PHP/Nginx
          options. Note that Phabricator itself can store arbitrarily
          large files, as long as the webserver and PHP allow at least
          a 32M minimum upload size. As a result you should almost
          never need to modify this value; your server will
          automatically support arbitrarily large files out of the
          box.
        '';
      };

      extraConfig = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [ "set pygments.enabled  false" ];
      };
      preamble = mkOption {
        type = types.lines;
        default = "";
        example = "$_SERVER['HTTPS'] = true;";
      };

    };
  };

  ## ---------------------------------------------------------------------------
  ## -- Service implementation -------------------------------------------------
  config = mkIf cfg.enable {

    # environment.systemPackages =
    #   [ php phab-admin pkgs.nodejs pkgs.which pkgs.imagemagick
    #   pkgs.jq pkgs.pythonPackages.pygments ];

    systemd.services."phabricator-init" =
      { # wantedBy = [ "multi-user.target" ];
        requires = [ "network.target" "mysql.service" ];
        #before   = [ "nginx.service" ];

        path = [ php pkgs.git ];
        preStart = ''
          chown -R phabricator:phabricator ${cfg.rootDir}
          mkdir -p ${cfg.rootDir}/{data,tmp/phd/log,tmp/phd/pid}
        '';
        script = ''
          cd ${cfg.rootDir}
          export PATH=./phabricator/bin:$PATH
          ${concatStringsSep "\n" (mapAttrsToList (name: val: ''
            (
            if [ ! -d ${name} ]; then
            git clone ${val} ${name}
            fi
            cd ${name}
            git checkout master
            git pull origin master
            )
          '') (cfg.extensions // cfg.src))}
          set -x
          $phabricator config set phd.user                      phabricator
          $phabricator config set storage.local-disk.path       ${cfg.rootDir}/data
          $phabricator config set phd.pid-directory             ${cfg.rootDir}/tmp/phd/log
          $phabricator config set phd.log-directory             ${cfg.rootDir}/tmp/phd/pid
          $phabricator config set metamta.default-address       "noreply@${cfg.baseURI}" # Default From:
          $phabricator config set metamta.domain                "${cfg.baseURI}"         # Domain to send from
          $phabricator config set metamta.reply-handler-domain  "${cfg.baseURI}"         # Reply handler domain
          $phabricator config set metamta.mail-adapter          "PhabricatorMailImplementationMailgunAdapter"
          $phabricator config set mailgun.domain                "${cfg.baseURI}"
          $phabricator config set phabricator.base-uri          "https://${cfg.baseURI}"
          $phabricator config set security.alternate-file-domain "https://${cfg.baseFilesURI}"
          $phabricator config set mysql.port                    3306
          $phabricator config set storage.mysql-engine.max-size 0
          $phabricator config set pygments.enabled              true
          $phabricator config set files.enable-imagemagick      true
          $phabricator config set phabricator.timezone          ${config.time.timeZone}
          $phabricator config set environment.append-paths      '["/run/current-system/sw/bin", "/run/current-system/sw/sbin"]'
          ${concatMapStringsSep "\n" (x: "config ${x}") cfg.extraConfig}
          ln -fs ${
            pkgs.writeText "preamble.php" ''
              <?php
              ${cfg.preamble}
            ''
          } ./phabricator/support/preamble.php
        '';

        serviceConfig.User = "phabricator";
        serviceConfig.Type = "oneshot";
        serviceConfig.RemainAfterExit = true;
      };

    services.phpfpm.phpPackage = php;
    services.phpfpm.phpOptions = ''
      extension=${pkgs.php82Extensions.apcu}/lib/php/extensions/apcu.so
      apc.stat = '0'
      apc.slam_defense = '0'
      upload_max_filesize = ${cfg.uploadLimit}
      post_max_size = ${cfg.uploadLimit}
      always_populate_raw_post_data = -1
      zend_extension=${pkgs.php82Extensions.opcache}/lib/php/extensions/opcache.so
      opcache.validate_timestamps = 0
    '';

    services.phpfpm.pools.phabricator.user = "phabricator";
    services.phpfpm.pools.phabricator.listen = "/run/phpfpm/phabricator.sock";

    services.phpfpm.pools.phabricator.settings = {
      "listen.owner" = "nginx";
      "listen.group" = "nginx";
      pm = "dynamic";
      "pm.max_children" = 75;
      "pm.start_servers" = 10;
      "pm.min_spare_servers" = 5;
      "pm.max_spare_servers" = 20;
      "pm.max_requests" = 500;
    };

    services.mysql.enable = true;
    services.mysql.package = pkgs.mariadb;
    services.mysql.settings.mysqld = {
      sql_mode = "STRICT_ALL_TABLES";
      ft_min_word_len = 3;
      ft_stopword_file = toString mysqlStopwords;
      max_allowed_packet = 40000000;
      innodb_buffer_pool_size = "500M";
    };

    services.nginx.enable = true;
    services.nginx.virtualHosts."_" = {
      root = "${cfg.rootDir}/phabricator/webroot";
      extraConfig = ''
        client_max_body_size ${cfg.uploadLimit};
      '';
      locations."/".extraConfig = ''
        index index.php;
        rewrite ^/(.*)$ /index.php?__path__=/$1 last;
      '';
      locations."/favicon.ico".tryFiles = "$uri =204";
      locations."/index.php".extraConfig = ''
        fastcgi_pass    unix:/run/phpfpm/phabricator.sock;
        fastcgi_index   index.php;
        #required if PHP was built with --enable-force-cgi-redirect
        fastcgi_param  REDIRECT_STATUS    200;
        #variables to make the $_SERVER populate in PHP
        fastcgi_param  SCRIPT_FILENAME    $document_root$fastcgi_script_name;
        fastcgi_param  QUERY_STRING       $query_string;
        fastcgi_param  REQUEST_METHOD     $request_method;
        fastcgi_param  CONTENT_TYPE       $content_type;
        fastcgi_param  CONTENT_LENGTH     $content_length;
        fastcgi_param  SCRIPT_NAME        $fastcgi_script_name;
        fastcgi_param  GATEWAY_INTERFACE  CGI/1.1;
        fastcgi_param  SERVER_SOFTWARE    nginx/$nginx_version;
        fastcgi_param  REMOTE_ADDR        $remote_addr;
      '';
    };

    users.extraUsers.phabricator = {
      description = "Phabricator User";
      home = cfg.rootDir;
      createHome = true;
      group = "phabricator";
      uid = 801;
      useDefaultShell = true;
      isSystemUser = true;
    };

    users.extraGroups.phabricator = { gid = 8001; };
  };
}
