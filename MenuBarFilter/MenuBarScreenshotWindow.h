//
//  MenuBarScreenshotWindow.h
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


#import <Cocoa/Cocoa.h>
#import "CGSPrivate.h"
#import "Controller.h"

@class MenuBarScreenshotView;
@interface MenuBarScreenshotWindow : NSWindow {
@private
	CGSWindow window;

    Controller *controller;
    id eventHandler;

}

- (id)initWithScreen:(NSScreen *)screen;

@property (nonatomic, strong) MenuBarScreenshotView *view;
@property (nonatomic, strong) NSView *filterView;
@property (nonatomic, strong) Controller *controller;

@end

@interface MenuBarScreenshotView : NSView {
	CGFloat xOffset;
}

- (id)initWithScreen:(NSScreen *)screen;

@property (nonatomic, strong) NSScreen *screen;
@property (nonatomic, strong) Controller *controller;
@property (nonatomic) CGImageRef image;
@end