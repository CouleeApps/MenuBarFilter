//
//  MenuBarFilterAppDelegate.m
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

#import "MenuBarFilterAppDelegate.h"

@implementation MenuBarFilterAppDelegate

NSString *window_server = @"Window Server";
NSString *backstop_menubar = @"Backstop Menubar";

- (void) enableMenuItem:(BOOL)enable {
    if (statusItem && !enable) {
        [[statusItem statusBar] removeStatusItem:statusItem];
        [statusItem release];
    } else if (enable && !statusItem) {
        statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:22];
        [statusItem setMenu:statusMenu];
        [statusItem setHighlightMode:YES];
        [statusItem setImage:[NSImage imageNamed:@"NocturneMenu"]];
        [statusItem setAlternateImage:[NSImage imageNamed:@"NocturneMenuPressed"]];
        [statusItem retain];
    }    
}

- (void) applicationDidFinishLaunching:(NSNotification *)notification {

    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    
    NSDictionary *appDefaults = [NSMutableDictionary dictionary];
    
    // defaults write org.wezfurlong.MenuBarFilter enableMenu NO
    [appDefaults setValue:[NSNumber numberWithBool:YES] forKey:@"enableMenu"];
    
    // defaults write org.wezfurlong.MenuBarFilter useHue NO
    [appDefaults setValue:[NSNumber numberWithBool:YES] forKey:@"useHue"];
                                 
    [defs registerDefaults:appDefaults];
    
    [self enableMenuItem:[defs boolForKey:@"enableMenu"]];
    
    // create invert overlay
    invertWindow = [[MenuBarFilterWindow alloc] init];
    [invertWindow setFilter:@"CIColorInvert"];
    
    hueWindow = [[MenuBarFilterWindow alloc] init];
    if ([defs boolForKey:@"useHue"]) {
        // create hue overlay
        [hueWindow setFilter:@"CIHueAdjust"];
        [hueWindow setFilterValues:
             [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithFloat:M_PI], 
              @"inputAngle", nil]];  
    } else {
        // de-saturation filter
        [hueWindow setFilter:@"CIColorControls"];
        [hueWindow setFilterValues:
            [NSDictionary dictionaryWithObject: [NSNumber numberWithFloat:0.0] 
            forKey: @"inputSaturation" ] ];
        [hueWindow setFilterValues:
            [NSDictionary dictionaryWithObject: [NSNumber numberWithFloat:0.10] 
            forKey: @"inputBrightness" ] ];
        [hueWindow setFilterValues:
            [NSDictionary dictionaryWithObject: [NSNumber numberWithFloat:0.8] 
            forKey: @"inputContrast" ] ];        
    }
    
    // add observer for screen changes
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(reposition) 
                                                 name:NSApplicationDidChangeScreenParametersNotification 
                                               object:nil];
    
    // add observer for full-screen
    [[NSApplication sharedApplication] addObserver:self
                                        forKeyPath:@"currentSystemPresentationOptions"
                                           options:( NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew )
                                           context:NULL];
    
    if ( [invertWindow respondsToSelector:@selector(toggleFullScreen:)] ) {                                                    
        // lion hack
        NSTimer * timer = [NSTimer timerWithTimeInterval:1
                                                  target:self 
                                                selector:@selector(checkForFullscreen) 
                                                userInfo:nil 
                                                 repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:timer 
                                  forMode:NSDefaultRunLoopMode];
        
        NSTimer * timer2 = [NSTimer timerWithTimeInterval:.1
                                                  target:self 
                                                selector:@selector(checkForAppSwitch) 
                                                userInfo:nil 
                                                 repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:timer2
                                  forMode:NSDefaultRunLoopMode];
    }
    
    // show overlays
    [self reposition];
    [invertWindow orderFront:nil];
    [hueWindow orderFront:nil]; 
    visible = YES;
}

- (void) reposition {
    CGFloat menuHeight = 21;
    
    NSRect frame = [[NSScreen mainScreen] frame];
    frame.origin.y = NSHeight(frame) - menuHeight;
    frame.size.height = menuHeight;
    
    [hueWindow setFrame:frame display:NO];
    [invertWindow setFrame:frame display:NO];
}

- (void) observeValueForKeyPath:(NSString *)keyPath
                       ofObject:(id)object
                         change:(NSDictionary *)change
                        context:(void *)context {
    
    if ( [keyPath isEqualToString:@"currentSystemPresentationOptions"] ) {
        if ( [[change valueForKey:@"new"] boolValue] ) {
            // hide
            [hueWindow orderOut:nil];
            [invertWindow orderOut:nil];
            visible = NO;
        } else {
            // show
            [hueWindow orderFront:nil];
            [invertWindow orderFront:nil];
            visible = YES;
        }
        return;
    }

    [super observeValueForKeyPath:keyPath
                         ofObject:object
                           change:change
                          context:context];
}

- (void) checkForFullscreen {
    bool show = true;
    

        // Look at the windows on this screen; if we can't find the menubar backstop,
        // we know we're in fullscreen mode
        
        CFArrayRef windows = CGWindowListCopyWindowInfo( kCGWindowListOptionOnScreenOnly, kCGNullWindowID );
        CFIndex i, n;
        
        show = false;
        
        for (i = 0, n = CFArrayGetCount(windows); i < n; i++) {
            CFDictionaryRef windict = CFArrayGetValueAtIndex(windows, i);
            CFStringRef name = CFDictionaryGetValue(windict, kCGWindowOwnerName);
            
            if ([window_server compare:(NSString*)name] == 0) {                
                name = CFDictionaryGetValue(windict, kCGWindowName);
                if ([backstop_menubar compare:(NSString*)name] == 0) {
                    show = true;                    
                }
            
            }
            if (show) break;
        }
    
    CFRelease(windows);

    if ( show && !visible ) {
        [hueWindow orderFront:nil];
        [invertWindow orderFront:nil];
        visible = YES;
    }
    else if ( !show && visible ) {
        [hueWindow orderOut:nil];
        [invertWindow orderOut:nil];
        visible = NO;
    }


}

- (void) checkForAppSwitch {
    static int previousPid = -1;
    int activePid = [[[[NSWorkspace sharedWorkspace] activeApplication]
                      valueForKey:@"NSApplicationProcessIdentifier"] intValue];
    if ( previousPid != activePid ) {
        [self checkForFullscreen];
        previousPid = activePid;
    }
}

@end
