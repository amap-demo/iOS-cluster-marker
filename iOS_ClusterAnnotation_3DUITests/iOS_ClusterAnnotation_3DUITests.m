//
//  iOS_ClusterAnnotation_3DUITests.m
//  iOS_ClusterAnnotation_3DUITests
//
//  Created by hanxiaoming on 16/12/20.
//  Copyright © 2016年 AutoNavi. All rights reserved.
//

#import <XCTest/XCTest.h>

@interface iOS_ClusterAnnotation_3DUITests : XCTestCase

@end

@implementation iOS_ClusterAnnotation_3DUITests

- (void)setUp {
    [super setUp];
    
    // Put setup code here. This method is called before the invocation of each test method in the class.
    
    // In UI tests it is usually best to stop immediately when a failure occurs.
    self.continueAfterFailure = NO;
    // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
    [[[XCUIApplication alloc] init] launch];
    
    // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample {
    // Use recording to get started writing UI tests.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
    XCUIApplication *app = [[XCUIApplication alloc] init];
    XCUIElement *element = [[[[[[[app.otherElements containingType:XCUIElementTypeNavigationBar identifier:@"Cluster Annotations"] childrenMatchingType:XCUIElementTypeOther].element childrenMatchingType:XCUIElementTypeOther].element childrenMatchingType:XCUIElementTypeOther].element childrenMatchingType:XCUIElementTypeOther].element childrenMatchingType:XCUIElementTypeOther] elementBoundByIndex:1];
    
    [element doubleTap];
    [element swipeRight];
    [element swipeLeft];
    [element twoFingerTap];
    [element doubleTap];
    [element twoFingerTap];
    
    
    // 重新加载
    XCUIElement *button = app.buttons[@"\u91cd\u65b0\u52a0\u8f7d\u6570\u636e"];
    [button tap];
    [button tap];
    
    [element doubleTap];
    [element twoFingerTap];
    
    [[[element childrenMatchingType:XCUIElementTypeOther] elementBoundByIndex:5] tap];
    
    XCUIElement *appleStaticText = [app.tables.cells elementBoundByIndex:0];
    [appleStaticText tap];
    
    XCUIElement *clusterAnnotationsButton = app.navigationBars[@"POI\u4fe1\u606f (AMapPOI)"].buttons[@"Cluster Annotations"];
    [clusterAnnotationsButton tap];
    
}

@end
