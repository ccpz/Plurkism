//Copyright 2010 Yi-Ta Chiang
//
//Licensed under the Apache License, Version 2.0 (the "License");
//you may not use this file except in compliance with the License.
//You may obtain a copy of the License at 
//
//http://www.apache.org/licenses/LICENSE-2.0

#import <Cocoa/Cocoa.h>
#import "JSON/JSON.h"
#import "ASIHTTPRequest/ASIHTTPRequest.h"
#import "../Common.h"
#import "PlurkismAppController.h"
#import "Growl.framework/Headers/Growl.h"
#import "PlurkismGrowlDelegate.h"


#define API_KEY @"2w3LnBHYvPvJBadBcvOjskKCEmQDLeUd"
#define API_PATH_LOGIN @"/API/Users/login"
#define API_PATH_LOGOUT @"/API/Users/logout"
#define API_PATH_GETCHANNEL @"/API/Realtime/getUserChannel"
#define API_PATH_GETPUBLIC_PROFILE @"/API/Profile/getPublicProfile"

@interface PlurkController : NSObject <ASIHTTPRequestDelegate> {
@private NSMutableString* channel;
@private NSMutableDictionary* messages;
@private NSMutableDictionary* users;
}

- (void) LogoutPlurk;
- (void) LoginPlurk;
- (void) SendRequest:(NSURL*) url;
- (void) SendRequest:(NSURL*) url withID:(NSNumber*) Id;
-(NSString*) PlurkAPIUrl:(NSString*) url withGET:(NSString*)get_string;
-(NSString*) PlurkAPIUrl:(NSString*) url withGET:(NSString*)get_string withSSL:(BOOL)SSL;
-(NSString*) avatarURL:(NSDictionary*) user;
-(NSNumber*) UniqueID;
- (void)timerFireMethod:(NSTimer*)theTimer;

@end
