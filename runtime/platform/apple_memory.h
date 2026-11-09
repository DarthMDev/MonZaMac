// Fault-safe reads of our own mapped guest data for shader diagnostics.
#pragma once
#include <TargetConditionals.h>
#include <mach/mach.h>
#if !TARGET_OS_IOS
#include <mach/mach_vm.h>
#endif

static inline bool apple_read_memory(uint64_t addr, size_t size, void *out) {
#if TARGET_OS_IOS
    vm_size_t got = 0;
    return vm_read_overwrite(mach_task_self(), addr, size, (vm_address_t)out, &got) == KERN_SUCCESS && got == size;
#else
    mach_vm_size_t got = 0;
    return mach_vm_read_overwrite(mach_task_self(), addr, size, (mach_vm_address_t)out, &got) == KERN_SUCCESS && got == size;
#endif
}
