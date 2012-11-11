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

// Undocumented spaces related APIs
typedef int CGSConnection;
extern CGSConnection _CGSDefaultConnection(void);
typedef void (*CGConnectionNotifyProc)(int data1, int data2, int data3, void* userParameter);
extern CGError CGSRegisterConnectionNotifyProc(const CGSConnection cid,
                                               CGConnectionNotifyProc function, int event, void* userParameter);

/* observed that this is sent when Mission Control is activated */
#define CGSConnectionNotifyEventMissionControl 1204

static void spaces_callback(int data1, int data2, int data3, void *ptr)
{
    MenuBarFilterAppDelegate *self = ptr;

    switch (data1) {
        case CGSConnectionNotifyEventMissionControl: // Mission Control
            //NSLog(@"space_callback: Mission Control launched");
            [self missionControlActivated];
            break;

        default:
            NSLog(@"space_callback! ptr=%p %d %d %d", ptr, data1, data2, data3);
    }
}

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

#if USE_EVENT_TAP
static CGEventRef tap_callback (
                                CGEventTapProxy proxy,
                                CGEventType type,
                                CGEventRef event,
                                void *refcon
                                )
{
    MenuBarFilterAppDelegate *self = refcon;
    [self missionControlTapped];
//    NSLog(@"MC tap %@", event);
    return NULL;
}
#endif

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

    NSNotificationCenter *nc = [[NSWorkspace sharedWorkspace] notificationCenter];

    // observe space/workspace changes, including Lion full-screen mode changes
    [nc addObserver:self
           selector:@selector(checkForFullScreen:)
                                                 name:@"NSWorkspaceActiveSpaceDidChangeNotification"
                                               object:nil];


    // add observer for full-screen (not Lion style)
    [[NSApplication sharedApplication] addObserver:self
                                        forKeyPath:@"currentSystemPresentationOptions"
                                           options:( NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew )
                                           context:NULL];

    // When mission control launches, if it is canceled using the swipe down gesture,
    // we have no way to tell that it was canceled.  So we need to snoop on mouse
    // events and re-show our filter.  My first attempt was using a quartz event tap
    // but that receives input event while mission control is active.  So I switched
    // to an NSEvent based monitor instead.  I've kept the tap code here just in case
    // I need to bring it back again.
#if USE_EVENT_TAP
    eventTap = CGEventTapCreate(kCGAnnotatedSessionEventTap, kCGHeadInsertEventTap,
                                kCGEventTapOptionListenOnly,
                                CGEventMaskBit(kCGEventMouseMoved) |
                                CGEventMaskBit(kCGEventKeyUp) | CGEventMaskBit(kCGEventKeyDown),
                                tap_callback,
                                self);

    CFRunLoopAddSource(
                       [[NSRunLoop currentRunLoop] getCFRunLoop],
                       CFMachPortCreateRunLoopSource(NULL, eventTap, 0),
                       kCFRunLoopCommonModes);
    CGEventTapEnable(eventTap, NO);
#endif

    // When full-screen apps hide/show the menu bar
    NSNotificationCenter *dc = [NSDistributedNotificationCenter defaultCenter];
    [dc addObserver:self selector:@selector(fullScreenShowMenuBar:) name:@"com.apple.HIToolbox.frontMenuBarShown" object:nil];
    [dc addObserver:self selector:@selector(fullScreenHideMenuBar:) name:@"com.apple.HIToolbox.hideMenuBarShown" object:nil];

#if 0
    // I used this to spy on the various notifications
    [nc addObserver:self selector:@selector(GlobalNotificationObserver:) name:NULL object:nil];

    // @"com.apple.HIToolbox.frontMenuBarShown"
    // @"com.apple.HIToolbox.hideMenuBarShown"
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(GlobalNotificationObserver:) name:NULL object:nil];
#endif

    // Use undocumented APIs to detect mission control being launched :-/
    // I observed this event code on 10.8. No idea if this is valid for other versions of OSX, YMMV.
    CGSRegisterConnectionNotifyProc(_CGSDefaultConnection(), spaces_callback, CGSConnectionNotifyEventMissionControl, self);

