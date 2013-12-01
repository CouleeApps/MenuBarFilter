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

@implementation MenuBarScreenshotWindow
@synthesize imageView;

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
       NSWindowCollectionBehaviorStationary];
      
      window = (CGSWindow)[self windowNumber];
      
      imageView = [[NSImageView alloc] initWithFrame:self.frame];
      [self.contentView addSubview:imageView];
      [imageView setAutoresizingMask:NSMinXEdge | NSMaxXEdge | NSMinYEdge | NSMaxYEdge];
   }
   return self;
}

- (void)setFrame:(NSRect)frameRect display:(BOOL)flag {
   [super setFrame:frameRect display:flag];
   
   //Full-screen
   [imageView setFrame:NSMakeRect(0, 0, frameRect.size.width, frameRect.size.height)];
}

@end
