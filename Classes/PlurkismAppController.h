//Copyright 2010 Yi-Ta Chiang
//
//Licensed under the Apache License, Version 2.0 (the "License");
//you may not use this file except in compliance with the License.
//You may obtain a copy of the License at 
//
//http://www.apache.org/licenses/LICENSE-2.0

#import <Cocoa/Cocoa.h>
#import <Security/Security.h>
#import <CoreServices/CoreServices.h>
#import "PlurkController.h"
#import "../Common.h"

@class PlurkController;
@interface PlurkismAppController : NSObject <NSApplicationDelegate> {
	
    BOOL debug;
    PlurkController* plurk;
}

@property(readonly) BOOL debug;
- (void) DebugNotified:(NSNotification *)notification;
- (void) StopNotified: (NSNotification *)notification;
- (void) LoginDataNotified:(NSNotification *)notification;
@end
