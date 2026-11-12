#include <TargetConditionals.h>
#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
#include <SDL3/SDL.h>
#include <cmath>
#include "touch.h"
#include "input_bind.h"
#include "menu.h"

namespace {
enum { LeftStick = BIND_PAD_COUNT, RightStick, Menu };

UIColor *accent(NSInteger slot) {
    if (slot == BIND_A || slot == Menu) return [UIColor colorWithRed:.99 green:.78 blue:.44 alpha:1];
    if (slot == BIND_B) return [UIColor colorWithRed:1 green:.64 blue:.77 alpha:1];
    return [UIColor colorWithRed:.82 green:.76 blue:1 alpha:1];
}
}

@class TouchDeck;

@interface TouchKey : UIView
@property(nonatomic, weak) TouchDeck *deck;
@property(nonatomic) NSInteger slot;
@property(nonatomic, copy) NSString *title;
@property(nonatomic, strong) UITouch *finger;
@property(nonatomic) CGPoint axis;
- (void)reset;
@end

@interface TouchDeck : UIView
@property(nonatomic, strong) NSArray<TouchKey *> *keys;
@property(nonatomic) BOOL preview;
- (void)publish;
- (void)reset;
- (void)openMenu;
@end

@implementation TouchKey
- (void)reset {
    if (!self.finger) return;
    self.finger = nil;
    self.axis = CGPointZero;
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    (void)rect;
    BOOL stick = self.slot == LeftStick || self.slot == RightStick;
    BOOL active = self.finger != nil;
    CGRect face = CGRectInset(self.bounds, 2, 2);
    CGFloat radius = MIN(face.size.width, face.size.height) / 2;
    UIColor *tint = accent(self.slot);
    UIBezierPath *shape = [UIBezierPath bezierPathWithRoundedRect:face cornerRadius:radius];
    UIColor *surface = [UIColor colorWithRed:.10 green:.07 blue:.19 alpha:active ? .90 : .67];
    [surface setFill];
    [shape fill];
    [[tint colorWithAlphaComponent:active ? .95 : .58] setStroke];
    shape.lineWidth = active ? 2 : 1;
    [shape stroke];

    if (stick) {
        UIBezierPath *guide = [UIBezierPath bezierPathWithOvalInRect:CGRectInset(face, 9, 9)];
        [[tint colorWithAlphaComponent:.25] setStroke];
        [guide stroke];
        CGFloat knob = radius * .45;
        CGFloat travel = radius - knob - 6;
        CGPoint center = CGPointMake(CGRectGetMidX(face) + self.axis.x * travel,
                                     CGRectGetMidY(face) - self.axis.y * travel);
        UIBezierPath *cap = [UIBezierPath bezierPathWithOvalInRect:
            CGRectMake(center.x - knob, center.y - knob, 2 * knob, 2 * knob)];
        [[tint colorWithAlphaComponent:active ? .95 : .37] setFill];
        [cap fill];
        return;
    }

    if (active) {
        [[tint colorWithAlphaComponent:.82] setFill];
        [shape fill];
    }
    if (self.slot == Menu) {
        UIImage *gear = [UIImage systemImageNamed:@"gearshape"];
        gear = [gear imageWithTintColor:active ? UIColor.blackColor : tint
                          renderingMode:UIImageRenderingModeAlwaysOriginal];
        [gear drawInRect:CGRectMake(CGRectGetMidX(face) - 10, CGRectGetMidY(face) - 10, 20, 20)];
        return;
    }
    NSDictionary *attributes = @{
        NSFontAttributeName: [UIFont systemFontOfSize:self.slot == BIND_A ? 21 : 16 weight:UIFontWeightSemibold],
        NSForegroundColorAttributeName: active ? UIColor.blackColor : tint,
    };
    CGSize size = [self.title sizeWithAttributes:attributes];
    [self.title drawAtPoint:CGPointMake(CGRectGetMidX(face) - size.width / 2,
                                        CGRectGetMidY(face) - size.height / 2)
             withAttributes:attributes];
}

