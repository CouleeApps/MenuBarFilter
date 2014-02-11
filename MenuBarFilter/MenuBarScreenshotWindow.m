//
//  MenuBarScreenshotWindow.m
//  MenuBarFilter
//
//  Created by Glenn Smith on 12/1/13.
//  Copyright 2013 Glenn Smith
//
/*
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */


#import "MenuBarScreenshotWindow.h"
#import <QuartzCore/QuartzCore.h>

@implementation MenuBarScreenshotWindow
@synthesize controller;

- (id) init {
    self = [self initWithContentRect:[[NSScreen mainScreen] frame]
                           styleMask:NSBorderlessWindowMask
                             backing:NSBackingStoreBuffered
                               defer:NO];
    if ( self != nil ) {
        [self setHidesOnDeactivate:NO];
        [self setCanHide:NO];
        [self setIgnoresMouseEvents:YES];
        [self setOpaque: NO];
        [self setBackgroundColor:[NSColor colorWithDeviceWhite:1.0 alpha:0.0]];

        //GS- +2 so it can capture Cloud as well
        [self setLevel:NSMainMenuWindowLevel + 2];

        [self setCollectionBehavior:
         NSWindowCollectionBehaviorCanJoinAllSpaces |
         NSWindowCollectionBehaviorStationary |
         NSWindowCollectionBehaviorIgnoresCycle];

        window = (CGSWindow)[self windowNumber];

        self.view = [[MenuBarScreenshotView alloc] initWithFrame:NSMakeRect(0, 0, 1440, 21)];
        [self setContentView:self.view];

//        //Load the filters
//        CIFilter *invertFilter = [CIFilter filterWithName:@"CIColorInvert"];
//        CIFilter *colorFilter = [CIFilter filterWithName:@"CIHueAdjust"];
//        [colorFilter setValue:@M_PI forKey:@"inputAngle"];
//        CIFilter *gammaFilter = [CIFilter filterWithName:@"CIGammaAdjust"];
//        [gammaFilter setValue:@3 forKey:@"inputPower"];
//
//        CALayer *layer = [CALayer layer];
//
//        [self.view setWantsLayer:YES];
//        [self.view setLayer:layer];
//        [self.view setLayerUsesCoreImageFilters:YES];
//        [self.view.layer setFilters:@[invertFilter, colorFilter, gammaFilter]];
//        [self.view.layer setNeedsDisplay];

        NSThread *thread = [[NSThread alloc] initWithTarget:self selector:@selector(updateLoop) object:nil];
        [thread start];

        eventHandler = [NSEvent addGlobalMonitorForEventsMatchingMask:NSLeftMouseDownMask | NSRightMouseDownMask | NSLeftMouseUpMask | NSRightMouseUpMask handler:^(NSEvent * mouseEvent) {
            [self performSelector:@selector(update) onThread:thread withObject:nil waitUntilDone:NO];
        }];
    }
    return self;
}

- (void)updateLoop {
    while (self) {
        if (self.isVisible)
            @autoreleasepool {
                @synchronized (self) {
                    [self update];
                }
            }
        usleep(100000);
    }
}

- (void)update {
    [controller update];
}

- (void)dealloc {
    [NSEvent removeMonitor:eventHandler];
}

- (void)setFrame:(NSRect)frameRect display:(BOOL)flag {
    [super setFrame:frameRect display:flag];
}

@end


@implementation MenuBarScreenshotView

- (id)init {
    self = [super init];
    self.image = nil;
    return self;
}

- (void)setImage:(CGImageRef)image {
    @synchronized (self) {
        if (_image)
            CFRelease(_image);
        _image = CGImageCreateWithImageInRect(image, CGRectApplyAffineTransform(self.frame, CGAffineTransformMakeScale(CGImageGetWidth(image) / self.frame.size.width, CGImageGetWidth(image) / self.frame.size.width)));
    }
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect {
    CGContextRef ref = [NSGraphicsContext currentContext].graphicsPort;
    if (self.image)
        CGContextDrawImage(ref, dirtyRect, self.image);
    [super drawRect:dirtyRect];
}

@end