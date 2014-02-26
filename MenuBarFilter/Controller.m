/*
 File: Controller.m
 Abstract: Handles UI interaction and retrieves window images.
 Version: 1.1

 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.

 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.

 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.

 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.

 Copyright (C) 2010 Apple Inc. All Rights Reserved.

 */

#import "Controller.h"
#import <CoreGraphics/CoreGraphics.h>
#import <QuartzCore/QuartzCore.h>

@implementation Controller
@synthesize outputView;

#pragma mark Basic Profiling Tools
// Set to 1 to enable basic profiling. Profiling information is logged to console.
#ifndef PROFILE_WINDOW_GRAB
#define PROFILE_WINDOW_GRAB 0
#endif

#if PROFILE_WINDOW_GRAB
#define StopwatchStart() AbsoluteTime start = UpTime()
#define Profile(img) CFRelease(CGDataProviderCopyData(CGImageGetDataProvider(img)))
#define StopwatchEnd(caption) do { Duration time = AbsoluteDeltaToDuration(UpTime(), start); double timef = time < 0 ? time / -1000000.0 : time / 1000.0; NSLog(@"%s Time Taken: %f seconds", caption, timef); } while(0)
#else
#define StopwatchStart()
#define Profile(img)
#define StopwatchEnd(caption)
#endif

#pragma mark Utilities

NSString *kAppNameKey = @"applicationName";	// Application Name & PID
NSString *kWindowOriginKey = @"windowOrigin";	// Window Origin as a string
NSString *kWindowSizeKey = @"windowSize";		// Window Size as a string
NSString *kWindowIDKey = @"windowID";			// Window ID
NSString *kWindowLevelKey = @"windowLevel";	// Window Level
NSString *kWindowOrderKey = @"windowOrder";	// The overall front-to-back ordering of the

// Simple helper to twiddle bits in a uint32_t.
inline uint32_t ChangeBits(uint32_t currentBits, uint32_t flagsToChange, BOOL setFlags);
uint32_t ChangeBits(uint32_t currentBits, uint32_t flagsToChange, BOOL setFlags) {
	if(setFlags) {	// Set Bits
		return currentBits | flagsToChange;
	} else {	// Clear Bits
		return currentBits & ~flagsToChange;
	}
}

- (void)setOutputImage:(CGImageRef)cgImage {
    StopwatchStart();
	if (cgImage != NULL) {
		// Create a bitmap rep from the image...
		// Set the output view to the new NSImage.
		[outputView performSelectorOnMainThread:@selector(setImage:) withObject:(__bridge id)cgImage waitUntilDone:NO];
	} else {
        NSLog(@"Image is null");
		[outputView performSelectorOnMainThread:@selector(setImage:) withObject:nil waitUntilDone:NO];
	}
	StopwatchEnd("Outputting Image");
}

- (NSPoint)screenOffset {
#if 0
	if (!notificationCenter) {
		NSArray *windowList = (__bridge NSArray *)CGWindowListCopyWindowInfo(listOptions, kCGNullWindowID);
		for (NSDictionary *window in windowList) {
			//Notification center level 25 size 0x0

			if ([[window objectForKey:(__bridge NSString *)kCGWindowOwnerName] isEqualToString:@"Notification Center"] &&
				[[[window objectForKey:(__bridge NSString *)kCGWindowBounds] objectForKey:@"Width"]  intValue] == 0 &&
				[[[window objectForKey:(__bridge NSString *)kCGWindowBounds] objectForKey:@"Height"] intValue] == 0 &&
				[[window objectForKey:(__bridge NSString *)kCGWindowLayer] intValue] == 25 &&
				[[[window objectForKey:(__bridge NSString *)kCGWindowBounds] objectForKey:@"X"] intValue] == [[NSScreen mainScreen] frame].size.width &&
				[[[window objectForKey:(__bridge NSString *)kCGWindowBounds] objectForKey:@"Y"] intValue] == 0) {
				//It's our notif center

				notificationCenter = [[window objectForKey:(__bridge NSString *)kCGWindowNumber] intValue];
			}
		}
	}

    if (notificationCenter) {
        NSArray *info = (__bridge NSArray *)CGWindowListCopyWindowInfo(kCGWindowListOptionIncludingWindow, notificationCenter);
		if ([info count]) {
			NSDictionary *bounds = [[info objectAtIndex:0] objectForKey:(__bridge NSString *)kCGWindowBounds];
			return NSMakePoint([[bounds objectForKey:@"X"] intValue] - [[NSScreen mainScreen] frame].size.width, 0);
		}
    }
#endif
    return NSMakePoint(0, 0);
}

#pragma mark Window Image Methods

- (void)createSingleWindowShot:(CGWindowID)windowID {
	// Create an image from the passed in windowID with the single window option selected by the user.
	StopwatchStart();
	CGImageRef windowImage = CGWindowListCreateImage(imageBounds, singleWindowListOptions, windowID, imageOptions);
	Profile(windowImage);
	StopwatchEnd("Single Window");
	[self setOutputImage:windowImage];
	CGImageRelease(windowImage);
}

