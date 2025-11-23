#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KERNEL="${REPO_ROOT}/result/bzImage"
INITRD="${REPO_ROOT}/result/initrd"
DISK="${REPO_ROOT}/disk.img"
CMDLINE="console=hvc0 loglevel=8 rdinit=/init panic=-1"

if [[ ! -f "${KERNEL}" || ! -f "${INITRD}" ]]; then
  echo "Kernel or initrd not found in ${REPO_ROOT}/result. Run 'nix build .#bundle-fio' first." >&2
  exit 1
fi

exec nix run nixpkgs#cloud-hypervisor -- \
  --cpus boot=1 \
  --memory size=1024M \
  --kernel "${KERNEL}" \
  --initramfs "${INITRD}" \
  --cmdline "${CMDLINE}" \
  --disk "path=${DISK},num_queues=1,direct=on" \
  --console tty
