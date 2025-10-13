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
        configfile = ./miniconfig;
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
        ];
      };
    }
  );
}
