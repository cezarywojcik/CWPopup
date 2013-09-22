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
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
@import Accelerate;
#endif
#import <float.h>

@interface UIImage (ImageBlur)
- (UIImage *)applyBlurWithRadius:(CGFloat)blurRadius tintColor:(UIColor *)tintColor saturationDeltaFactor:(CGFloat)saturationDeltaFactor maskImage:(UIImage *)maskImage;
@end

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
@implementation UIImage (ImageBlur)
// This method is taken from Apple's UIImageEffects category provided in WWDC 2013 sample code
- (UIImage *)applyBlurWithRadius:(CGFloat)blurRadius tintColor:(UIColor *)tintColor saturationDeltaFactor:(CGFloat)saturationDeltaFactor maskImage:(UIImage *)maskImage
{
    // Check pre-conditions.
    if (self.size.width < 1 || self.size.height < 1) {
        NSLog (@"*** error: invalid size: (%.2f x %.2f). Both dimensions must be >= 1: %@", self.size.width, self.size.height, self);
        return nil;
    }
    if (!self.CGImage) {
        NSLog (@"*** error: image must be backed by a CGImage: %@", self);
        return nil;
    }
    if (maskImage && !maskImage.CGImage) {
        NSLog (@"*** error: maskImage must be backed by a CGImage: %@", maskImage);
        return nil;
    }

    CGRect imageRect = { CGPointZero, self.size };
    UIImage *effectImage = self;

    BOOL hasBlur = blurRadius > __FLT_EPSILON__;
    BOOL hasSaturationChange = fabs(saturationDeltaFactor - 1.) > __FLT_EPSILON__;
    if (hasBlur || hasSaturationChange) {
        UIGraphicsBeginImageContextWithOptions(self.size, NO, [[UIScreen mainScreen] scale]);
        CGContextRef effectInContext = UIGraphicsGetCurrentContext();
        CGContextScaleCTM(effectInContext, 1.0, -1.0);
        CGContextTranslateCTM(effectInContext, 0, -self.size.height);
        CGContextDrawImage(effectInContext, imageRect, self.CGImage);

        vImage_Buffer effectInBuffer;
        effectInBuffer.data     = CGBitmapContextGetData(effectInContext);
        effectInBuffer.width    = CGBitmapContextGetWidth(effectInContext);
        effectInBuffer.height   = CGBitmapContextGetHeight(effectInContext);
        effectInBuffer.rowBytes = CGBitmapContextGetBytesPerRow(effectInContext);

        UIGraphicsBeginImageContextWithOptions(self.size, NO, [[UIScreen mainScreen] scale]);
        CGContextRef effectOutContext = UIGraphicsGetCurrentContext();
        vImage_Buffer effectOutBuffer;
        effectOutBuffer.data     = CGBitmapContextGetData(effectOutContext);
        effectOutBuffer.width    = CGBitmapContextGetWidth(effectOutContext);
        effectOutBuffer.height   = CGBitmapContextGetHeight(effectOutContext);
        effectOutBuffer.rowBytes = CGBitmapContextGetBytesPerRow(effectOutContext);

        if (hasBlur) {
            // A description of how to compute the box kernel width from the Gaussian
            // radius (aka standard deviation) appears in the SVG spec:
            // http://www.w3.org/TR/SVG/filters.html#feGaussianBlurElement
            //
            // For larger values of 's' (s >= 2.0), an approximation can be used: Three
            // successive box-blurs build a piece-wise quadratic convolution kernel, which
            // approximates the Gaussian kernel to within roughly 3%.
            //
            // let d = floor(s * 3*sqrt(2*pi)/4 + 0.5)
            //
            // ... if d is odd, use three box-blurs of size 'd', centered on the output pixel.
            //
            CGFloat inputRadius = blurRadius * [[UIScreen mainScreen] scale];
            NSUInteger radius = floor(inputRadius * 3. * sqrt(2 * M_PI) / 4 + 0.5);
            if (radius % 2 != 1) {
                radius += 1; // force radius to be odd so that the three box-blur methodology works.
            }
            vImageBoxConvolve_ARGB8888(&effectInBuffer, &effectOutBuffer, NULL, 0, 0, radius, radius, 0, kvImageEdgeExtend);
            vImageBoxConvolve_ARGB8888(&effectOutBuffer, &effectInBuffer, NULL, 0, 0, radius, radius, 0, kvImageEdgeExtend);
            vImageBoxConvolve_ARGB8888(&effectInBuffer, &effectOutBuffer, NULL, 0, 0, radius, radius, 0, kvImageEdgeExtend);
        }
        BOOL effectImageBuffersAreSwapped = NO;
        if (hasSaturationChange) {
            CGFloat s = saturationDeltaFactor;
            CGFloat floatingPointSaturationMatrix[] = {
                0.0722 + 0.9278 * s,  0.0722 - 0.0722 * s,  0.0722 - 0.0722 * s,  0,
                0.7152 - 0.7152 * s,  0.7152 + 0.2848 * s,  0.7152 - 0.7152 * s,  0,
                0.2126 - 0.2126 * s,  0.2126 - 0.2126 * s,  0.2126 + 0.7873 * s,  0,
                0,                    0,                    0,  1,
            };
            const int32_t divisor = 256;
            NSUInteger matrixSize = sizeof(floatingPointSaturationMatrix)/sizeof(floatingPointSaturationMatrix[0]);
            int16_t saturationMatrix[matrixSize];
            for (NSUInteger i = 0; i < matrixSize; ++i) {
                saturationMatrix[i] = (int16_t)roundf(floatingPointSaturationMatrix[i] * divisor);
            }
            if (hasBlur) {
                vImageMatrixMultiply_ARGB8888(&effectOutBuffer, &effectInBuffer, saturationMatrix, divisor, NULL, NULL, kvImageNoFlags);
                effectImageBuffersAreSwapped = YES;
            }
            else {
                vImageMatrixMultiply_ARGB8888(&effectInBuffer, &effectOutBuffer, saturationMatrix, divisor, NULL, NULL, kvImageNoFlags);
            }
        }
        if (!effectImageBuffersAreSwapped)
            effectImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();

        if (effectImageBuffersAreSwapped)
            effectImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }

    // Set up output context.
    UIGraphicsBeginImageContextWithOptions(self.size, NO, [[UIScreen mainScreen] scale]);
    CGContextRef outputContext = UIGraphicsGetCurrentContext();
    CGContextScaleCTM(outputContext, 1.0, -1.0);
    CGContextTranslateCTM(outputContext, 0, -self.size.height);

    // Draw base image.
    CGContextDrawImage(outputContext, imageRect, self.CGImage);

    // Draw effect image.
    if (hasBlur) {
        CGContextSaveGState(outputContext);
        if (maskImage) {
            CGContextClipToMask(outputContext, imageRect, maskImage.CGImage);
        }
        CGContextDrawImage(outputContext, imageRect, effectImage.CGImage);
        CGContextRestoreGState(outputContext);
    }

    // Add in color tint.
    if (tintColor) {
        CGContextSaveGState(outputContext);
        CGContextSetFillColorWithColor(outputContext, tintColor.CGColor);
        CGContextFillRect(outputContext, imageRect);
        CGContextRestoreGState(outputContext);
    }

    // Output image is ready.
    UIImage *outputImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return outputImage;
}
@end
#endif

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
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0) {
        return [imageToBlur applyBlurWithRadius:10.0f tintColor:[UIColor clearColor] saturationDeltaFactor:1.0 maskImage:nil];
    }
    return imageToBlur;
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
    if ([[[UIDevice currentDevice] systemVersion] floatValue] < 7.0 && useBlurForPopup) {
        NSLog(@"ERROR: Blur unavailable prior to iOS 7");
        objc_setAssociatedObject(self, &CWUseBlurForPopup, [NSNumber numberWithBool:NO], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else {
        objc_setAssociatedObject(self, &CWUseBlurForPopup, [NSNumber numberWithBool:useBlurForPopup], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

- (BOOL)useBlurForPopup {
    NSNumber *result = objc_getAssociatedObject(self, &CWUseBlurForPopup);
    return [result boolValue];

}

@end