- (void)updateStick {
    if (self.slot == LeftStick || self.slot == RightStick) {
        CGPoint p = [self.finger locationInView:self];
        CGFloat x = p.x - CGRectGetMidX(self.bounds);
        CGFloat y = CGRectGetMidY(self.bounds) - p.y;
        CGFloat length = hypot(x, y);
        CGFloat travel = CGRectGetWidth(self.bounds) * .34;
        CGFloat strength = fmin(1, fmax(0, (length - 4) / (travel - 4)));
        self.axis = length > 0 ? CGPointMake(x / length * strength, y / length * strength) : CGPointZero;
    }
    [self setNeedsDisplay];
    [self.deck publish];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (self.finger) return;
    self.finger = touches.anyObject;
    [self updateStick];
}
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (self.finger && [touches containsObject:self.finger]) [self updateStick];
}
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (!self.finger || ![touches containsObject:self.finger]) return;
    BOOL activate = self.slot == Menu && [self pointInside:[self.finger locationInView:self] withEvent:event];
    [self reset];
    [self.deck publish];
    if (activate) [self.deck openMenu];
}
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (self.finger && [touches containsObject:self.finger]) {
        [self reset];
        [self.deck publish];
    }
}
@end

@implementation TouchDeck
- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.backgroundColor = UIColor.clearColor;
    self.opaque = NO;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    NSArray<NSString *> *labels = @[@"A", @"B", @"X", @"Y", @"L3", @"R3", @"L", @"R", @"ZL", @"ZR",
                                   @"+", @"−", @"◀", @"▲", @"▶", @"▼", @"", @"", @""];
    NSMutableArray<TouchKey *> *keys = [NSMutableArray array];
    for (NSUInteger i = 0; i < labels.count; i++) {
        TouchKey *key = [[TouchKey alloc] initWithFrame:CGRectZero];
        key.opaque = NO;
        key.backgroundColor = UIColor.clearColor;
        key.contentMode = UIViewContentModeRedraw;
        key.deck = self;
        key.slot = i;
        key.title = labels[i];
        [keys addObject:key];
        [self addSubview:key];
    }
    self.keys = keys;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willResign:)
        name:UIApplicationWillResignActiveNotification object:nil];
    return self;
}
- (void)willResign:(NSNotification *)notification { [self reset]; }

- (void)safeAreaInsetsDidChange {
    [super safeAreaInsetsDidChange];
    [self reset];
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect safe = UIEdgeInsetsInsetRect(self.bounds, self.safeAreaInsets);
    CGFloat left = CGRectGetMinX(safe), right = CGRectGetMaxX(safe);
    CGFloat top = CGRectGetMinY(safe), bottom = CGRectGetMaxY(safe);
    CGFloat scale = fmin(1.22, fmin(safe.size.width / 650, safe.size.height / 340));
    if (scale <= 0) return;
    // Anchor control groups to the safe corners; leave the center clear for the game.
    auto place = [&](NSInteger slot, CGFloat x, CGFloat y, CGFloat w, CGFloat h) {
        self.keys[slot].frame = CGRectMake(x - w * scale / 2, y - h * scale / 2, w * scale, h * scale);
    };
    CGFloat leftCluster = left + 82 * scale, rightCluster = right - 82 * scale;
    CGFloat clusterY = bottom - 161 * scale;
    place(LeftStick, leftCluster, bottom - 50 * scale, 88, 88);
    place(RightStick, rightCluster, bottom - 50 * scale, 88, 88);
    place(BIND_LSTICK, left + 151 * scale, bottom - 27 * scale, 44, 44);
    place(BIND_RSTICK, right - 151 * scale, bottom - 27 * scale, 44, 44);
    CGFloat arm = 39 * scale;
    place(BIND_UP, leftCluster, clusterY - arm, 48, 48);
    place(BIND_DOWN, leftCluster, clusterY + arm, 48, 48);
    place(BIND_LEFT, leftCluster - arm, clusterY, 48, 48);
    place(BIND_RIGHT, leftCluster + arm, clusterY, 48, 48);
    place(BIND_X, rightCluster, clusterY - arm, 48, 48);
    place(BIND_B, rightCluster, clusterY + arm, 48, 48);
    place(BIND_Y, rightCluster - arm, clusterY, 48, 48);
    place(BIND_A, rightCluster + arm, clusterY, 48, 48);
    place(BIND_ZL, left + 48 * scale, top + 31 * scale, 80, 44);
    place(BIND_ZR, right - 48 * scale, top + 31 * scale, 80, 44);
    place(BIND_L, left + 123 * scale, top + 31 * scale, 62, 44);
    place(BIND_R, right - 123 * scale, top + 31 * scale, 62, 44);
    CGFloat center = CGRectGetMidX(safe);
    place(BIND_MINUS, center - 55 * scale, top + 31 * scale, 44, 44);
    place(BIND_PLUS, center + 55 * scale, top + 31 * scale, 44, 44);
    place(Menu, center, top + 31 * scale, 44, 44);
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *target = [super hitTest:point withEvent:event];
    return target == self ? nil : target;
}

