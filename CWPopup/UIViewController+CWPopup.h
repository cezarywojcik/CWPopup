//
//  UIViewController+CWPopup.h
//  CWPopupDemo
//
//  Created by Cezary Wojcik on 8/21/13.
//  Copyright (c) 2013 Cezary Wojcik. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIViewController (CWPopup)

@property (nonatomic, readwrite) UIViewController *popupViewController;
@property (nonatomic, readwrite) BOOL useBlurForPopup;
@property (nonatomic, readwrite) BOOL bgCatchTap;
@property (nonatomic, readwrite) BOOL closeOnBgTap;
@property (nonatomic, readwrite) BOOL hideShadow;
@property (nonatomic, readwrite) CGPoint popupViewOffset;

- (void)presentPopupViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion;
- (void)dismissPopupViewControllerAnimated:(BOOL)flag completion:(void (^)(void))completion;
- (void)setUseBlurForPopup:(BOOL)useBlurForPopup;
- (BOOL)useBlurForPopup;
- (BOOL)closeOnBgTap;
- (BOOL)bgCatchTap;
- (BOOL)hideShadow;
-(void)blurTap;
@end
