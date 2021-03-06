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

/* observed that this is sent when Mission Control is activated */
#define CGSConnectionNotifyEventMissionControl 1204

static void spaces_callback(int data1, int data2, int data3, void *ptr)
{
    MenuBarFilterAppDelegate *self = (__bridge MenuBarFilterAppDelegate *)(ptr);

    switch (data1) {
        case CGSConnectionNotifyEventMissionControl: // Mission Control
            //NSLog(@"space_callback: Mission Control launched");
            [self missionControlActivated];
            break;

        default:
            NSLog(@"space_callback! ptr=%p %d %d %d", ptr, data1, data2, data3);
			[self checkForFullScreen:NULL];
    }
}

- (void) enableMenuItem:(BOOL)enable {
    if (statusItem && !enable) {
        [[statusItem statusBar] removeStatusItem:statusItem];
    } else if (enable && !statusItem) {
        statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:22];
        [statusItem setMenu:statusMenu];
        [statusItem setHighlightMode:YES];
        [statusItem setImage:[NSImage imageNamed:@"NocturneMenu"]];
        [statusItem setAlternateImage:[NSImage imageNamed:@"NocturneMenuPressed"]];
    }
}

- (BOOL)filterWindowsBroken {
    NSString *osVersion = [[NSProcessInfo processInfo] operatingSystemVersionString];
    //Version 10.9 (Build 13A603)

    int osMajor = [[[osVersion componentsSeparatedByString:@" "][1] componentsSeparatedByString:@"."][0] intValue];
    int osMinor = [[[osVersion componentsSeparatedByString:@" "][1] componentsSeparatedByString:@"."][1] intValue];

    //GS- I assume future versions will also have this broken
    return (osMajor == 10 && osMinor >= 9) || osMajor > 10 /* Future compatibility */;
}

- (void)updateScreens {
	for (int i = 0; i < [NSScreen screens].count; i ++) {
		NSScreen *screen = [NSScreen screens][i];

		//GS- All of this is broken in Mavericks.
		if (![self filterWindowsBroken]) {
			NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
			NSDictionary *appDefaults = [NSMutableDictionary dictionary];

			// defaults write org.wezfurlong.MenuBarFilter enableMenu NO
			[appDefaults setValue:[NSNumber numberWithBool:YES] forKey:@"enableMenu"];

			// defaults write org.wezfurlong.MenuBarFilter useHue NO
			[appDefaults setValue:[NSNumber numberWithBool:YES] forKey:@"useHue"];

			[defs registerDefaults:appDefaults];
			[self enableMenuItem:[defs boolForKey:@"enableMenu"]];

			// create invert overlay
			MenuBarFilterWindow *invertWindow = [[MenuBarFilterWindow alloc] initWithScreen:screen];
			[invertWindow setFilter:@"CIColorInvert"];

			// create border overlay
			MenuBarFilterWindow *borderWindow = [[MenuBarFilterWindow alloc] initWithScreen:screen];
			[borderWindow setBackgroundColor: NSColor.blackColor];

			MenuBarFilterWindow *hueWindow = [[MenuBarFilterWindow alloc] initWithScreen:screen];
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
				 [NSDictionary dictionaryWithObject: [NSNumber numberWithFloat:0.0]
											 forKey: @"inputBrightness" ] ];
				[hueWindow setFilterValues:
				 [NSDictionary dictionaryWithObject: [NSNumber numberWithFloat:1.0]
											 forKey: @"inputContrast" ] ];
			}

			[hueWindows addObject:hueWindow];
			[invertWindows addObject:invertWindow];
			[borderWindows addObject:borderWindow];
		} else {
			MenuBarScreenshotWindow *screenshotWindow = [[MenuBarScreenshotWindow alloc] initWithScreen:screen];

			Controller *controller = [[Controller alloc] init];

			//GS- Default values
			[controller setWindowId:(CGSWindow)screenshotWindow.windowNumber];
			[controller setSingleWindowOption:kSingleWindowBelowOnly];
			[controller setTightFit:NO];

			screenshotWindow.controller = controller;
			screenshotWindow.view.controller = controller;


			[controllers addObject:controller];
			[screenshotWindows addObject:screenshotWindow];

			//GS- Have the controller output to the menu bar
			controller.outputView = screenshotWindow.view;

			// create border overlay
			MenuBarFilterWindow *borderWindow = [[MenuBarFilterWindow alloc] initWithScreen:screen];
			[borderWindow setBackgroundColor: NSColor.blackColor];

			[borderWindows addObject:borderWindow];
		}
	}
}

