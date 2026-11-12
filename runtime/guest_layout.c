// Where the guest's address space lives (runtime/rt.h): the low window at GUEST_LO and the alias region.
#include <stdlib.h>

#include "platform.h"
#include "rt.h"

#define GIB (1ull << 30)

#if TARGET_OS_IOS
uint64_t g_alias_base = ALIAS_BASE, g_alias_size = ALIAS_SIZE;
#else
uint64_t g_alias_base = GUEST_LOW_END, g_alias_size = 16 * GIB;  // (the alias region right behind the low window, unless it moved)
#endif

// Claim both reservations, before anything else can map there. false: the low window is taken, or no hole below 2^39
// holds the alias region (the caller starts again: the system's own regions move at every launch).
bool guest_reserve(void) {
#if TARGET_OS_IOS
    extern bool g_ios_guest_reserved;
    if (g_ios_guest_reserved) return true;
    g_ios_guest_reserved = plat_reserve_guest(GUEST_LO, GUEST_HI);
    return g_ios_guest_reserved;
#else
    // LARECOMP_IMITATE_MACOS27=1 (development): take the two ~12 GB blocks a macOS 27.0 start had there (measured in a
    // virtual machine) before anything else, so that the alias region has to go to a hole, as there, on any macOS.
    const char *imitate = getenv("LARECOMP_IMITATE_MACOS27");
    if (imitate && atoi(imitate)) {
        static const uint64_t blocks[][2] = {{0x729a000000ull, 0x759ac00000ull}, {0x759b400000ull, 0x789a000000ull}};
        for (int i = 0; i < 2; i++)
            if (!plat_reserve_guest(blocks[i][0], blocks[i][1])) LOG("[mem] imitating macOS 27: block %d not free\n", i);
    }
    if (!plat_reserve_guest(GUEST_LO, GUEST_LOW_END)) return false;
    // The SDK's virtual address memory takes 12 GB of the alias region (and its node area a little more): always the full
    // 16 GB, never a smaller hole. A start that finds none is only a restart away (about 1 in 3 on macOS 27.0, measured).
    for (uint64_t at = GUEST_LOW_END; at + g_alias_size <= GUEST_LIMIT; at += GIB)
        if (plat_reserve_guest(at, at + g_alias_size)) {
            g_alias_base = at;
            LOG("[mem] guest layout: low window %llx-%llx, alias region %llx+%llx%s\n", GUEST_LO, GUEST_LOW_END, at, g_alias_size,
                at == GUEST_LOW_END ? "" : " (in a hole: the address space behind the low window is not free)");
            return true;
        }
    return false;
#endif
}

// Fresh zero pages over both reservations (an in-place reboot).
bool guest_reset(void) {
#if TARGET_OS_IOS
    return plat_zero_guest(GUEST_LO, GUEST_HI - GUEST_LO);
#else
    return plat_reset_guest(GUEST_LO, GUEST_LOW_END) && plat_reset_guest(g_alias_base, g_alias_base + g_alias_size);
#endif
}
