/// Layout of the guest memory space on x86_64.
/// Mostly taken from firecracker: https://github.com/firecracker-microvm/firecracker/blob/main/src/vmm/src/arch/x86_64/layout.rs

// Address for kernel command line
pub const CMDLINE_ADDR: u64 = 0x20000;
pub const CMDLINE_MAX_SIZE: u64 = 2048;

// Address for boot params
pub const BOOT_PARAMS_ADDR: u64 = 0x10000;

pub const KVM_TSS_ADDRESS: u64 = 0xfffb_d000;

/// Location of RSDP pointer in x86 machines
pub const RSDP_ADDR: u64 = 0x000e_0000;

/// Start of memory region we will use for system data (MPTable, ACPI, etc). We are putting its
/// start address where EBDA normally starts, i.e. in the last 1 KiB of the first 640KiB of memory
pub const SYSTEM_MEM_START: u64 = 0x9fc00;

/// Size of memory region for system data.
pub const SYSTEM_MEM_SIZE: u64 = RSDP_ADDR - SYSTEM_MEM_START;

pub const MMIO_LENGTH: u64 = 0x1000;

pub const FIRST_ADDR_PAST_32BITS: u64 = 1 << 32;

pub const HIMEM_START: u64 = 0x0010_0000; // 1 MB.

pub const MMIO32_MEM_START: u64 = FIRST_ADDR_PAST_32BITS - MMIO32_MEM_SIZE;
pub const MMIO32_MEM_SIZE: u64 = 1024 * 1024;

/// Base address for the first virtio-mmio device
/// Each device needs 0x200 (512) bytes for registers
pub const VIRTIO_MMIO_BASE: u64 = MMIO32_MEM_START;
pub const VIRTIO_MMIO_DEVICE_SIZE: u64 = 0x200;