- (void) applicationDidFinishLaunching:(NSNotification *)notification {
	screenshotWindows = [@[] mutableCopy];
	hueWindows = [@[] mutableCopy];
	invertWindows = [@[] mutableCopy];
	borderWindows = [@[] mutableCopy];

	[self updateScreens];
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

    // When full-screen apps hide/show the menu bar
    NSNotificationCenter *dc = [NSDistributedNotificationCenter defaultCenter];
    [dc addObserver:self selector:@selector(fullScreenShowMenuBar:) name:@"com.apple.HIToolbox.frontMenuBarShown" object:nil];
    [dc addObserver:self selector:@selector(fullScreenHideMenuBar:) name:@"com.apple.HIToolbox.hideMenuBarShown" object:nil];

#if 0
    // I used this to spy on the various notifications
    [nc addObserver:self selector:@selector(GlobalNotificationObserver:) name:NULL object:nil];
    [dc addObserver:self selector:@selector(GlobalNotificationObserver:) name:NULL object:nil];
#endif

    // Use undocumented APIs to detect mission control being launched :-/
    // I observed this event code on 10.8. No idea if this is valid for other versions of OSX, YMMV.
    CGSRegisterConnectionNotifyProc(_CGSDefaultConnection(), spaces_callback, CGSConnectionNotifyEventMissionControl, (__bridge void *)(self));

#if 0
    // I used this to spy on the spaces events
    for (int i = 0; i < 2048; i++) {
        CGSRegisterConnectionNotifyProc(_CGSDefaultConnection(), spaces_callback, i, (__bridge void *)(self));
    }
#endif

    // show overlays
    [self reposition];
    [self showFilter];
}

- (void) GlobalNotificationObserver:(NSNotification*)notification {
    NSLog(@"GlobalNotify: %@", notification);
}

- (void) reposition {
    if (inMissionControl)
        return;
	if (!visible)
		return;

	CGFloat tallest = 0.0f;
	for (int i = 0; i < [NSScreen screens].count; i ++) {
		NSScreen *screen = [NSScreen screens][i];

		NSRect frame = [screen frame];
		if (frame.size.height - frame.origin.y > tallest)
			tallest = frame.size.height;
	}

	NSLog(@"Tallest screen is %f", tallest);

	for (int i = 0; i < [NSScreen screens].count; i ++) {
		NSScreen *screen = [NSScreen screens][i];

		NSRect frame = [screen frame];
		NSRect vframe = [screen visibleFrame];
		NSRect borderFrame = [screen visibleFrame];

		NSLog(@"frame o=%f h=%f, vframe o=%f h=%f", frame.origin.y, frame.size.height, vframe.origin.y, vframe.size.height);

		frame.origin.y = vframe.size.height + vframe.origin.y + 1;
		frame.size.height -= (vframe.size.height + vframe.origin.y);

		if ([screen frame].size.height < tallest) {
			//GS- If we're not the tallest screen, then we need to offset to counter it
			frame.size.height += (tallest - [screen frame].size.height);
//			frame.origin.y -= (tallest - [screen frame].size.height);
		}
		
		//GS- This doesn't automatically fix itself, and I hate the one pixel border that shows up
		if ([self filterWindowsBroken])
			frame.size.height --;

		borderFrame.origin.y = frame.origin.y - 1;
		borderFrame.size.height = 1;

		NSLog(@"Using %f %f", frame.origin.y, frame.size.height);

		borderFrame = [borderWindows[i] constrainFrameRect:borderFrame toScreen:screen];

		if ([self filterWindowsBroken]) {
			frame = [screenshotWindows[i] constrainFrameRect:frame toScreen:screen];
			[screenshotWindows[i] setFrame:frame display:NO];
			[borderWindows[i] setFrame:borderFrame display:NO];
		} else {
			frame = [invertWindows[i] constrainFrameRect:frame toScreen:screen];
			[hueWindows[i] setFrame:frame display:NO];
			[invertWindows[i] setFrame:frame display:NO];
			[borderWindows[i] setFrame:borderFrame display:NO];
		}
	}
}

