{
  inputs = {
    utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, utils }: utils.lib.eachDefaultSystem (system:
    let
      pkgs = nixpkgs.legacyPackages.${system};
      lib = pkgs.lib;

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

      initShell = pkgs.bashInteractive;
      initrdPackages = [
        initShell
        pkgs.fio
        pkgs.coreutils
        pkgs.findutils
        pkgs.gnugrep
        pkgs.gnused
        pkgs.gawk
        pkgs.util-linux
        pkgs.procps
        pkgs.iproute2
        pkgs.iputils
        pkgs.less
        pkgs.e2fsprogs
        pkgs.eudev
      ];
      initrdBinPath = lib.makeBinPath initrdPackages;
      initScript = pkgs.writeScript "brewvm-init" ''
        #!${initShell}/bin/bash
        set -euo pipefail

        export PATH=${initrdBinPath}
        mkdir -p /proc /sys /run /dev /dev/pts
        mount -t proc proc /proc
        mount -t sysfs sysfs /sys
        mount -t tmpfs tmpfs /run
        mount -t devtmpfs devtmpfs /dev || true
        mount -t devpts devpts /dev/pts || true

        echo "brewvm initrd ready - launching bash"
        exec ${initShell}/bin/bash
      '';
      mkInitrdContents = script:
        [
          {
            object = script;
            symlink = "/init";
          }
        ]
        ++ (builtins.map
          (pkg: {
            object = pkg;
            symlink = "/nix/store/.pkg-${lib.strings.sanitizeDerivationName pkg.name}";
          })
          initrdPackages);
      initrd = pkgs.makeInitrd {
        name = "brewvm-initrd";
        contents = mkInitrdContents initScript;
        compressor = pkgs: "${pkgs.coreutils}/bin/cat";
        extension = ".cpio";
      };
      fioInitScript = pkgs.writeScript "brewvm-init-fio" ''
        #!${initShell}/bin/bash
        set -euo pipefail

        export PATH=${initrdBinPath}
        mkdir -p /proc /sys /run /dev /dev/pts
        mount -t proc proc /proc
        mount -t sysfs sysfs /sys
        mount -t tmpfs tmpfs /run
        mount -t devtmpfs devtmpfs /dev || true
        mount -t devpts devpts /dev/pts || true

        device=/dev/vda
        tries=10
        while [ $tries -gt 0 ]; do
          if [ -b "$device" ]; then
            break
          fi
          tries=$((tries - 1))
          echo "Waiting for $device..."
          sleep 1
        done
        if [ ! -b "$device" ]; then
          echo "Device $device not found; rebooting"
          reboot -f || echo b > /proc/sysrq-trigger
        fi

        run_bench() {
          local name=$1
          local mode=$2
          local block_size=$3
          echo "=== Running $name ($mode, bs=$block_size) ==="
          fio \
            --name="$name" \
            --filename="$device" \
            --rw="$mode" \
            --bs="$block_size" \
            --direct=1 \
            --ioengine=libaio \
            --iodepth=32 \
            --numjobs=1 \
            --size=512M \
            --group_reporting
        }

        run_bench "seq-read" read 1M
        run_bench "seq-write" write 1M
        run_bench "rand-read" randread 4k
        run_bench "rand-write" randwrite 4k

        sync
        echo "fio benchmarks complete, powering off"
        reboot -f || echo b > /proc/sysrq-trigger
        sleep 5
      '';
      initrdFio = pkgs.makeInitrd {
        name = "brewvm-initrd-fio";
        contents = mkInitrdContents fioInitScript;
        compressor = pkgs: "${pkgs.coreutils}/bin/cat";
        extension = ".cpio";
      };
      bundle = pkgs.symlinkJoin {
        name = "brewvm-bundle";
        paths = [
          customKernel
          initrd
        ];
      };
      bundleFio = pkgs.symlinkJoin {
        name = "brewvm-bundle-fio";
        paths = [
          customKernel
          initrdFio
        ];
      };
    in
    {
      packages = {
        kernel = customKernel;
        initrd = initrd;
        "initrd-fio" = initrdFio;
        bundle = bundle;
        "bundle-fio" = bundleFio;
        default = bundle;
      };

      devShell = pkgs.mkShell {
        buildInputs = with pkgs; [
          zig
          zls
          nasm
          u-root
          go
          perf
          perf-tools
          flamegraph
        ];
      };
    }
  );
}
