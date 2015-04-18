//
//  CWPopupTests.m
//  CWPopupDemo
//
//  Created by Nicolas Goles on 4/18/15.
//  Copyright (c) 2015 Cezary Wojcik. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "UIViewController+CWPopup.h"

@interface CWPopupTests : XCTestCase
@property (nonatomic, strong) UIViewController *testViewController;
@property (nonatomic, strong) UIViewController *testContainerViewController;
@end

@implementation CWPopupTests

- (void)setUp {
    [super setUp];
	
	// Setup Test View Controller
	_testViewController = [UIViewController new];
	_testViewController.view = [UIView new];
	_testViewController.view.frame = CGRectMake(0, 0, 200, 300);
	
	// Setup Container View Controller
	_testContainerViewController = [UIViewController new];
	_testContainerViewController.view = [UIView new];
	_testViewController.view.frame = CGRectMake(0, 0, 100, 400);
}

- (void)tearDown {
    [super tearDown];
	_testViewController = nil;
	_testContainerViewController = nil;
}

- (void)testPresentPopupViewControllerAnimatedNO_withContaineAndTestPopupControllers_testControllerShouldMatchAChildController {
	[_testContainerViewController presentPopupViewController:_testViewController animated:NO completion:^{
		XCTAssert([_testContainerViewController.childViewControllers containsObject:_testViewController]);
	}];
}

- (void)testPresentPopupViewControllerAnimatedYES_withContainerAndTestPopupControllers_testControllerShouldMatchAChildController {
	XCTestExpectation *expectaction = [self expectationWithDescription:@"Should Finish Presenting Popup View Controller"];
	
	[_testContainerViewController presentPopupViewController:_testViewController animated:YES completion:^{
		XCTAssert([_testContainerViewController.childViewControllers containsObject:_testViewController]);
		[expectaction fulfill];
	}];
	
	[self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
		if (error) {
			NSLog(@"Timeout error presenting ViewController: %@", error);
		}
	}];
	
}

- (void)testDismissPopupViewControllerAnimatedNO_withContainerAndTestPopupControllers_testControllerShouldNotBeAChildController
{
	[_testContainerViewController presentPopupViewController:_testViewController animated:NO completion:^{
    	[_testContainerViewController dismissPopupViewControllerAnimated:NO completion:^{
			XCTAssert(![_testContainerViewController.childViewControllers containsObject:_testViewController]);
    	}];
	}];
}

- (void)testDismissPopupViewControllerAnimatedYES_withContainerAndTestPopupControllers_testControllerShouldNotBeAChildController
{
	XCTestExpectation *expectation = [self expectationWithDescription:@"Should finish dismissing a PopupViewController"];
									  
	[_testContainerViewController presentPopupViewController:_testViewController animated:NO completion:^{
    	[_testContainerViewController dismissPopupViewControllerAnimated:YES completion:^{
			XCTAssert(![_testContainerViewController.childViewControllers containsObject:_testViewController]);
			[expectation fulfill];
    	}];
	}];
	
	[self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
		if (error) {
			NSLog(@"Timeout error dismissing ViewController: %@", error);
		}
	}];
}

@end