- (void)publish {
    uint32_t buttons = 0;
    for (NSInteger i = 0; i < BIND_PAD_COUNT; i++)
        if (self.keys[i].finger) buttons |= 1u << i;
    CGPoint l = self.keys[LeftStick].axis, r = self.keys[RightStick].axis;
    input_touch_state(buttons, lround(l.x * 32767), lround(l.y * 32767),
                               lround(r.x * 32767), lround(r.y * 32767));
}
- (void)reset {
    for (TouchKey *key in self.keys) [key reset];
    [self publish];
}
- (void)openMenu {
    if (self.preview) return;
    SDL_Event event = {};
    event.type = SDL_EVENT_KEY_DOWN;
    event.key.scancode = SDL_SCANCODE_F1;
    SDL_PushEvent(&event);
}
@end

static TouchDeck *deck;

void touch_start(SDL_Window *window) {
    UIWindow *native = (__bridge UIWindow *)SDL_GetPointerProperty(
        SDL_GetWindowProperties(window), SDL_PROP_WINDOW_UIKIT_WINDOW_POINTER, NULL);
    UIView *surface = native.rootViewController.view;
    if (deck || !surface) return;
    deck = [[TouchDeck alloc] initWithFrame:surface.bounds];
    [surface addSubview:deck];
}

void touch_update(bool game_controls) {
    BOOL changed = NO;
    for (TouchKey *key in deck.keys) {
        if (key.slot == Menu || key.hidden == !game_controls) continue;
        [key reset];
        key.hidden = !game_controls;
        changed = YES;
    }
    if (changed) [deck publish];
}

void touch_stop(void) {
    [deck reset];
    [deck removeFromSuperview];
    deck = nil;
}

void touch_preview(SDL_Window *window) {
#if TARGET_OS_SIMULATOR
    touch_start(window);
    deck.preview = YES;
    UIView *surface = deck.superview;
    surface.backgroundColor = [UIColor colorWithRed:.19 green:.14 blue:.29 alpha:1];
    UILabel *label = [[UILabel alloc] initWithFrame:surface.bounds];
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    label.textAlignment = NSTextAlignmentCenter;
    label.textColor = accent(BIND_A);
    label.font = [UIFont systemFontOfSize:24 weight:UIFontWeightSemibold];
    label.text = @"MonZaMac  /  Touch Preview";
    // Cover the Metal layer, which has no frame in the game-free preview.
    label.backgroundColor = surface.backgroundColor;
    [surface insertSubview:label belowSubview:deck];
    SDL_Event event;
    while (!SDL_WaitEventTimeout(&event, 16) || event.type != SDL_EVENT_QUIT) {}
    touch_stop();
#endif
}
#endif