- (void) observeValueForKeyPath:(NSString *)keyPath
                       ofObject:(id)object
                         change:(NSDictionary *)change
                        context:(void *)context {

    if ( [keyPath isEqualToString:@"currentSystemPresentationOptions"] ) {
        if ( [[change valueForKey:@"new"] boolValue] ) {
            [self hideFilter];
            //      NSLog(@"currentSystemPresentationOptions -> hiding");
        } else {
            [self showFilter];
            //      NSLog(@"currentSystemPresentationOptions -> making visible");
        }
        return;
    }

    [super observeValueForKeyPath:keyPath
                         ofObject:object
                           change:change
                          context:context];
}

// When mission control launches, if it is canceled using the swipe down gesture,
// we have no way to tell that it was canceled.  So we need to snoop on mouse
// events and re-show our filter.  My first attempt was using a quartz event tap
// but that receives input event while mission control is active.  So I switched
// to an NSEvent based monitor instead.
- (void) missionControlTapped {
    if (inMissionControl) {
        //    NSLog(@"tapped and in mission control; show again");
        inMissionControl = NO;
        if (eventMonitor) {
            [NSEvent removeMonitor:eventMonitor];
            eventMonitor = nil;
        }
        [self checkForFullScreen:nil];
    }
}

- (void) missionControlActivated {
    [self hideFilter];
    inMissionControl = TRUE;
    eventMonitor = [NSEvent
                    addGlobalMonitorForEventsMatchingMask:
                    NSMouseMovedMask|NSKeyDownMask|NSLeftMouseDownMask|NSLeftMouseUpMask|
                    NSFlagsChangedMask|NSTabletPointMask
                    handler:^void (NSEvent *evt) {
                        [self missionControlTapped];
                    }];
}

- (void) showFilter {
    if (!visible) {
		CGPoint offset = [controllers[0] screenOffset];
		if (isnan(offset.x)) {
			//Oops
			[self hideFilter];
			return;
		}
        if ([self filterWindowsBroken]) {
			for (int i = 0; i < [NSScreen screens].count; i ++) {
				[screenshotWindows[i] orderFrontRegardless];
				[borderWindows[i] orderFrontRegardless];
			}
        } else {
			for (int i = 0; i < [NSScreen screens].count; i ++) {
				[invertWindows[i] orderFrontRegardless];
				[hueWindows[i] orderFrontRegardless];
				[borderWindows[i] orderFrontRegardless];
			}
        }
        visible = YES;
		[self reposition];
    }
}

- (void) hideFilter {
    if (visible) {
        if ([self filterWindowsBroken]) {
			for (int i = 0; i < [NSScreen screens].count; i ++) {
				[screenshotWindows[i] orderOut:nil];
				[borderWindows[i] orderOut:nil];
			}
        } else {
			for (int i = 0; i < [NSScreen screens].count; i ++) {
				[hueWindows[i] orderOut:nil];
				[invertWindows[i] orderOut:nil];
				[borderWindows[i] orderOut:nil];
			}
        }
        visible = NO;
    }
}

- (void) fullScreenHideMenuBar:(NSNotification*)notification {
    [self hideFilter];
}

- (void) fullScreenShowMenuBar:(NSNotification*)notification {
    [self showFilter];
}

- (void) checkForFullScreen:(NSNotification*)notification {
    if (inMissionControl)
        return;
    
    // Look at the windows on this screen; if we can't find the menubar backstop,
    // we know we're in fullscreen mode

    CFArrayRef windows = CGWindowListCopyWindowInfo( kCGWindowListOptionOnScreenOnly, kCGNullWindowID );
    CFIndex i, n;

    bool show = false;

    for (i = 0, n = CFArrayGetCount(windows); i < n; i++) {
        CFDictionaryRef windict = CFArrayGetValueAtIndex(windows, i);
        CFStringRef name = CFDictionaryGetValue(windict, kCGWindowOwnerName);

        if ([window_server compare:(__bridge NSString*)name] == 0) {
            name = CFDictionaryGetValue(windict, kCGWindowName);
            if ([backstop_menubar compare:(__bridge NSString*)name] == 0) {
                show = true;
            }

        }
        if (show) break;
    }

    CFRelease(windows);

    if ( show && !visible ) {
        [self showFilter];
        //    NSLog(@"checkForFullScreen -> making visible");
        
    }
    else if ( !show && visible ) {
        [self hideFilter];
        //    NSLog(@"checkForFullScreen -> hiding");
    } else if (show) {
        // Force them to the front again
        [self showFilter];
        //     NSLog(@"checkForFullScreen show + visible");
    }
}

@end
