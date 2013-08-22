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

#define ANIMATION_TIME 0.5

NSString const *CWPopupKey = @"CWPopupkey";

@implementation UIViewController (CWPopup)

@dynamic popupViewController;

#pragma mark - present/dismiss

- (void)presentPopupViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    // setup
    self.popupViewController = viewControllerToPresent;
    CGRect frame = viewControllerToPresent.view.frame;
    CGFloat x = ([UIScreen mainScreen].bounds.size.width - viewControllerToPresent.view.frame.size.width)/2;
    CGFloat y =([UIScreen mainScreen].bounds.size.height - viewControllerToPresent.view.frame.size.height)/2;
    CGRect finalFrame = CGRectMake(x, y, frame.size.width, frame.size.height);
    // shadow setup
    viewControllerToPresent.view.layer.shadowOffset = CGSizeMake(0,0);
    viewControllerToPresent.view.layer.shadowColor = [UIColor blackColor].CGColor;
    viewControllerToPresent.view.layer.shadowRadius = 3.0f;
    viewControllerToPresent.view.layer.shadowOpacity = 0.8f;
    viewControllerToPresent.view.layer.shadowPath = [UIBezierPath bezierPathWithRect:viewControllerToPresent.view.layer.bounds].CGPath;
    // rounded corners
    viewControllerToPresent.view.layer.cornerRadius = 5.0f;
    if (flag) { // animate
        CGRect initialFrame = CGRectMake(finalFrame.origin.x, [UIScreen mainScreen].bounds.size.height + 10, finalFrame.size.width, finalFrame.size.height);
        viewControllerToPresent.view.frame = initialFrame;
        [self.view addSubview:viewControllerToPresent.view];
        [UIView animateWithDuration:ANIMATION_TIME delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            viewControllerToPresent.view.frame = finalFrame;
        } completion:^(BOOL finished) {
            [completion invoke];
        }];
    } else { // don't animate
        viewControllerToPresent.view.frame = finalFrame;
        [self.view addSubview:viewControllerToPresent.view];
        [completion invoke];
    }
}

- (void)dismissPopupViewControllerAnimated:(BOOL)flag completion:(void (^)(void))completion {
    if (flag) { // animate
        CGRect initialFrame = self.popupViewController.view.frame;
        [UIView animateWithDuration:ANIMATION_TIME delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self.popupViewController.view.frame = CGRectMake(initialFrame.origin.x, [UIScreen mainScreen].bounds.size.height, initialFrame.size.width, initialFrame.size.height);
        } completion:^(BOOL finished) {
            [self.popupViewController.view removeFromSuperview];
            self.popupViewController = nil;
            [completion invoke];
        }];
    } else { // don't animate
        [self.popupViewController.view removeFromSuperview];
        self.popupViewController = nil;
        [completion invoke];
    }
}

#pragma mark - popupViewController getter/setter

- (void)setPopupViewController:(UIViewController *)popupViewController {
    objc_setAssociatedObject(self, &CWPopupKey, popupViewController, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIViewController *)popupViewController {
    return objc_getAssociatedObject(self, &CWPopupKey);
}

@end
