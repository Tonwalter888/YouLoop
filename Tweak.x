#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>

#import "../YTVideoOverlay/Header.h"
#import "../YTVideoOverlay/Init.x"
#import <YouTubeHeader/YTColor.h>
#import <YouTubeHeader/YTMainAppVideoPlayerOverlayViewController.h>
#import <YouTubeHeader/YTMainAppVideoPlayerOverlayView.h>
#import <YouTubeHeader/YTMainAppControlsOverlayView.h>
#import <YouTubeHeader/YTPlayerViewController.h>
#import <YouTubeHeader/QTMIcon.h>

#define TweakKey @"YouLoop"
#define LOOP_KEY @"defaultLoop_enabled"
#define IS_ENABLED(k) [[NSUserDefaults standardUserDefaults] boolForKey:(k)]

@interface YTMainAppVideoPlayerOverlayViewController (YouLoop)
@property (nonatomic, assign) YTPlayerViewController *parentViewController; // for accessing YTPlayerViewController
@end

@interface YTMainAppVideoPlayerOverlayView (YouLoop)
@property (nonatomic, weak, readwrite) YTMainAppVideoPlayerOverlayViewController *delegate;
@end

@interface YTPlayerViewController (YouLoop)
- (void)didPressYouLoop; // contains actual logic for enabling/disabling loop
@end

@interface YTAutoplayAutonavController : NSObject
- (NSInteger)loopMode; // for reading loop state
- (void)setLoopMode:(NSInteger)loopMode; // for setting loop state
@end

@interface YTMainAppControlsOverlayView (YouLoop)
@property (nonatomic, assign) YTPlayerViewController *playerViewController; // for accessing YTPlayerViewController
- (void)didPressYouLoop:(id)arg; // for custom button press
@end

// For accessing YTPlayerViewController
@interface YTInlinePlayerBarController : NSObject
@end

@interface YTInlinePlayerBarContainerView (YouLoop)
@property (nonatomic, strong) YTInlinePlayerBarController *delegate; // for accessing YTPlayerViewController
- (void)didPressYouLoop:(id)arg; // for custom button press
@end

@interface YTColor (YouLoop)
+ (UIColor *)lightRed; // for tinting the loop button when enabled
@end

// For displaying snackbars - @theRealfoxster
@interface YTHUDMessage : NSObject
+ (id)messageWithText:(id)text;
- (void)setAction:(id)action;
@end
@interface GOOHUDManagerInternal : NSObject
- (void)showMessageMainThread:(id)message;
+ (id)sharedInstance;
@end

// Retrieves the bundle for the tweak
NSBundle *YouLoopBundle() {
    static NSBundle *bundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *tweakBundlePath = [[NSBundle mainBundle] pathForResource:TweakKey ofType:@"bundle"];
        if (tweakBundlePath)
            bundle = [NSBundle bundleWithPath:tweakBundlePath];
        else
            bundle = [NSBundle bundleWithPath:[NSString stringWithFormat:ROOT_PATH_NS(@"/Library/Application Support/%@.bundle"), TweakKey]];
    });
    return bundle;
}
static NSBundle *tweakBundle = nil; // not sure why I need to store tweakBundle

// Get the image for the loop button based on the given state and size
static UIImage *getYouLoopImage(NSString *imageSize) {
    UIColor *tintColor = IS_ENABLED(LOOP_KEY) ? [%c(YTColor) lightRed] : [%c(YTColor) white1];
    NSString *imageName = [NSString stringWithFormat:@"PlayerLoop@%@", imageSize];
    UIImage *base = [UIImage imageNamed:imageName inBundle:YouLoopBundle() compatibleWithTraitCollection:nil];
    if (!base) { base = [UIImage systemImageNamed:@"repeat"]; }
    return [%c(QTMIcon) tintImage:base color:tintColor];
}

%group Main
%hook YTPlayerViewController

%new
- (void)didPressYouLoop {
    id mainAppController = self.activeVideoPlayerOverlay;
    if (![mainAppController isKindOfClass:objc_getClass("YTMainAppVideoPlayerOverlayViewController")]) return;
    YTMainAppVideoPlayerOverlayViewController *playerOverlay = (YTMainAppVideoPlayerOverlayViewController *)mainAppController;
    YTAutoplayAutonavController *autoplayController = nil;
    @try {
        autoplayController = (YTAutoplayAutonavController *)[playerOverlay valueForKey:@"_autonavController"];
    } @catch (__unused NSException *e) {}
    if (!autoplayController) return;
    BOOL newState = !IS_ENABLED(LOOP_KEY);
    [[NSUserDefaults standardUserDefaults] setBool:newState forKey:LOOP_KEY];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [autoplayController setLoopMode:newState ? 2 : 0];
    [[%c(GOOHUDManagerInternal) sharedInstance]
        showMessageMainThread:[%c(YTHUDMessage)
        messageWithText:(newState ? LOC(@"LOOP_ENABLED") : LOC(@"LOOP_DISABLED"))]];
}

