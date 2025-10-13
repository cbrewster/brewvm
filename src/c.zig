pub const c = @cImport({
    @cInclude("linux/kvm.h");
    @cInclude("asm/bootparam.h");
});
