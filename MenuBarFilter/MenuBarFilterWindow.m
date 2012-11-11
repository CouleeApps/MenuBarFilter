//
//  MenuBarFilterWindow.m
//  MenuBarFilter
//
//  Created by eece on 24/02/2011.
//  Copyright 2011 eece. All rights reserved.
//  Copyright 2012 Wez Furlong
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


#import "MenuBarFilterWindow.h"

typedef long CGSConnection;
typedef long CGSWindow;


extern CGSConnection _CGSDefaultConnection( void );
extern void CGSRemoveWindowFilter( CGSConnection cid, CGSWindow wid, void * fid );
extern void CGSReleaseCIFilter( CGSConnection cid, void * fid );
extern OSStatus CGSNewCIFilterByName( CGSConnection cid, CFStringRef filterName, void * fid );
extern OSStatus CGSAddWindowFilter( CGSConnection cid, CGSWindow wid, void * fid, int value );
extern void CGSSetCIFilterValuesFromDictionary( CGSConnection cid, void * fid, CFDictionaryRef filterValues );


CGSConnection cid;

@implementation MenuBarFilterWindow

+ (void)initialize {
    cid = _CGSDefaultConnection();
}

- (id) init {
    self = [self initWithContentRect:[[NSScreen mainScreen] frame]
                           styleMask:NSBorderlessWindowMask
                             backing:NSBackingStoreBuffered
                               defer:NO];
    if ( self != nil ) {
        [self setHidesOnDeactivate:NO];
        [self setCanHide:NO];
        [self setIgnoresMouseEvents:YES];
        [self setLevel:CGWindowLevelForKey(kCGCursorWindowLevelKey)];
        [self setOpaque: NO];
        [self setBackgroundColor:[NSColor colorWithDeviceWhite:0.0 alpha:0.0]];

        [self setLevel:kCGMaximumWindowLevel];

        [self setCollectionBehavior:
            NSWindowCollectionBehaviorCanJoinAllSpaces |
            NSWindowCollectionBehaviorStationary];

        wid = [self windowNumber];
    }
    return self;
}

- (void)setFilter:(NSString *)filterName{
    if ( fid ){
        CGSRemoveWindowFilter( cid, wid, fid );
        CGSReleaseCIFilter( cid, fid );
    }
    if ( filterName ) {
        CGError error = CGSNewCIFilterByName( cid, (CFStringRef)filterName, &fid );
        if ( error == noErr ) {
            CGSAddWindowFilter( cid, wid, fid, 0x00003001 );
        }
    }
}

-(void)setFilterValues:(NSDictionary *)filterValues{
    if ( !fid ) {
        return;
    }
    CGSSetCIFilterValuesFromDictionary( cid, fid, (CFDictionaryRef)filterValues );
}

@end