// Ensure saved preference is applied when player view appears (first launch / video switch)
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    BOOL shouldLoop = IS_ENABLED(LOOP_KEY);
    if (!shouldLoop) return;
    id mainAppController = self.activeVideoPlayerOverlay;
    if (![mainAppController isKindOfClass:objc_getClass("YTMainAppVideoPlayerOverlayViewController")]) return;
    YTMainAppVideoPlayerOverlayViewController *playerOverlay = (YTMainAppVideoPlayerOverlayViewController *)mainAppController;
    YTAutoplayAutonavController *autoplayController = nil;
    @try {
        autoplayController = (YTAutoplayAutonavController *)[playerOverlay valueForKey:@"_autonavController"];
    } @catch (__unused NSException *e) {}
    if (autoplayController) {
        [autoplayController setLoopMode:2];
    }
}
%end

%hook YTAutoplayAutonavController

- (id)initWithParentResponder:(id)arg1 {
    self = %orig(arg1);
    if (self) {
        BOOL shouldLoop = IS_ENABLED(LOOP_KEY);
        [self setLoopMode:shouldLoop ? 2 : 0];
    }
    return self;
}

static BOOL yl_forcing = NO;
- (void)setLoopMode:(NSInteger)arg1 {
    %orig;
    if (yl_forcing) return;
    BOOL shouldLoop = IS_ENABLED(LOOP_KEY);
    NSInteger target = shouldLoop ? 2 : 0;
    NSInteger current = 0;
    @try { current = [self loopMode]; } @catch (__unused NSException *e) { current = arg1; }
    if (current != target) {
        yl_forcing = YES;
        %orig(target);
        yl_forcing = NO;
    }
}
%end
%end

/**
 * Adds a button to the top area
 */
%group Top
%hook YTMainAppControlsOverlayView

- (UIImage *)buttonImage:(NSString *)tweakId {
    return [tweakId isEqualToString:TweakKey] ? getYouLoopImage(@"3") : %orig;
}

%new(v@:@)
- (void)didPressYouLoop:(id)arg {
    YTMainAppVideoPlayerOverlayView *mainOverlayView = (YTMainAppVideoPlayerOverlayView *)self.superview;
    YTMainAppVideoPlayerOverlayViewController *mainOverlayController = (YTMainAppVideoPlayerOverlayViewController *)mainOverlayView.delegate;
    YTPlayerViewController *playerVC = mainOverlayController.parentViewController;
    if (playerVC) [playerVC didPressYouLoop];
    id btn = self.overlayButtons[TweakKey];
    if ([btn isKindOfClass:[UIButton class]]) {
        [(UIButton *)btn setImage:getYouLoopImage(@"3") forState:UIControlStateNormal];
    }
}
%end
%end

/**
 * Adds a button to the bottom area
 */
%group Bottom
%hook YTInlinePlayerBarContainerView

- (UIImage *)buttonImage:(NSString *)tweakId {
    return [tweakId isEqualToString:TweakKey] ? getYouLoopImage(@"3") : %orig;
}

%new(v@:@)
- (void)didPressYouLoop:(id)arg {
    YTInlinePlayerBarController *delegate = self.delegate;
    YTMainAppVideoPlayerOverlayViewController *_delegate = nil;
    @try { _delegate = [delegate valueForKey:@"_delegate"]; } @catch (__unused NSException *e) {}
    YTPlayerViewController *parentVC = _delegate.parentViewController;
    if (parentVC) [parentVC didPressYouLoop];
    id btn = self.overlayButtons[TweakKey];
    if ([btn isKindOfClass:[UIButton class]]) {
        [(UIButton *)btn setImage:getYouLoopImage(@"3") forState:UIControlStateNormal];
    }
}
%end
%end

%ctor {
    tweakBundle = YouLoopBundle();
    initYTVideoOverlay(TweakKey, @{
        AccessibilityLabelKey: @"Toggle Loop",
        SelectorKey: @"didPressYouLoop:"
    });
    %init(Main);
    %init(Top);
    %init(Bottom);
}
