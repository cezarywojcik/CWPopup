//
//  UIViewController+CWPopup.m
//  CWPopupDemo
//
//  Created by Cezary Wojcik on 8/21/13.
//  Copyright (c) 2013 Cezary Wojcik. All rights reserved.
//

#import "UIViewController+CWPopup.h"
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// image blurring from http://stackoverflow.com/a/8916196

@interface UIImage (ImageBlur)
- (UIImage *)getImageWithBlur;
@end

@implementation UIImage (ImageBlur)
- (UIImage *)getImageWithBlur {
    float weight[5] = {0.2270270270, 0.1945945946, 0.1216216216, 0.0540540541, 0.0162162162};
    // Blur horizontally
    UIGraphicsBeginImageContext(self.size);
    [self drawInRect:CGRectMake(0, 0, self.size.width, self.size.height) blendMode:kCGBlendModePlusLighter alpha:weight[0]];
    for (int x = 1; x < 5; ++x) {
        [self drawInRect:CGRectMake(x, 0, self.size.width, self.size.height) blendMode:kCGBlendModePlusLighter alpha:weight[x]];
        [self drawInRect:CGRectMake(-x, 0, self.size.width, self.size.height) blendMode:kCGBlendModePlusLighter alpha:weight[x]];
    }
    UIImage *horizontallyBlurredImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    // Blur vertically
    UIGraphicsBeginImageContext(self.size);
    [horizontallyBlurredImage drawInRect:CGRectMake(0, 0, self.size.width, self.size.height) blendMode:kCGBlendModePlusLighter alpha:weight[0]];
    for (int y = 1; y < 5; ++y) {
        [horizontallyBlurredImage drawInRect:CGRectMake(0, y, self.size.width, self.size.height) blendMode:kCGBlendModePlusLighter alpha:weight[y]];
        [horizontallyBlurredImage drawInRect:CGRectMake(0, -y, self.size.width, self.size.height) blendMode:kCGBlendModePlusLighter alpha:weight[y]];
    }
    UIImage *blurredImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    //
    return blurredImage;
}
@end

#define ANIMATION_TIME 0.5f
#define STATUS_BAR_SIZE 22

NSString const *CWPopupKey = @"CWPopupkey";
NSString const *CWBlurViewKey = @"CWFadeViewKey";
NSString const *CWUseBlurForPopup = @"CWUseBlurForPopup";

@implementation UIViewController (CWPopup)

@dynamic popupViewController, useBlurForPopup;

#pragma mark - blur view methods

- (UIImage *)getScreenImage {
    // frame without status bar
    CGRect frame;
    if (UIDeviceOrientationIsPortrait([UIApplication sharedApplication].statusBarOrientation)) {
        frame = CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height);
    } else {
        frame = CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.height, [UIScreen mainScreen].bounds.size.width);
    }
    // begin image context
    UIGraphicsBeginImageContext(frame.size);
    // get current context
    CGContextRef currentContext = UIGraphicsGetCurrentContext();
    // draw current view
    [self.view.layer renderInContext:UIGraphicsGetCurrentContext()];
    // clip context to frame
    CGContextClipToRect(currentContext, frame);
    // get resulting cropped screenshot
    UIImage *screenshot = UIGraphicsGetImageFromCurrentImageContext();
    // end image context
    UIGraphicsEndImageContext();
    return screenshot;
}

- (UIImage *)getBlurredImage:(UIImage *)imageToBlur {
    return [[imageToBlur getImageWithBlur] getImageWithBlur];
}

