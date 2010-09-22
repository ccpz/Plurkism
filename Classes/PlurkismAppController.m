//Copyright 2010 Yi-Ta Chiang
//
//Licensed under the Apache License, Version 2.0 (the "License");
//you may not use this file except in compliance with the License.
//You may obtain a copy of the License at 
//
//http://www.apache.org/licenses/LICENSE-2.0

#import "PlurkismAppController.h"
#import "PlurkismGrowlDelegate.h"
#import "ASIHTTPRequest/ASIHTTPRequest.h"

@implementation PlurkismAppController
@synthesize debug;

#pragma mark object lifecycle
- (id) init {
	if(self = [super init]) {
		[self DebugNotified:nil];        
        plurk = [[PlurkController alloc] init];
        
	}
	return self;
}

- (void) dealloc {
	[self applicationWillTerminate:nil];
	[super dealloc];
}
#pragma mark -

#pragma mark Notification 
- (void) StopNotified: (NSNotification *)notification{
	[NSApp terminate:self];
}

- (void) LoginDataNotified:(NSNotification *)notification {
	[plurk LoginPlurk];
}

- (void) DebugNotified:(NSNotification *)notification {
	CFPreferencesAppSynchronize(CFSTR(APP_NAME));
	CFPropertyListRef value = CFPreferencesCopyAppValue(KEY_DEBUG, CFSTR(APP_NAME));
	if(value && CFGetTypeID(value) == CFBooleanGetTypeID()) {
		debug = CFBooleanGetValue(value);
	}else {
		debug = NO;
	}
	if(value)
		CFRelease(value);
}
#pragma mark -

#pragma mark NSApplicationDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	
	// Insert code here to initialize your application 
	
	[[NSDistributedNotificationCenter defaultCenter] postNotificationName:NOTIFY_STOP object:nil];
	
	PlurkismGrowlDelegate* delegate = [[PlurkismGrowlDelegate alloc] init];
	
	if([GrowlApplicationBridge isGrowlInstalled]==NO) {
		NSRunAlertPanel(@"Plurkism Error", @"Growl is not installed", @"Exit", NULL, NULL);
		[NSApp terminate:self];
	}
	
	[GrowlApplicationBridge setGrowlDelegate:delegate];
	[delegate release];
	
	[[NSDistributedNotificationCenter defaultCenter] addObserver:self
														selector:@selector(LoginDataNotified:)
															name:NOTIFY_LOGIN
														  object:nil
											  suspensionBehavior:NSNotificationSuspensionBehaviorHold];
	[[NSDistributedNotificationCenter defaultCenter] addObserver:self
														selector:@selector(DebugNotified:)
															name:NOTIFY_DEBUG
														  object:nil
											  suspensionBehavior:NSNotificationSuspensionBehaviorHold];
	[[NSDistributedNotificationCenter defaultCenter] addObserver:self
														selector:@selector(StopNotified:)
															name:NOTIFY_STOP
														  object:nil
											  suspensionBehavior:NSNotificationSuspensionBehaviorDrop];
	
	[plurk LoginPlurk];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    [plurk release];
	[[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
}
#pragma mark -
@end
