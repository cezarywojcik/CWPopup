//
//  UIViewController+CWPopup.m
//  CWPopupDemo
//
//  Created by Cezary Wojcik on 8/21/13.
//  Copyright (c) 2013 Cezary Wojcik. All rights reserved.
//

#import "UIViewController+CWPopup.h"
#import <QuartzCore/QuartzCore.h>

#define ANIMATION_TIME 0.5

@implementation UIViewController (CWPopup)

- (void)presentPopupViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    CGRect frame = viewControllerToPresent.view.frame;
    CGFloat x = ([UIScreen mainScreen].bounds.size.width - viewControllerToPresent.view.frame.size.width)/2;
    CGFloat y =([UIScreen mainScreen].bounds.size.height - viewControllerToPresent.view.frame.size.height)/2;
    CGRect finalFrame = CGRectMake(x, y, frame.size.width, frame.size.height);
    // shadow setup
    viewControllerToPresent.view.layer.shadowOffset = CGSizeMake(0,0);
    viewControllerToPresent.view.layer.shadowColor = [UIColor blackColor].CGColor;
    viewControllerToPresent.view.layer.shadowRadius = 4.0f;
    viewControllerToPresent.view.layer.shadowOpacity = 0.8f;
    viewControllerToPresent.view.layer.shadowPath = [UIBezierPath bezierPathWithRect:viewControllerToPresent.view.layer.bounds].CGPath;
    if (flag) {
        CGRect initialFrame = CGRectMake(finalFrame.origin.x, [UIScreen mainScreen].bounds.size.height + 10, finalFrame.size.width, finalFrame.size.height);
        viewControllerToPresent.view.frame = initialFrame;
        [self.view addSubview:viewControllerToPresent.view];
        [UIView animateWithDuration:ANIMATION_TIME delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            viewControllerToPresent.view.frame = finalFrame;
        } completion:^(BOOL finished) {
            // code;
        }];
    } else {
        viewControllerToPresent.view.frame = finalFrame;
        [self.view addSubview:viewControllerToPresent.view];
    }
}

@end
