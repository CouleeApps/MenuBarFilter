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

CGSConnection connection;

@implementation MenuBarFilterWindow

+ (void)initialize {
    connection = _CGSDefaultConnection();
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
        [self setOpaque: NO];
        [self setBackgroundColor:[NSColor colorWithDeviceWhite:0.0 alpha:0.0]];

        [self setLevel:kCGStatusWindowLevel+1];

        [self setCollectionBehavior:
            NSWindowCollectionBehaviorCanJoinAllSpaces |
            NSWindowCollectionBehaviorStationary];

        window = (CGSWindow)[self windowNumber];
    }
    return self;
}

- (void)setFilter:(NSString *)filterName{
    if ( filter ){
        CGSRemoveWindowFilter( connection, window, filter );
        CGSReleaseCIFilter( connection, filter );
    }
    if ( filterName ) {
        CGError error = CGSNewCIFilterByName( connection, (__bridge CFStringRef)filterName, &filter );
        if ( error == noErr ) {
            CGSAddWindowFilter( connection, window, filter, 0x00003001 );
        }
    }
}

-(void)setFilterValues:(NSDictionary *)filterValues{
    if ( !filter ) {
        return;
    }
    CGSSetCIFilterValuesFromDictionary( connection, filter, (__bridge CFDictionaryRef)filterValues );
}

@end
