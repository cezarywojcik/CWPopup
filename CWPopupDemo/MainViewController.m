//
//  MainViewController.m
//  CWPopupDemo
//
//  Created by Cezary Wojcik on 8/21/13.
//  Copyright (c) 2013 Cezary Wojcik. All rights reserved.
//

#import "MainViewController.h"
#import "SamplePopupViewController.h"
#import "UIViewController+CWPopup.h"

@interface MainViewController ()

@end

@implementation MainViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - IBActions

- (IBAction)btnPresentPopup:(UIButton *)sender {
    SamplePopupViewController *samplePopupViewController = [[SamplePopupViewController alloc] initWithNibName:@"SamplePopupViewController" bundle:nil];
    [self presentPopupViewController:samplePopupViewController animated:YES completion:^{
        NSLog(@"popup view presented!");
    }];
}

@end
