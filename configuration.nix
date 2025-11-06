{ config, pkgs, ... }:

{
  # Note: hardware-configuration.nix and networking.hostName are now set in host-specific configs

  boot.loader.systemd-boot.enable = true;
  boot.initrd.kernelModules = [ "nvidia_drm" ];

  boot.kernelPackages = pkgs.linuxPackages_latest;
  
  # Performance-oriented kernel parameters for gaming
  boot.kernelParams = [
    # Disable CPU mitigations for better performance (security tradeoff)
    "mitigations=off"
    # Disable watchdog for slight performance improvement
    "nowatchdog"
    # Set preemption model for better gaming performance
    "preempt=full"
  ];

  networking.networkmanager.enable = true;

  time.timeZone = "America/Chicago";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;
  services.tailscale.enable = true;

    networking.firewall.allowedTCPPorts = [19999];

  services.netdata = {
    enable = true;
    config = {
      global = {
        "memory mode" = "ram";
        "debug log" = "none";
        "access log" = "none";
        "error log" = "syslog";
      };
    };
  };

  services.netdata.package = pkgs.netdata.override {
  withCloudUi = true;
};

systemd.services.netdata.path = [pkgs.linuxPackages.nvidia_x11];
services.netdata.configDir."python.d.conf" = pkgs.writeText "python.d.conf" ''
  nvidia_smi: yes
'';

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  services.udev.packages = [
    (pkgs.writeTextFile {
      name = "gcadapter-udev-rules";
      destination = "/etc/udev/rules.d/51-gcadapter.rules";
      text = ''
        SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTRS{idVendor}=="057e", ATTRS{idProduct}=="0337", MODE="0666"
      '';
    })
    (pkgs.writeTextFile {
      name = "losslessadapter-udev-rules";
      destination = "/etc/udev/rules.d/51-losslessadapter.rules";
      text = ''
        SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTRS{idVendor}=="2e8a", ATTRS{idProduct}=="102b", MODE="0666"
      '';
    })
  ];

  services.printing.enable = true;

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  security.polkit.enable = true;
  services.pipewire = {
    enable = true;
    wireplumber.enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # CPU governor for performance
  powerManagement.cpuFreqGovernor = "performance";

  # System-level performance tuning
  boot.kernel.sysctl = {
    # Reduce swappiness for better gaming performance
    "vm.swappiness" = 10;
    # Increase file handles for better performance
    "fs.file-max" = 524288;
    # Network optimizations
    "net.core.rmem_max" = 134217728;
    "net.core.wmem_max" = 134217728;
  };

  users.users.dillon = {
    isNormalUser = true;
    description = "Dillon";
    shell = pkgs.zsh;
    extraGroups = [ "networkmanager" "wheel" "video" "audio" ];
    packages = with pkgs; [
      kdePackages.kate
    ];
  };

  home-manager.backupFileExtension = "bak";

  programs.firefox.enable = true;
  programs.niri.enable = true;
  programs.zsh.enable = true;
  programs.steam.enable = true;
  programs.steam.extraCompatPackages = [ pkgs.proton-ge-bin];
  programs.fuse.userAllowOther = true;
  programs.gamescope.enable = false;
  
  # Enable GameMode for better gaming performance
  programs.gamemode = {
    enable = true;
    settings = {
      general = {
        renice = 10;
      };
      gpu = {
        apply_gpu_optimisations = "accept-responsibility";
        gpu_device = 0;
        amd_performance_level = "high";
      };
      custom = {
        start = "${pkgs.libnotify}/bin/notify-send 'GameMode started'";
        end = "${pkgs.libnotify}/bin/notify-send 'GameMode ended'";
      };
    };
  };

  # Enable XDG desktop portals for gamescope and other applications
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = "*";
  };

  # Sets up service for periodic garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  hardware.bluetooth = {
  enable = true;
  powerOnBoot = true;
  settings = {
    General = {
      # Shows battery charge of connected devices on supported
      # Bluetooth adapters. Defaults to 'false'.
      Experimental = true;
      # When enabled other devices can connect faster to us, however
      # the tradeoff is increased power consumption. Defaults to
      # 'false'.
      FastConnectable = true;
    };
    Policy = {
      # Enable all controllers when they are found. This includes
      # adapters present on start as well as adapters that are plugged
      # in later on. Defaults to 'true'.
      AutoEnable = true;
    };
  };
};

hardware.graphics.enable = true;
services.xserver.videoDrivers = [ "nvidia" ];
hardware.nvidia.open = true;
hardware.nvidia.modesetting.enable = true;
# Enable power management for better performance consistency
hardware.nvidia.powerManagement.enable = true;
# Disable experimental fine-grained power management
hardware.nvidia.powerManagement.finegrained = false;
# Force maximum performance mode
hardware.nvidia.forceFullCompositionPipeline = false;

hardware.graphics.extraPackages = [ pkgs.libvdpau-va-gl ]; #NVIDIA doesn't support libvdpau, so this package will redirect VDPAU calls to LIBVA.

environment.variables = {
  VDPAU_DRIVER = "va_gl";
  LIBVA_DRIVER_NAME = "nvidia";
  # NVIDIA performance optimizations
  __GL_THREADED_OPTIMIZATION = "1";
  __GL_SHADER_DISK_CACHE = "1";
  __GL_SHADER_DISK_CACHE_SKIP_CLEANUP = "1";
  # Force GPU to maximum performance
  __GL_SYNC_TO_VBLANK = "0";
};



  environment.systemPackages = with pkgs; [
    git
    zed-editor
    code-cursor-fhs
    zsh
    wezterm
    discord
    libdisplay-info
  ];

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
  ];

  system.stateVersion = "25.05";
}
