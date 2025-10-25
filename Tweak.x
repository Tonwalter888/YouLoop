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
#define IS_ENABLED(k) [[NSUserDefaults standardUserDefaults] boolForKey:k]

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
    UIColor *tintColor = IS_ENABLED(@"defaultLoop_enabled") ? [%c(YTColor) lightRed] : [%c(YTColor) white1];
    NSString *imageName = [NSString stringWithFormat:@"PlayerLoop@%@", imageSize];
    return [%c(QTMIcon) tintImage:[UIImage imageNamed:imageName inBundle:YouLoopBundle() compatibleWithTraitCollection:nil] color:tintColor];
}

%hook YTPlayerViewController
%new
- (void)didPressYouLoop {
    id mainAppController = self.activeVideoPlayerOverlay;
    if ([mainAppController isKindOfClass:objc_getClass("YTMainAppVideoPlayerOverlayViewController")]) {
        YTMainAppVideoPlayerOverlayViewController *playerOverlay = (YTMainAppVideoPlayerOverlayViewController *)mainAppController;
        YTAutoplayAutonavController *autoplayController = (YTAutoplayAutonavController *)[playerOverlay valueForKey:@"_autonavController"];
        BOOL isCurrentlyLooping = ([autoplayController loopMode] == 2);
        BOOL newState = !isCurrentlyLooping;
        [autoplayController setLoopMode:newState ? 2 : 0];
        [[NSUserDefaults standardUserDefaults] setBool:newState forKey:@"defaultLoop_enabled"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [[%c(GOOHUDManagerInternal) sharedInstance]
            showMessageMainThread:[%c(YTHUDMessage)
            messageWithText:(newState ? LOC(@"LOOP_ENABLED") : LOC(@"LOOP_DISABLED"))]];
    }
}
%end

%hook YTAutoplayAutonavController
- (id)initWithParentResponder:(id)arg1 {
    self = %orig(arg1);
    if (self) {
        BOOL shouldLoop = IS_ENABLED(@"defaultLoop_enabled");
        if (shouldLoop) {
            [self setLoopMode:2];
        }
    }
    return self;
}

- (void)setLoopMode:(NSInteger)arg1 {
    %orig;
    BOOL shouldLoop = IS_ENABLED(@"defaultLoop_enabled");
    if (shouldLoop && arg1 != 2) {
        %orig(2);
    }
}
%end

/**
  * Adds a button to the top area in the video player overlay
  */
%group Top
%hook YTMainAppControlsOverlayView

- (UIImage *)buttonImage:(NSString *)tweakId {
    return [tweakId isEqualToString:TweakKey] ? getYouLoopImage(@"3") : %orig;
}

// Custom method to handle the button press
%new(v@:@)
- (void)didPressYouLoop:(id)arg {
    // Call our custom method in the YTPlayerViewController class
    YTMainAppVideoPlayerOverlayView *mainOverlayView = (YTMainAppVideoPlayerOverlayView *)self.superview;
    YTMainAppVideoPlayerOverlayViewController *mainOverlayController = (YTMainAppVideoPlayerOverlayViewController *)mainOverlayView.delegate;
    YTPlayerViewController *playerViewController = mainOverlayController.parentViewController;
    if (playerViewController) {
        [playerViewController didPressYouLoop];
    }
    // Update button color
    [self.overlayButtons[TweakKey] setImage:getYouLoopImage(@"3") forState:0];
}

%end
%end

/**
  * Adds a button to the bottom area next to the fullscreen button
  */
%group Bottom
%hook YTInlinePlayerBarContainerView

- (UIImage *)buttonImage:(NSString *)tweakId {
    return [tweakId isEqualToString:TweakKey] ? getYouLoopImage(@"3") : %orig;
}

// Custom method to handle the button press
%new(v@:@)
- (void)didPressYouLoop:(id)arg {
    // Navigate to the YTPlayerViewController class from here
    YTInlinePlayerBarController *delegate = self.delegate; // for @property
    YTMainAppVideoPlayerOverlayViewController *_delegate = [delegate valueForKey:@"_delegate"]; // for ivars
    YTPlayerViewController *parentViewController = _delegate.parentViewController;
    // Call our custom method in the YTPlayerViewController class
    if (parentViewController) {
        [parentViewController didPressYouLoop];
    }
    // Update button color
    [self.overlayButtons[TweakKey] setImage:getYouLoopImage(@"3") forState:0];
}

%end
%end

%ctor {
    tweakBundle = YouLoopBundle(); // not sure why I need to store tweakBundle
    // Setup as defined in the example from YTVideoOverlay
    initYTVideoOverlay(TweakKey, @{
        AccessibilityLabelKey: @"Toggle Loop",
        SelectorKey: @"didPressYouLoop:"
    });
    %init(Main);
    %init(Top);
    %init(Bottom);
}
