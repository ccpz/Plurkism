//Copyright 2010 Yi-Ta Chiang
//
//Licensed under the Apache License, Version 2.0 (the "License");
//you may not use this file except in compliance with the License.
//You may obtain a copy of the License at 
//
//http://www.apache.org/licenses/LICENSE-2.0

#import "PlurkismGrowlDelegate.h"


@implementation PlurkismGrowlDelegate

- (NSDictionary*)registrationDictionaryForGrowl {
	NSArray *allNotes = [NSArray arrayWithObjects:
						 NOTE_ERROR,
						 NOTE_INFO,
						 NOTE_NEWMESSAGE,
						 NOTE_NEWRESPONSE,
						 nil];
	return [NSDictionary dictionaryWithObjectsAndKeys:
			allNotes, GROWL_NOTIFICATIONS_ALL,
			allNotes, GROWL_NOTIFICATIONS_DEFAULT,
			nil];
}

- (NSString*)applicationNameForGrowl {
	return @"Plurkism";
}

- (void) growlNotificationWasClicked:(id)clickContext {
	NSString* str = (NSString*)clickContext;
	NSString* u = [NSString stringWithFormat:@"http://www.plurk.com/p/%@", str];
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:u]];
}
@end