- (void)createScreenShot {
	// This just invokes the API as you would if you wanted to grab a screen shot. The equivalent using the UI would be to
	// enable all windows, turn off "Fit Image Tightly", and then select all windows in the list.
	StopwatchStart();
	CGImageRef screenShot = CGWindowListCreateImage(CGRectInfinite, kCGWindowListOptionOnScreenAboveWindow | kCGWindowListOptionIncludingWindow, kCGNullWindowID, kCGWindowImageDefault);
	Profile(screenShot);
	StopwatchEnd("Screenshot");
	[self setOutputImage:screenShot];
	CGImageRelease(screenShot);
}

#pragma mark GUI Support

- (void)updateImageWithSelection {
	// Depending on how much is selected either clear the output image or
	// set the image based on a single selected window

    //GS- Removed most of this so it can take a window ID passed in via -setWindowId:
	if (windowId == 0) {
		[self setOutputImage:NULL];
	} else {
		// Single window selected, so use the single window options.
		[self createSingleWindowShot:windowId];
	}
}

// Simple helper that converts the selected row number of the singleWindow NSMatrix
// to the appropriate CGWindowListOption.
- (CGWindowListOption)singleWindowOption {
	CGWindowListOption option = 0;
	switch (windowOption) {
		case kSingleWindowAboveOnly:
			option = kCGWindowListOptionOnScreenAboveWindow;
			break;

		case kSingleWindowAboveIncluded:
			option = kCGWindowListOptionOnScreenAboveWindow | kCGWindowListOptionIncludingWindow;
			break;

		case kSingleWindowOnly:
			option = kCGWindowListOptionIncludingWindow;
			break;

		case kSingleWindowBelowIncluded:
			option = kCGWindowListOptionOnScreenBelowWindow | kCGWindowListOptionIncludingWindow;
			break;

		case kSingleWindowBelowOnly:
			option = kCGWindowListOptionOnScreenBelowWindow;
			break;

		default:
			break;
	}
	return option;
}

- (id)init {
    self = [super init];

	// Set the initial list options to match the UI.
	listOptions = kCGWindowListOptionAll;
	listOptions = ChangeBits(listOptions, kCGWindowListOptionOnScreenOnly, NO);
	listOptions = ChangeBits(listOptions, kCGWindowListExcludeDesktopElements, YES);

	// Set the initial image options to match the UI.
	imageOptions = kCGWindowImageDefault;
	imageOptions = ChangeBits(imageOptions, kCGWindowImageBoundsIgnoreFraming, YES);
	imageOptions = ChangeBits(imageOptions, kCGWindowImageShouldBeOpaque, YES);
	imageOptions = ChangeBits(imageOptions, kCGWindowImageOnlyShadows, NO);

	// Set initial single window options to match the UI.
	singleWindowListOptions = [self singleWindowOption];

	// CGWindowListCreateImage & CGWindowListCreateImageFromArray will determine their image size dependent on the passed in bounds.
	// This sample only demonstrates passing either CGRectInfinite to get an image the size of the desktop
	// or passing CGRectNull to get an image that tightly fits the windows specified, but you can pass any rect you like.
	imageBounds = CGRectNull;

	// Default to creating a screen shot. Do this after our return since the previous request
	// to refresh the window list will set it to nothing due to the interactions with KVO.
	[self performSelectorOnMainThread:@selector(createScreenShot) withObject:self waitUntilDone:NO];

    notificationCenter = 0;
    NSArray *windowList = (__bridge NSArray *)CGWindowListCopyWindowInfo(listOptions, kCGNullWindowID);
    for (NSDictionary *window in windowList) {
        //Notification center level 25 size 0x0

        if ([[window objectForKey:(__bridge NSString *)kCGWindowOwnerName] isEqualToString:@"Notification Center"] &&
            [[[window objectForKey:(__bridge NSString *)kCGWindowBounds] objectForKey:@"Width"]  intValue] == 0 &&
            [[[window objectForKey:(__bridge NSString *)kCGWindowBounds] objectForKey:@"Height"] intValue] == 0 &&
            [[window objectForKey:(__bridge NSString *)kCGWindowLayer] intValue] == 25 &&
            [[[window objectForKey:(__bridge NSString *)kCGWindowBounds] objectForKey:@"X"] intValue] == [[NSScreen mainScreen] frame].size.width &&
            [[[window objectForKey:(__bridge NSString *)kCGWindowBounds] objectForKey:@"Y"] intValue] == 0) {
            //It's our notif center

            notificationCenter = [[window objectForKey:(__bridge NSString *)kCGWindowNumber] intValue];
        }
    }

    return self;
}


#pragma mark Control Actions

- (void)update {
    [self updateImageWithSelection];
}

- (void)setWindowId:(CGSWindow)newWindowId {
    windowId = newWindowId;
	singleWindowListOptions = [self singleWindowOption];
    [self updateImageWithSelection];
}

- (void)setSingleWindowOption:(SingleWindowOption)option {
    windowOption = option;
    singleWindowListOptions = [self singleWindowOption];
	[self updateImageWithSelection];
}

- (void)setTightFit:(BOOL)fit {
	imageBounds = (fit ? CGRectNull : CGRectInfinite);
	[self updateImageWithSelection];
}

@end
