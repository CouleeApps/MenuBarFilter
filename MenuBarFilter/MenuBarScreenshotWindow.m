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
        usleep(100000);
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
        CGContextDrawImage(ref, dirtyRect, image);
        CFRelease(image);
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
            int _r, _g, _b;
            if (linePointer[3]) {
                _r = linePointer[0];
                _g = linePointer[1];
                _b = linePointer[2];
            } else
                _r = _g = _b = 0;

            // perform the colour inversion
            _r = 255 - _r;
            _g = 255 - _g;
            _b = 255 - _b;

            float r = _r / 255.0f, g = _g / 255.0f, b = _b / 255.0f;

            if (r != g || r != b || g != b) {
                float cMax = MAX(MAX(r, g), b);
                float cMin = MIN(MIN(r, g), b);
                float delta = cMax - cMin;

                float h = 0, s = 0, l = (cMax + cMin) / 2.f;

                if (cMax == r) h = 60.f * _mod(((g-b)/delta), 6.f);
                if (cMax == g) h = 60.f *      ((b-r)/delta + 2.f);
                if (cMax == b) h = 60.f *      ((r-g)/delta + 4.f);
                
                if (delta == 0) s = 0.f;
                else s = delta/(1 - _abs((2.f * l) - 1.f));

                h += 180.f;
                h = _mod(h, 360.f);

                float c =     (1.f - _abs((2.f * l) - 1.f)) * s;
                float x = c * (1.f - _abs(_mod(h / 60.f, 2.f) - 1.f));
                float m = l - (c / 2.f);

                if      (h < 60)  r = c + m, g = x + m, b = m;
                else if (h < 120) r = x + m, g = c + m, b = m;
                else if (h < 180) r = m,     g = c + m, b = x + m;
                else if (h < 240) r = m,     g = x + m, b = c + m;
                else if (h < 300) r = x + m, g = m,     b = c + m;
                else if (h < 360) r = c + m, g = m,     b = x + m;
                else              r = m,     g = m,     b = m;
            }

            _r = (int)(r * 255), _g = (int)(g * 255), _b = (int)(b * 255);

            // multiply by alpha again, divide by 255 to undo the
            // scaling before, store the new values and advance
            // the pointer we're reading pixel data from
            linePointer[0] = _r;
            linePointer[1] = _g;
            linePointer[2] = _b;
            linePointer += 4;
        }
    }

    free(memoryPool);

    // get a CG image from the context, wrap that into a
    // UIImage
    CGImageRef cgImage = CGBitmapContextCreateImage(context);

    return cgImage;
}

float _mod(float f, float m) {
    if (f > INT_MAX) return fmodf(f, m);
    return ((f / m) - (float)(int)(f / m)) * m;
}

float _abs(float f) {
    return f * (f >= 0 ? 1 : -1);
}

@end