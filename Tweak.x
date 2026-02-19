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
#import <YouTubeHeader/GOOHUDManagerInternal.h>
#import <YouTubeHeader/YTInlinePlayerBarContainerView.h>

#define TweakKey @"YouLoop"
#define LOOP_KEY @"YouLoopKey"
#define IS_ENABLED(k) [[NSUserDefaults standardUserDefaults] boolForKey:(k)]

@interface YTMainAppVideoPlayerOverlayViewController (YouLoop)
@property (nonatomic, assign) YTPlayerViewController *parentViewController;
@end

@interface YTMainAppVideoPlayerOverlayView (YouLoop)
@property (nonatomic, weak, readwrite) YTMainAppVideoPlayerOverlayViewController *delegate;
@end

@interface YTPlayerViewController (YouLoop)
- (void)didPressYouLoop;
@end

@interface YTAutoplayAutonavController : NSObject
- (NSInteger)loopMode;
- (void)setLoopMode:(NSInteger)loopMode;
@end

@interface YTMainAppControlsOverlayView (YouLoop)
- (void)didPressYouLoop:(id)arg;
@end

@interface YTInlinePlayerBarController : NSObject
@end

@interface YTInlinePlayerBarContainerView (YouLoop)
- (void)didPressYouLoop:(id)arg;
@end

@interface YTColor (YouLoop)
+ (UIColor *)lightRed;
@end

NSBundle *YouLoopBundle() {
    static NSBundle *bundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *tweakBundlePath = [[NSBundle mainBundle] pathForResource:TweakKey ofType:@"bundle"];
        if (tweakBundlePath)
            bundle = [NSBundle bundleWithPath:tweakBundlePath];
        else
            bundle = [NSBundle bundleWithPath:[NSString stringWithFormat:PS_ROOT_PATH_NS(@"/Library/Application Support/%@.bundle"), TweakKey]];
    });
    return bundle;
}

static NSBundle *tweakBundle = nil;

static UIImage *YouLoopIcon(NSString *imageSize) {
    UIColor *tintColor = IS_ENABLED(LOOP_KEY) ? [%c(YTColor) lightRed] : [%c(YTColor) white1];
    NSString *imageName = [NSString stringWithFormat:@"Loop@%@", imageSize];
    UIImage *base = [UIImage imageNamed:imageName inBundle:YouLoopBundle() compatibleWithTraitCollection:nil];
    return [%c(QTMIcon) tintImage:base color:tintColor];
}

BOOL LoopStatus = !IS_ENABLED(LOOP_KEY);
BOOL shouldLoop = IS_ENABLED(LOOP_KEY);
BOOL ForceLoop = NO;

%group Main
%hook YTPlayerViewController
%new
- (void)didPressYouLoop {
    id mainAppController = self.activeVideoPlayerOverlay;
    YTMainAppVideoPlayerOverlayViewController *playerOverlay = (YTMainAppVideoPlayerOverlayViewController *)mainAppController;
    YTAutoplayAutonavController *autoplayController = (YTAutoplayAutonavController *)[playerOverlay valueForKey:@"_autonavController"];
    [[NSUserDefaults standardUserDefaults] setBool:LoopStatus forKey:LOOP_KEY];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [autoplayController setLoopMode:LoopStatus ? 2 : 0];
    [[%c(GOOHUDManagerInternal) sharedInstance]
        showMessageMainThread:[%c(YTHUDMessage)
        messageWithText:(LoopStatus ? LOC(@"LOOP_ENABLED") : LOC(@"LOOP_DISABLED"))]];
}

// Ensure saved preference is applied when player view appears (first launch / video switch)
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (!shouldLoop) return;
    id mainAppController = self.activeVideoPlayerOverlay;
    YTMainAppVideoPlayerOverlayViewController *playerOverlay = (YTMainAppVideoPlayerOverlayViewController *)mainAppController;
    YTAutoplayAutonavController *autoplayController = (YTAutoplayAutonavController *)[playerOverlay valueForKey:@"_autonavController"];
    if (autoplayController) {
        [autoplayController setLoopMode:2];
    }
}
%end

%hook YTAutoplayAutonavController

- (id)initWithParentResponder:(id)arg1 {
    self = %orig(arg1);
    if (self) {
        [self setLoopMode:shouldLoop ? 2 : 0];
    }
    return self;
}

- (void)setLoopMode:(NSInteger)arg1 {
    %orig;
    if (ForceLoop) return;
    NSInteger target = shouldLoop ? 2 : 0;
    NSInteger current = [self loopMode];
    if (current != target) {
        ForceLoop = YES;
        %orig(target);
        ForceLoop = NO;
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
    return [tweakId isEqualToString:TweakKey] ? YouLoopIcon(@"3") : %orig;
}

%new(v@:@)
- (void)didPressYouLoop:(id)arg {
    YTMainAppVideoPlayerOverlayView *mainOverlayView = (YTMainAppVideoPlayerOverlayView *)self.superview;
    YTMainAppVideoPlayerOverlayViewController *mainOverlayController = (YTMainAppVideoPlayerOverlayViewController *)mainOverlayView.delegate;
    YTPlayerViewController *pvc = mainOverlayController.parentViewController;
    if (pvc) [pvc didPressYouLoop];
    UIButton *btn = self.overlayButtons[TweakKey];
    if ([btn isKindOfClass:[UIButton class]]) {
        btn.tintColor = shouldLoop ? [YTColor lightRed] : [YTColor white1];
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
    return [tweakId isEqualToString:TweakKey] ? YouLoopIcon(@"3") : %orig;
}

%new(v@:@)
- (void)didPressYouLoop:(id)arg {
    YTInlinePlayerBarController *delegate = self.delegate;
    YTMainAppVideoPlayerOverlayViewController *_delegate = [delegate valueForKey:@"_delegate"];
    YTPlayerViewController *pvc = _delegate.parentViewController;
    if (pvc) [pvc didPressYouLoop];
    UIButton *btn = self.overlayButtons[TweakKey];
    if ([btn isKindOfClass:[UIButton class]]) {
        btn.tintColor = shouldLoop ? [YTColor lightRed] : [YTColor white1];
    }
}

%end
%end

%ctor {
    tweakBundle = YouLoopBundle();
    initYTVideoOverlay(TweakKey, @{
        AccessibilityLabelKey: @"YouLoop",
        SelectorKey: @"didPressYouLoop:"
    });
    %init(Main);
    %init(Top);
    %init(Bottom);
}