- (void)addBlurView {
    UIImageView *blurView = [UIImageView new];
    if (UIDeviceOrientationIsPortrait([UIApplication sharedApplication].statusBarOrientation)) {
        blurView.frame = CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height);
    } else {
        blurView.frame = CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.height, [UIScreen mainScreen].bounds.size.width);
    }
    blurView.alpha = 0.0f;
    blurView.image = [self getBlurredImage:[self getScreenImage]];
    [self.view addSubview:blurView];
    [self.view bringSubviewToFront:self.popupViewController.view];
    objc_setAssociatedObject(self, &CWBlurViewKey, blurView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - present/dismiss

- (void)presentPopupViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (self.popupViewController == nil) {
        // initial setup
        self.popupViewController = viewControllerToPresent;
        self.popupViewController.view.autoresizesSubviews = NO;
        self.popupViewController.view.autoresizingMask = UIViewAutoresizingNone;
        [self.popupViewController viewWillAppear:YES];
        CGRect finalFrame = [self getPopupFrameForViewController:viewControllerToPresent];
        // parallax setup if iOS7+
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
        if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0) {
            UIInterpolatingMotionEffect *interpolationHorizontal = [[UIInterpolatingMotionEffect alloc] initWithKeyPath:@"center.x" type:UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis];
            interpolationHorizontal.minimumRelativeValue = @-10.0;
            interpolationHorizontal.maximumRelativeValue = @10.0;
            UIInterpolatingMotionEffect *interpolationVertical = [[UIInterpolatingMotionEffect alloc] initWithKeyPath:@"center.y" type:UIInterpolatingMotionEffectTypeTiltAlongVerticalAxis];
            interpolationHorizontal.minimumRelativeValue = @-10.0;
            interpolationHorizontal.maximumRelativeValue = @10.0;
            [self.popupViewController.view addMotionEffect:interpolationHorizontal];
            [self.popupViewController.view addMotionEffect:interpolationVertical];
        }
#endif
        // shadow setup
        viewControllerToPresent.view.layer.shadowOffset = CGSizeMake(0.0f, 0.0f);
        viewControllerToPresent.view.layer.shadowColor = [UIColor blackColor].CGColor;
        viewControllerToPresent.view.layer.shadowRadius = 3.0f;
        viewControllerToPresent.view.layer.shadowOpacity = 0.8f;
        viewControllerToPresent.view.layer.shadowPath = [UIBezierPath bezierPathWithRect:viewControllerToPresent.view.layer.bounds].CGPath;
        // rounded corners
        viewControllerToPresent.view.layer.cornerRadius = 5.0f;
        // blurview
        if (self.useBlurForPopup) {
            [self addBlurView];
        } else {
            UIView *fadeView = [UIView new];
            if (UIDeviceOrientationIsPortrait([UIApplication sharedApplication].statusBarOrientation)) {
                fadeView.frame = [UIScreen mainScreen].bounds;
            } else {
                fadeView.frame = CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.height, [UIScreen mainScreen].bounds.size.width);
            }
            fadeView.backgroundColor = [UIColor blackColor];
            fadeView.alpha = 0.0f;
            [self.view addSubview:fadeView];
            objc_setAssociatedObject(self, &CWBlurViewKey, fadeView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        UIView *blurView = objc_getAssociatedObject(self, &CWBlurViewKey);
        // setup
        if (flag) { // animate
            CGRect initialFrame = CGRectMake(finalFrame.origin.x, [UIScreen mainScreen].bounds.size.height + viewControllerToPresent.view.frame.size.height/2, finalFrame.size.width, finalFrame.size.height);
            viewControllerToPresent.view.frame = initialFrame;
            [self.view addSubview:viewControllerToPresent.view];
            [UIView animateWithDuration:ANIMATION_TIME delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
                viewControllerToPresent.view.frame = finalFrame;
                blurView.alpha = self.useBlurForPopup ? 1.0f : 0.4f;
            } completion:^(BOOL finished) {
                [self.popupViewController viewDidAppear:YES];
                [completion invoke];
            }];
        } else { // don't animate
            [self.popupViewController viewDidAppear:YES];
            viewControllerToPresent.view.frame = finalFrame;
            [self.view addSubview:viewControllerToPresent.view];
            [completion invoke];
        }
        // if screen orientation changed
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(screenOrientationChanged) name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];
    }
}

