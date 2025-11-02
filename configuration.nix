{ config, pkgs, ... }:

{
  # Note: hardware-configuration.nix and networking.hostName are now set in host-specific configs
  
  boot.loader.systemd-boot.enable = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;

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
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  users.users.dillon = {
    isNormalUser = true;
    description = "Dillon";
    shell = pkgs.zsh;
    extraGroups = [ "networkmanager" "wheel" ];
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
hardware.nvidia.open = true;  # see the note above


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
