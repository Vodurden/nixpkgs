{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.thermald;

  # Prefixes every line in a string with the given prefix.
  prefixLinesWith = prefix: s:
    prefix + (builtins.replaceStrings ["\n"] ["\n${prefix}"] s);

  indent = s: prefixLinesWith "  " s;

  boolToInt = b: if b then 1 else 0;

  mapXmlElement = f: cfg: attr:
    let value = attrByPath [attr] null cfg;
    in optionalString (value != null) "<${attr}>${f value}</${attr}>";

  xmlBlock = name: children:
    if children == []
    then ""
    else "<${name}>\n" + indent (builtins.concatStringsSep "\n" children) + "\n</${name}>";

  xmlElement = cfg: attr: mapXmlElement (x: x) cfg attr;

  platformConfig = with types; submodule {
    options = {
      Name = mkOption {
        type = str;
        description = "The name of this platform, can be any arbitrary string.";
        example = "Passive CPU cooling";
      };

      UUID = mkOption {
        type = nullOr string;
        default = null;
        description = ''
          UUID is optional, if present this will be matched. Both product name and UUID
          can contain wild card "*", which matches any platform.
        '';
      };

      ProductName = mkOption {
        type = str;
        description = "The product name of this platform. Can be a * to indicate all products.";
        example = "*";
      };

      Preference = mkOption {
        type = enum ["quiet" "performance"];
        description = ''
          Quiet mode will only use passive cooling device. Performance will only select
          active devices.
        '';
      };

      ThermalSensors = mkOption {
        type = listOf thermalSensorConfig;
        default = [];
        description = ''
          The thermal sensors available on this platform.

          A thermal sensor is an interface to read the temperature of a thermal zone.
        '';
      };

      ThermalZones = mkOption {
        type = listOf thermalZoneConfig;
        description = ''
          The thermal zones available on this platform.

          A thermal zone is a conceptual model that defines a physical space that contains devices,
          thermal sensors and cooling controls.

          For example: a thermal zone can be a CPU or a laptop cover. A zone can contain multiple
          sensors for monitoring temperature and a cooling device provides the interface to reduce
          the temperature of a thermal zone.
        '';
      };

      CoolingDevices = mkOption {
        type = listOf coolingDeviceConfig;
        default = [];
        description = ''
          The cooling devices available on this platform.

          A cooling device is an interface to reduce the temperature of one or more thermal zones.

          An example cooling device is a fan or some linux driver that can throttle the source
          device.
        '';
      };
    };
  };

  thermalSensorConfig = with types; submodule {
    options = {
      Type = mkOption {
        type = str;
        description = ''
          The type of this sensor.

          This can be any name and is used by <literal>ThermalZones.TripPoints.SensorType</literal>
          to reference this sensor.
        '';
        example = "CPU_TEMP";
      };

      Path = mkOption {
        type = nullOr path;
        default = null;
        description = "The path to this sensor.";
        example = "/sys/class/hwmon/hwmon0/temp1_input";
      };

      AsyncCapable = mkOption {
        type = nullOr bool;
        default = null;
        description = "If true then we don't need to poll.";
      };
    };
  };

  thermalZoneConfig = with types; submodule {
    options = {
      Type = mkOption {
        type = str;
        description = ''
          The thermal zone we are configuring.

          To modify an existing thermal zone then this should match a thermal zone type
          available on your machine. Otherwise, this will define a new thermal zone.

          To list available thermal zone types run <literal>cat /sys/class/thermal/thermal_zone*/type</literal>.
        '';
        example = "x86_pkg_temp";
      };

      Path = mkOption {
        type = nullOr path;
        default = null;
        description = "The path to this thermal zone device.";
        example = "/sys/class/thermal/thermal_zone0";
      };

      AsyncCapable = mkOption {
        type = nullOr bool;
        default = null;
        description = "If true then we don't need to poll.";
      };

      TripPoints = mkOption {
        type = listOf tripPointConfig;
        description = ''
          A trip point defines a temperature limit for a thermal zone and establishes what
          cooling devices should be engaged to keep the thermal zone under that temperature.
        '';
      };
    };
  };


  tripPointConfig = with types; submodule {
    options = {
      SensorType = mkOption {
        type = str;
        description = ''
          The sensor type.

          This should match either: A sensor type defined in ThermalSensors or a thermal zone
          type containing the sensor you want to use.

          To list available thermal zone types run <literal>cat /sys/class/thermal/thermal_zone*/type</literal>.
        '';
        example = "x86_pkg_temp";
      };

      Temperature = mkOption {
        type = int;
        description = ''
          Temperature in millidegree celcius at which to take action.

          When the thermal zone exceeds this temperature the cooling devices will be activated.
        '';
        example = "70000";
      };

      Type = mkOption {
        type = enum [ "max" "passive" "active" ];
        description = ''
          If a max type is specified, then daemon will use PID control to
          aggressively throttle to avoid reaching this temp.

          If passive is specified then only passive cooling devices will be used.

          If active is specified then only active cooling devices will be used.
        '';
      };

      ControlType = mkOption {
        type = nullOr (enum [ "sequential" "parallel" ]);
        default = null;
        description = ''
          When a trip point temperature is violated a number of cooling device can be activated.

          If the control type is sequential then it will exhaust the first cooling device before
          trying the next.
        '';
      };

      CoolingDevices = mkOption {
        type = listOf tripPointCoolingDeviceConfig;
        default = [];
        description = ''
          The cooling devices to use for this trip point.
        '';
      };
    };
  };

  tripPointCoolingDeviceConfig = with types; submodule {
    options = {
      Index = mkOption {
        type = nullOr int;
        default = null;
        description = "The index of this cooling device.";
      };

      Type = mkOption {
        type = str;
        description = ''
          The type of cooling device.

          This needs to be either a cooling device built in to thermald, present in the thermal
          sysfs or a defined in the cooling device section of this configuration.

          The cooling devices built in to thermald are: <literal>rapl_controller</literal>,
          <literal>intel_pstate</literal>, <literal>cpufreq</literal> and <literal>LCD</literal>.

          To list the cooling devices available in the thermal sysfs run:
          <literal>cat /sys/class/thermal/cooling_device*/type</literal>.
        '';
      };

      Influence = mkOption {
        type = nullOr int;
        default = null;
        description = ''
          The influence of this cooling device. This affects the order in which cooling
          devices are applied with higher influence devices being applied first. The relative
          magnitude of each device also contributes to how aggressively each device is applied.
        '';
      };

      SamplingPeriod = mkOption {
        type = nullOr int;
        default = null;
        description = ''
          Delay in seconds when using this cooling device, this takes some time to actually
          cool a zone.
        '';
      };

      TargetState = mkOption {
        type = nullOr int;
        default = null;
        description = ''
          Set a specific state of this cooling device when this trip is violated.
        '';
      };
    };
  };

  coolingDeviceConfig = with types; submodule {
    options = {
      Type = mkOption {
        type = str;
        description = "The type of this cooling device.";
      };

      MinState = mkOption {
        type = nullOr int;
        default = null;
        description = "The min state of this cooling device.";
      };

      IncDecStep = mkOption {
        type = nullOr int;
        default = null;
        description = "The IncDecStep.";
      };

      ReadBack = mkOption {
        type = nullOr int;
        default = null;
        description = "The ReadBack.";
      };

      MaxState = mkOption {
        type = nullOr int;
        default = null;
        description = "The MaxState.";
      };

      DebouncePeriod = mkOption {
        type = nullOr int;
        default = null;
        description = "The DebouncePeriod.";
      };

      PidControl = mkOption {
        description = ''
          If there are no PID parameters, compensation increase step wise and exponentially (if
          single step is not able to change trend). Alternatively a PID parameters can be
          specified then next step  will use PID calculation using provided PID constants.
        '';
        default = {};
        type = submodule {
          options = {
            kp = mkOption {
              type = str;
              description = "kp";
            };

            kd = mkOption {
              type = str;
              description = "kd";
            };

            ki = mkOption {
              type = str;
              description = "ki";
            };
          };
        };
      };

      WritePrefix = mkOption {
        type = nullOr string;
        default = null;
        description = ''
          If set this prefix will be attached to the state value. For example: if the prefix
          is "level " it will preserve the spaces and prefix the state when writing to the
          sysfs.
        '';
      };
    };
  };

  makeThermalConfigurationXml = configFile:
    "<?xml version=\"1.0\"?>\n" +
    xmlBlock "ThermalConfiguration" (map makePlatformXml configFile.platforms);

  makePlatformXml = pCfg: xmlBlock "Platform" [
    (xmlElement pCfg "Name")
    (xmlElement pCfg "UUID")
    (xmlElement pCfg "ProductName")
    (xmlElement pCfg "Preference")
    (xmlBlock "ThermalSensors" (map makeThermalSensorXml pCfg.ThermalSensors))
    (xmlBlock "ThermalZones" (map makeThermalZoneXml pCfg.ThermalZones))
    (xmlBlock "CoolingDevices" (map makeCoolingDeviceXml pCfg.CoolingDevices))
  ];

  makeThermalSensorXml = tsCfg: xmlBlock "ThermalSensor" [
    (xmlElement tzCfg "Type")
    (xmlElement tzCfg "Path")
    (mapXmlElement boolToInt tzCfg "AsyncCapable")
  ];

  makeThermalZoneXml = tzCfg: xmlBlock "ThermalZone" [
    (xmlElement tzCfg "Type")
    (xmlElement tzCfg "Path")
    (mapXmlElement boolToInt tzCfg "AsyncCapable")
    (xmlBlock "TripPoints" (map makeTripPointXml tzCfg.TripPoints))
  ];

  makeTripPointXml = tpCfg: xmlBlock "TripPoint" ([
    (xmlElement tpCfg "SensorType")
    (mapXmlElement toString tpCfg "Temperature")
    (xmlElement tpCfg "Type")
    (xmlElement tpCfg "ControlType")
  ] ++ (map makeTripPointCoolingDeviceXml tpCfg.CoolingDevices));

  makeTripPointCoolingDeviceXml = tpcdCfg: xmlBlock "CoolingDevice" [
    (mapXmlElement toString tpcdCfg "Index")
    (xmlElement tpcdCfg "Type")
    (mapXmlElement toString tpcdCfg "Influence")
    (mapXmlElement toString tpcdCfg "SamplingPeriod")
    (mapXmlElement toString tpcdCfg "TargetState")
  ];

  makeCoolingDeviceXml = cdCfg: xmlBlock "CoolingDevice" [
    (xmlElement cdCfg "Type")
    (mapXmlElement toString cdCfg "MinState")
    (mapXmlElement toString cdCfg "IncDecStep")
    (mapXmlElement toString cdCfg "ReadBack")
    (mapXmlElement toString cdCfg "MaxState")
    (mapXmlElement toString cdCfg "DebouncePeriod")
    (xmlBlock "PidControl" [
      (xmlElement cdCfg.PidControl "kp")
      (xmlElement cdCfg.PidControl "kd")
      (xmlElement cdCfg.PidControl "ki")
    ])
    (xmlElement cdCfg "WritePrefix")
  ];
in {
  ###### interface
  options = {
    services.thermald = {
      enable = mkOption {
        default = false;
        description = ''
          Whether to enable thermald, the temperature management daemon.
        '';
      };

      debug = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether to enable debug logging.
        '';
      };

      config = mkOption {
        type = types.nullOr (types.submodule {
          options = {
            platforms = mkOption {
              default = [];
              type = types.listOf platformConfig;
              description = "thermald platforms.";
            };
          };
        });
        default = null;
        description = "the thermald manual configuration file.";
      };

      configFile = mkOption {
        type = types.nullOr types.path;
        default = optionalString (cfg.config != null) (builtins.toFile "thermal-conf.xml" (makeThermalConfigurationXml cfg.config));
        description = "the thermald manual configuration file.";
      };
    };
  };

  ###### implementation
  config = mkIf cfg.enable {
    services.dbus.packages = [ pkgs.thermald ];

    environment.etc."thermald/thermal-conf.xml".text =
      mkIf (cfg.configFile != null) cfg.configFile;

    systemd.services.thermald = {
      description = "Thermal Daemon Service";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = ''
          ${pkgs.thermald}/sbin/thermald \
            --no-daemon \
            ${optionalString cfg.debug "--loglevel=debug"} \
            ${optionalString (cfg.configFile != null) "--config-file ${cfg.configFile}"} \
            --dbus-enable
        '';
      };
    };
  };
}
