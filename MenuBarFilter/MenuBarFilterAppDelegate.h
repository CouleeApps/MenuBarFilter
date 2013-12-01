//
//  MenuBarFilterAppDelegate.h
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

#include "MenuBarFilterWindow.h"
#include "MenuBarScreenshotWindow.h"
#include "Controller.h"

@interface MenuBarFilterAppDelegate : NSObject <NSApplicationDelegate> {

    IBOutlet NSMenu *statusMenu;
    IBOutlet Controller *controller;

@private
    MenuBarFilterWindow * invertWindow;
    MenuBarFilterWindow * hueWindow;
	 MenuBarFilterWindow * borderWindow;
    MenuBarScreenshotWindow * screenshotWindow;
    BOOL visible;
    BOOL inMissionControl;
    id eventMonitor;
    NSStatusItem *statusItem;
}

- (void) reposition;
- (void) missionControlActivated;
- (void) missionControlTapped;
- (void) checkForFullScreen:(NSNotification*)notification;
- (void) fullScreenShowMenuBar:(NSNotification*)notification;
- (void) fullScreenHideMenuBar:(NSNotification*)notification;

- (void) showFilter;
- (void) hideFilter;


@end
