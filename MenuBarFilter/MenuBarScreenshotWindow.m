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

        self.view = [[MenuBarScreenshotView alloc] initWithFrame:[[NSScreen mainScreen] frame]];
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
			if ([[mouseEvent window] convertBaseToScreen:[mouseEvent locationInWindow]].y < self.frame.size.height)
				[self performSelector:@selector(update) onThread:thread withObject:nil waitUntilDone:NO];
        }];
    }
    return self;
}

- (void)setFrame:(NSRect)frameRect display:(BOOL)flag {
    [super setFrame:frameRect display:flag];
    [self.view setFrame:CGRectOffset(frameRect, 0, -frameRect.origin.y)];
}

- (void)updateLoop {
    while (self) {
        if (self.isVisible)
            @autoreleasepool {
                @synchronized (self) {
                    [self update];
                }
            }
        usleep(200000);
    }
}

- (void)update {
    [controller update];
}

- (void)dealloc {
    [NSEvent removeMonitor:eventHandler];
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
    if (self.image) {
        CGImageRef image = [self invertedImage];
        CGPoint offset = [self.controller screenOffset];
        dirtyRect = CGRectApplyAffineTransform(dirtyRect, CGAffineTransformMakeTranslation(-offset.x, offset.y));
        CGContextDrawImage(ref, dirtyRect, image);
    }
    [super drawRect:dirtyRect];
}

//http://stackoverflow.com/a/6672628/214063
- (CGImageRef)invertedImage {
    CGImageRef image = self.image;
    int width = (int)CGImageGetWidth(image);
    int height = (int)CGImageGetHeight(image);

    // Create a suitable RGB+alpha bitmap context in BGRA colour space
    CGColorSpaceRef colourSpace = CGColorSpaceCreateDeviceRGB();
    unsigned char *memoryPool = (unsigned char *)calloc(width*height*4, 1);
    CGContextRef context = CGBitmapContextCreate(memoryPool, width, height, 8, width * 4, colourSpace, kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(colourSpace);

    // draw the current image to the newly created context
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);

    // run through every pixel, a scan line at a time...
    for (int y = 0; y < height; y ++) {
        // get a pointer to the start of this scan line
        unsigned char *linePointer = &memoryPool[y * width * 4];

        // step through the pixels one by one...
        for (int x = 0; x < width; x ++) {
            // get RGB values. We're dealing with premultiplied alpha
            // here, so we need to divide by the alpha channel (if it
            // isn't zero, of course) to get uninflected RGB. We
            // multiply by 255 to keep precision while still using
            // integers
            if (linePointer[3]) {

				//Suuuper lazy define makes my life easier
#define r linePointer[0]
#define g linePointer[1]
#define b linePointer[2]
#define c linePointer

				// perform the colour inversion
				r = 255 - r;
				g = 255 - g;
				b = 255 - b;

				//Super cool actually investigating this rather than just using a hue/saturation calculation
				//Much faster this way as well
				//
				//39A33B -> A339A1
				// (57, 163, 59) -> (163, 57, 161); 161 = (163 -  59) + 57
				//CCA539 -> 3960CC
				//(204, 165, 57) ->  (57, 96, 204);  96 = (204 - 165) + 57

				//So what it looks like is:
				//<r, g, b> -> <r1, g1, b1>
				//max   = max(r, g, b)
				//min   = min(r, g, b)
				//other = whichever isn't above
				//
				//<max>1 = min
				//<min>1 = max
				//<other> = (max - other) + min

				//Which color index is the largest or smallest?
				int max   = r > g ? (r > b ? 0 : 2) : (g > b ? 1 : 2);
				int min   = r < g ? (r < b ? 0 : 2) : (g < b ? 1 : 2);

				//Which one did we not get?
				int other = (max + min == 1 ? 2 : (max + min == 3 ? 0 : 1));

				//Calculate c[other] (probably a cleaner way to do this)
				c[other] = (c[max] - c[other]) + c[min];

				//Save it because we can't just forget the value
				int cmax = c[max];

				//Swap the two of them
				c[max] = c[min];
				c[min] = cmax;
			}
            linePointer += 4;
        }
    }

    free(memoryPool);

    // get a CG image from the context, wrap that into a
    // UIImage
    CGImageRef cgImage = CGBitmapContextCreateImage(context);

	CFAutorelease(cgImage);
	CFRelease(context);

    return cgImage;
}

@end