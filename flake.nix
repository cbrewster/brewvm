{
  inputs = {
    utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, utils }: utils.lib.eachDefaultSystem (system:
    let
      pkgs = nixpkgs.legacyPackages.${system};

      base = pkgs.linuxKernel.kernels.linux_6_17;

      # Minimal kernel with virtio-mmio support
      customKernel = pkgs.linuxKernel.manualConfig {
        version = base.version;
        src = base.src;
        configfile = pkgs.fetchurl {
          url = "https://raw.githubusercontent.com/cloud-hypervisor/linux/refs/heads/ch-6.12.8/arch/x86/configs/ch_defconfig";
          hash = "sha256-0igpcqyxHerIdMnSJiavfZuor+0zPH3u0jQj6glwB+Y=";
        };
      };
    in
    {
      packages = {
        kernel = customKernel;
        default = customKernel;
      };

      devShell = pkgs.mkShell {
        buildInputs = with pkgs; [
          zig
          zls
          nasm
          u-root
          go
        ];
      };
    }
  );
}
