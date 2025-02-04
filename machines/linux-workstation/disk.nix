{
  disko.devices = {
    disk = {
      main = {
        device = "/dev/nvme0n1";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              type = "EF00";
              size = "256M";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            swap = {
              size = "72G";
              content = {
                type = "swap";
                resumeDevice = true;
              };
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "btrfs";
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
  };
}