#if 0
    // I used this to spy on the spaces events
    for (int i = 0; i < 2048; i++) {
        CGSRegisterConnectionNotifyProc(_CGSDefaultConnection(), spaces_callback, i, self);
    }
#endif

    // show overlays
    [self reposition];
    [invertWindow orderFront:nil];
    [hueWindow orderFront:nil];
    visible = YES;
}

- (void) GlobalNotificationObserver:(NSNotification*)notification {
    NSLog(@"GlobalNotify: %@", notification);
}

- (void) reposition {
    NSRect frame = [[NSScreen mainScreen] frame];
    NSRect vframe = [[NSScreen mainScreen] visibleFrame];

    NSLog(@"frame o=%f h=%f, vframe o=%f h=%f", frame.origin.y, frame.size.height, vframe.origin.y, vframe.size.height);

    frame.origin.y = vframe.size.height + vframe.origin.y + 1;
    frame.size.height -= (vframe.size.height + vframe.origin.y);

    NSLog(@"Using %f %f", frame.origin.y, frame.size.height);

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
      //      NSLog(@"currentSystemPresentationOptions -> hiding");
        } else {
            // show
            [hueWindow orderFront:nil];
            [invertWindow orderFront:nil];
            visible = YES;
      //      NSLog(@"currentSystemPresentationOptions -> making visible");
        }
        return;
    }

    [super observeValueForKeyPath:keyPath
                         ofObject:object
                           change:change
                          context:context];
}

- (void) missionControlTapped {
    if (inMissionControl) {
    //    NSLog(@"tapped and in mission control; show again");
        inMissionControl = NO;
#if USE_EVENT_TAP
        CGEventTapEnable(eventTap, NO);
#endif
        if (eventMonitor) {
            [NSEvent removeMonitor:eventMonitor];
            eventMonitor = nil;
        }
        [self checkForFullScreen:nil];
    }
}

- (void) missionControlActivated {
    if (visible) {
        [hueWindow orderOut:nil];
        [invertWindow orderOut:nil];
        visible = NO;
    //    NSLog(@"missionControlActivated -> hiding");
    }

    inMissionControl = TRUE;
#if USE_EVENT_TAP
    CGEventTapEnable(eventTap, YES);
#endif

    eventMonitor = [NSEvent
                    addGlobalMonitorForEventsMatchingMask:
                        NSMouseMovedMask|NSKeyDownMask|NSLeftMouseDownMask|NSLeftMouseUpMask|
                        NSFlagsChangedMask|NSTabletPointMask
                    handler:^void (NSEvent *evt) {
        [self missionControlTapped];
    }];
}

- (void) fullScreenHideMenuBar:(NSNotification*)notification {
    if (visible) {
        [hueWindow orderOut:nil];
        [invertWindow orderOut:nil];
        visible = NO;
    //    NSLog(@"fullScreenHideMenuBar -> hiding");
    }
}

- (void) fullScreenShowMenuBar:(NSNotification*)notification {
    if (!visible) {
        [hueWindow orderFront:nil];
        [invertWindow orderFront:nil];
        visible = YES;
    //    NSLog(@"fullScreenShowMenuBar -> making visible");
    }
}

- (void) checkForFullScreen:(NSNotification*)notification {
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
    //    NSLog(@"checkForFullScreen -> making visible");
    }
    else if ( !show && visible ) {
        [hueWindow orderOut:nil];
        [invertWindow orderOut:nil];
        visible = NO;
    //    NSLog(@"checkForFullScreen -> hiding");
    } else if (show) {
        // Force them to the front again
        [invertWindow orderFrontRegardless];
        [hueWindow orderFrontRegardless];
   //     NSLog(@"checkForFullScreen show + visible");
    }


}

@end
