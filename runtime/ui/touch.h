#pragma once
#include <stdbool.h>
#include <stdint.h>

typedef struct SDL_Window SDL_Window;

#ifdef __cplusplus
extern "C" {
#endif

// UIKit overlay, called from the SDL UI thread.
void touch_start(SDL_Window *window);
void touch_update(bool game_controls);
void touch_stop(void);
void touch_preview(SDL_Window *window);

// Switch button bits and signed stick axes, published by UIKit.
void input_touch_state(uint32_t buttons, int32_t lx, int32_t ly, int32_t rx, int32_t ry);

#ifdef __cplusplus
}
#endif
