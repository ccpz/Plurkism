//Copyright 2010 Yi-Ta Chiang
//
//Licensed under the Apache License, Version 2.0 (the "License");
//you may not use this file except in compliance with the License.
//You may obtain a copy of the License at 
//
//http://www.apache.org/licenses/LICENSE-2.0

#import <Cocoa/Cocoa.h>
#import "PlurkismAppController.h"

void sigterm(int id)
{
	[NSApp terminate:NSApp];
}

int main(int argc, char *argv[])
{
	[NSApplication sharedApplication];
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	PlurkismAppController *plurkism = [[PlurkismAppController alloc] init];
	
	[NSApp setDelegate:plurkism];
	
	signal(SIGTERM, sigterm);
	[NSApp run];
	
	[plurkism release];
	[NSApp release];
	[pool release];
	
	return EXIT_SUCCESS;
}