- (void)dismissPopupViewControllerAnimated:(BOOL)flag completion:(void (^)(void))completion {
    UIView *blurView = objc_getAssociatedObject(self, &CWBlurViewKey);
    [self.popupViewController viewWillDisappear:YES];
    if (flag) { // animate
        CGRect initialFrame = self.popupViewController.view.frame;
        [UIView animateWithDuration:ANIMATION_TIME delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self.popupViewController.view.frame = CGRectMake(initialFrame.origin.x, [UIScreen mainScreen].bounds.size.height + initialFrame.size.height/2, initialFrame.size.width, initialFrame.size.height);
            // uncomment the line below to have slight rotation during the dismissal
            // self.popupViewController.view.transform = CGAffineTransformMakeRotation(M_PI/6);
            blurView.alpha = 0.0f;
        } completion:^(BOOL finished) {
            [self.popupViewController viewDidDisappear:YES];
            [self.popupViewController.view removeFromSuperview];
            [blurView removeFromSuperview];
            self.popupViewController = nil;
            [completion invoke];
        }];
    } else { // don't animate
        [self.popupViewController viewDidDisappear:YES];
        [self.popupViewController.view removeFromSuperview];
        [blurView removeFromSuperview];
        self.popupViewController = nil; 
        blurView = nil;
        [completion invoke];
    }
    // remove observer
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - handling screen orientation change

- (CGRect)getPopupFrameForViewController:(UIViewController *)viewController {
    CGRect frame = viewController.view.frame;
    CGFloat x;
    CGFloat y;
    if (UIDeviceOrientationIsPortrait([UIApplication sharedApplication].statusBarOrientation)) {
        x = ([UIScreen mainScreen].bounds.size.width - frame.size.width)/2;
        y = ([UIScreen mainScreen].bounds.size.height - frame.size.height)/2;
    } else {
        x = ([UIScreen mainScreen].bounds.size.height - frame.size.width)/2;
        y = ([UIScreen mainScreen].bounds.size.width - frame.size.height)/2;
    }
    return CGRectMake(x, y, frame.size.width, frame.size.height);
}

- (void)screenOrientationChanged {
    // make blur view go away so that we can re-blur the original back
    UIView *blurView = objc_getAssociatedObject(self, &CWBlurViewKey);
    [UIView animateWithDuration:ANIMATION_TIME animations:^{
        self.popupViewController.view.frame = [self getPopupFrameForViewController:self.popupViewController];
        if (UIDeviceOrientationIsPortrait([UIApplication sharedApplication].statusBarOrientation)) {
            blurView.frame = [UIScreen mainScreen].bounds;
        } else {
            blurView.frame = CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.height, [UIScreen mainScreen].bounds.size.width);
        }
        if (self.useBlurForPopup) {
            [UIView animateWithDuration:1.0f animations:^{
                // for delay
            } completion:^(BOOL finished) {
                [blurView removeFromSuperview];
                // popup view alpha to 0 so its not in the blur image
                self.popupViewController.view.alpha = 0.0f;
                [self addBlurView];
                self.popupViewController.view.alpha = 1.0f;
                // display blurView again
                UIView *blurView = objc_getAssociatedObject(self, &CWBlurViewKey);
                blurView.alpha = 1.0f;
            }];
        }
    }];
}

#pragma mark - popupViewController getter/setter

- (void)setPopupViewController:(UIViewController *)popupViewController {
    objc_setAssociatedObject(self, &CWPopupKey, popupViewController, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIViewController *)popupViewController {
    return objc_getAssociatedObject(self, &CWPopupKey);

}

- (void)setUseBlurForPopup:(BOOL)useBlurForPopup {
    objc_setAssociatedObject(self, &CWUseBlurForPopup, [NSNumber numberWithBool:useBlurForPopup], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)useBlurForPopup {
    NSNumber *result = objc_getAssociatedObject(self, &CWUseBlurForPopup);
    return [result boolValue];

}

@end
