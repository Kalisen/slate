//
//  TestFrameChange.m
//  Slate
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see http://www.gnu.org/licenses

#import <XCTest/XCTest.h>
#import "AccessibilityWrapper.h"
#import "MoveOperation.h"
#import "ResizeOperation.h"
#import "ScreenWrapper.h"

// A window of an app whose AXEnhancedUserInterface flag is scripted; records the calls it receives.
@interface RecordingWindow : AccessibilityWrapper
@property (assign) BOOL enhanced;
@property (assign) NSRect frame;
@property (strong) NSMutableArray *calls;
@end

@implementation RecordingWindow

- (id)initWithEnhancedUserInterface:(BOOL)enhanced {
  self = [super initWithApp:NULL window:NULL];
  if (self) {
    [self setEnhanced:enhanced];
    [self setFrame:NSMakeRect(100, 100, 300, 200)];
    [self setCalls:[NSMutableArray array]];
  }
  return self;
}

- (NSPoint)getCurrentTopLeft { return [self frame].origin; }
- (NSSize)getCurrentSize { return [self frame].size; }

- (BOOL)moveWindow:(NSPoint)thePoint {
  [[self calls] addObject:@"move"];
  [self setFrame:NSMakeRect(thePoint.x, thePoint.y, [self frame].size.width, [self frame].size.height)];
  return YES;
}

- (BOOL)resizeWindow:(NSSize)theSize {
  [[self calls] addObject:@"resize"];
  [self setFrame:NSMakeRect([self frame].origin.x, [self frame].origin.y, theSize.width, theSize.height)];
  return YES;
}

- (BOOL)isEnhancedUserInterfaceEnabled { return [self enhanced]; }

- (void)setEnhancedUserInterfaceEnabled:(BOOL)enabled {
  [[self calls] addObject:(enabled ? @"enhanced-on" : @"enhanced-off")];
  [self setEnhanced:enabled];
}

@end

@interface TestFrameChange : XCTestCase
@end

@implementation TestFrameChange

- (MoveOperation *)move {
  return [MoveOperation moveOperationFromString:@"move screenOriginX;screenOriginY screenSizeX/2;screenSizeY"];
}

- (void)testMoveSuspendsEnhancedUserInterfaceAroundFrameChange {
  RecordingWindow *window = [[RecordingWindow alloc] initWithEnhancedUserInterface:YES];
  XCTAssertTrue([[self move] doOperationWithAccessibilityWrapper:window screenWrapper:[[ScreenWrapper alloc] init]]);
  NSArray *expected = @[@"enhanced-off", @"resize", @"move", @"resize", @"enhanced-on"];
  XCTAssertEqualObjects([window calls], expected);
  XCTAssertTrue([window enhanced]);
}

- (void)testMoveLeavesEnhancedUserInterfaceUntouchedWhenOff {
  RecordingWindow *window = [[RecordingWindow alloc] initWithEnhancedUserInterface:NO];
  XCTAssertTrue([[self move] doOperationWithAccessibilityWrapper:window screenWrapper:[[ScreenWrapper alloc] init]]);
  NSArray *expected = @[@"resize", @"move", @"resize"];
  XCTAssertEqualObjects([window calls], expected);
  XCTAssertFalse([window enhanced]);
}

- (void)testResizeSuspendsEnhancedUserInterfaceAroundFrameChange {
  RecordingWindow *window = [[RecordingWindow alloc] initWithEnhancedUserInterface:YES];
  ResizeOperation *op = [ResizeOperation resizeOperationFromString:@"resize +10 +10"];
  XCTAssertTrue([op doOperationWithAccessibilityWrapper:window screenWrapper:[[ScreenWrapper alloc] init]]);
  NSArray *expected = @[@"enhanced-off", @"resize", @"move", @"enhanced-on"];
  XCTAssertEqualObjects([window calls], expected);
}

- (void)testEnhancedUserInterfaceIsRestoredWhenFrameChangeFails {
  RecordingWindow *window = [[RecordingWindow alloc] initWithEnhancedUserInterface:YES];
  XCTAssertFalse([window changeFrameWithoutAnimation:^BOOL { return NO; }]);
  XCTAssertTrue([window enhanced]);
}

- (void)testEnhancedUserInterfaceIsRestoredWhenFrameChangeThrows {
  RecordingWindow *window = [[RecordingWindow alloc] initWithEnhancedUserInterface:YES];
  XCTAssertThrows([window changeFrameWithoutAnimation:^BOOL {
    @throw [NSException exceptionWithName:@"Unable to compute result" reason:@"test" userInfo:nil];
  }]);
  XCTAssertTrue([window enhanced]);
}

@end
