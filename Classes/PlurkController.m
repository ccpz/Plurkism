//Copyright 2010 Yi-Ta Chiang
//
//Licensed under the Apache License, Version 2.0 (the "License");
//you may not use this file except in compliance with the License.
//You may obtain a copy of the License at 
//
//http://www.apache.org/licenses/LICENSE-2.0

#import "PlurkController.h"


@implementation PlurkController

- (id)init {
    if ((self = [super init])) {
        srandom(time(0));
		messages = [[NSMutableDictionary alloc] init];
		users = [[NSMutableDictionary alloc] init];
    }
    
    return self;
}

- (void)dealloc {
    [messages release];
    [users release];
    
    [super dealloc];
}

#pragma mark Util Function

- (void) LoginPlurk{
	CFPreferencesAppSynchronize(CFSTR(APP_NAME));
	NSString* account = (NSString*)CFPreferencesCopyAppValue(KEY_USERNAME, CFSTR(APP_NAME));
	if(account!=nil) {
		UInt32 len;
		char* pw;
		SecKeychainItemRef itemRef = nil;
		
		OSStatus status = SecKeychainFindGenericPassword(NULL,
														 strlen(APP_NAME),
														 APP_NAME,
														 strlen([(NSString*)KEY_USERNAME UTF8String]),
														 [(NSString*)KEY_USERNAME UTF8String],
														 &len,
														 (void**)&pw,
														 &itemRef);
		if (status == noErr) {
			char* null_pad_pw = malloc(sizeof(char)*(len+1));
			memcpy(null_pad_pw, pw, len);
			null_pad_pw[len]='\0';
			NSString* nspw = [NSString stringWithUTF8String:null_pad_pw];
			free(null_pad_pw);
			if ([(PlurkismAppController*)[NSApp delegate] debug]) {
				NSLog(@"Login with userid: %@", account);
			}
			NSURL *url = [NSURL URLWithString:[self PlurkAPIUrl:API_PATH_LOGIN withGET:[NSString stringWithFormat:@"api_key=%@&username=%@&password=%@", API_KEY, account, nspw] withSSL:YES]];
			ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url];
			[request setDelegate:self];
			[request startAsynchronous];
			
		} else {
			CFStringRef msg = SecCopyErrorMessageString(status, NULL);
			NSRunAlertPanel(_L(@"Keychain data read error"),
							[NSString stringWithFormat:_L(@"Error Code: %ld, message:%@"), status, msg],
							@"OK", NULL, NULL);
			CFRelease(msg);
		}
		CFRelease(account);
		if (itemRef) CFRelease(itemRef);
	} else {
		NSURL *URL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"openSetting" ofType:@"scpt"]];
		NSAppleScript* script = [[NSAppleScript alloc] initWithContentsOfURL:URL error:nil];
		[script executeAndReturnError:nil];
		[script release];
	}
    
}

- (void) LogoutPlurk{
	NSURL *url = [NSURL URLWithString:[self PlurkAPIUrl:API_PATH_LOGOUT withGET:[NSString stringWithFormat:@"api_key=%@", API_KEY]]];
	ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url];
	[request setDelegate:nil];
	[request startAsynchronous];
}

-(NSString*) PlurkAPIUrl:(NSString*) url withGET:(NSString*)get_string{
	return [self PlurkAPIUrl:url withGET:get_string withSSL:NO];
}

-(NSString*) PlurkAPIUrl:(NSString*) url withGET:(NSString*)get_string withSSL:(BOOL)SSL {
	NSString* protocol;
	if (SSL) {
		protocol=@"https";
	} else {
		protocol=@"http";
	}
	
	return [NSString stringWithFormat:@"%@://www.plurk.com%@?%@", protocol, url, get_string];
}

-(NSString*) avatarURL:(NSDictionary*) user {
	NSNumber* has_profile_image = [user objectForKey:@"has_profile_image"];
	if([has_profile_image intValue]==0) {
		return @"http://www.plurk.com/static/default_medium.gif";
	}else if ([user objectForKey:@"avatar"]==nil) {
		NSNumber* userid = [user objectForKey:@"user_id"];
		return [NSString stringWithFormat:@"http://avatars.plurk.com/%@-medium.gif", [userid stringValue]];
	} else {
		NSNumber* userid = [user objectForKey:@"id"];
		NSNumber* avatar = [user objectForKey:@"avatar"];
		return [NSString stringWithFormat:@"http://avatars.plurk.com/%@-medium%@.gif", [userid stringValue], [avatar stringValue]];
	}
	
}

-(NSNumber*) UniqueID {
	NSNumber* randid;
	do {
		randid = [NSNumber numberWithLong:random()];
	} while ([messages objectForKey:randid] != nil);
	return randid;
}

- (void) SendRequest:(NSURL*) url {
	[self SendRequest:url withID:[NSNumber numberWithInt:-1]];
}

- (void) SendRequest:(NSURL*) url withID:(NSNumber*) Id{
	ASIHTTPRequest *request2 = [ASIHTTPRequest requestWithURL:url];
	[request2 setDelegate:self];
	[request2 setTimeOutSeconds:60];
	[request2 setRequestID:Id];
	if ([(PlurkismAppController*)[NSApp delegate] debug]) {
		NSLog(@"HTTP request: %@", [[request2 url] absoluteString]);
	}
	[request2 startAsynchronous];
}
#pragma mark -
#pragma mark ASIHTTPRequestDelegate
- (void)requestFinished:(ASIHTTPRequest *)request {
	if ([(PlurkismAppController*)[NSApp delegate] debug]) {
		NSLog(@"HTTP response code: %d", [request responseStatusCode]);
		NSLog(@"HTTP Data: %@", [request responseString]);
	}
	if ([[[request url] path] caseInsensitiveCompare:API_PATH_LOGIN]==NSOrderedSame) {
		if([request responseStatusCode]==400) {
			SBJsonParser* json = [[SBJsonParser alloc] init];
			NSDictionary* data = [json objectWithString:[request responseString]];
			NSString* msg = [NSString stringWithFormat:_L(@"Login Failed: %@"), [data objectForKey:@"error_text"]];
			[GrowlApplicationBridge notifyWithTitle:_L(@"Error") description:msg notificationName:NOTE_ERROR iconData:nil priority:0 isSticky:NO clickContext:nil];
			[json release];
		} else {
			SBJsonParser* json = [[SBJsonParser alloc] init];
			NSDictionary* data = [json objectWithString:[request responseString]];
			[json release];
			NSDictionary* userinfo = [data objectForKey:@"user_info"];
			NSString* rawname = [userinfo objectForKey:@"display_name"];
			if([rawname length]==0) {
				rawname = [userinfo objectForKey:@"nick_name"];
			}
			NSString* msg = [NSString stringWithFormat:_L(@"Login as %@ successed"), rawname];
			[GrowlApplicationBridge notifyWithTitle:_L(NOTE_INFO) description:msg notificationName:NOTE_INFO iconData:nil priority:0 isSticky:NO clickContext:nil];
			NSURL* url = [NSURL URLWithString:[self PlurkAPIUrl:API_PATH_GETCHANNEL withGET:[NSString stringWithFormat:@"api_key=%@", API_KEY]]];
			[self SendRequest:url];
		}
		
	} else if ([[[request url] path] caseInsensitiveCompare:API_PATH_GETCHANNEL]==NSOrderedSame) { 
		SBJsonParser* json = [[SBJsonParser alloc] init];
		NSDictionary* data = [json objectWithString:[request responseString]];
		[json release];
		
		channel = [[NSMutableString alloc] initWithString:[data objectForKey:@"comet_server"]];
		NSURL* url = [NSURL URLWithString:channel];
		
		NSRange range = [channel rangeOfString:@"&offset="];
		[channel deleteCharactersInRange:NSMakeRange(range.location, [channel length]-range.location)];
		[self SendRequest:url];
	} else if ([[[request url] path] caseInsensitiveCompare:API_PATH_GETPUBLIC_PROFILE]==NSOrderedSame) { 
		SBJsonParser* json = [[SBJsonParser alloc] init];
		NSDictionary* data = [json objectWithString:[request responseString]];
		//NSLog(@"%@", [request responseString]);
		[json release];
		NSDictionary* userinfo = [data objectForKey:@"user_info"];
		NSString* rawname = [userinfo objectForKey:@"display_name"];
		if([rawname length]==0) {
			rawname = [userinfo objectForKey:@"nick_name"];
		}
		
		[users setObject:[NSString stringWithUTF8String:[rawname UTF8String]] forKey:[request requestID]];
		[self SendRequest:[NSURL URLWithString:[self avatarURL:userinfo]] withID:[request requestID]];
	}else if ([[[request url] path] rangeOfString:@"comet" options:NSCaseInsensitiveSearch].location != NSNotFound) {
		SBJsonParser* json = [[SBJsonParser alloc] init];
		NSDictionary* data = [json objectWithString:[request responseString]];
		[json release];
		
		if([data objectForKey:@"data"]!=nil) {
			NSArray* a = [data objectForKey:@"data"];
			NSDictionary* d = [a objectAtIndex:0];
			NSNumber* key = [self UniqueID];
			NSNumber* userid = [NSNumber numberWithInt:0];
			NSString* type = [d objectForKey:@"type"];
			[messages setObject:data forKey:key];
			
			if([type caseInsensitiveCompare:@"new_plurk"]==NSOrderedSame) {
				userid = [d objectForKey:@"user_id"];
			}else if([type caseInsensitiveCompare:@"new_response"]==NSOrderedSame) {
				NSDictionary* user = [d objectForKey:@"user"];
				NSNumberFormatter * f = [[NSNumberFormatter alloc] init];
				[f setNumberStyle:NSNumberFormatterDecimalStyle];
				userid = [f numberFromString:[[user allKeys] objectAtIndex:0]];
				[f release];
			}
			
			NSURL* url = [NSURL URLWithString:[self PlurkAPIUrl:API_PATH_GETPUBLIC_PROFILE withGET:[NSString stringWithFormat:@"api_key=%@&user_id=%@", API_KEY, [userid stringValue]]]];
			[self SendRequest:url withID:key];
		} else {
			NSNumber* offset = [data objectForKey:@"new_offset"];
			if([offset isEqualToNumber:[NSNumber numberWithInt:-3]]==YES) {
				/*resync channel*/
				NSURL* url = [NSURL URLWithString:[self PlurkAPIUrl:API_PATH_GETCHANNEL withGET:[NSString stringWithFormat:@"api_key=%@", API_KEY]]];
				[self SendRequest:url];
			} else {
				/*wait for next message*/
				NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"%@&offset=%@", channel, [offset stringValue]]];
				[self SendRequest:url];
			}
		}
	}else if ([[[request url] path] rangeOfString:@"gif" options:NSCaseInsensitiveSearch].location != NSNotFound) {
		NSDictionary* message = [messages objectForKey:[request requestID]];
		NSArray* a = [message objectForKey:@"data"];
		NSDictionary* d = [a objectAtIndex:0];
		NSString* type = [d objectForKey:@"type"];
		
        
		NSNumber * nsPlurkid = [d objectForKey:@"plurk_id"];
		uint64_t plurk_id = [nsPlurkid unsignedLongLongValue];
		NSString* mapping = [NSString stringWithFormat:@"%s","0123456789abcdefghijklmnopqrstuvwxyz"];
		NSMutableString* stringID = [[[NSMutableString alloc] init] autorelease];
		do {
			[stringID insertString:[NSString stringWithFormat:@"%C", [mapping characterAtIndex:(plurk_id%36)]] atIndex:0];
			plurk_id -= plurk_id%36;
			plurk_id /=36;
		} while (plurk_id!=0);
		
		NSString* title = _L(NOTE_NEWMESSAGE);
		if([type caseInsensitiveCompare:@"new_response"]==NSOrderedSame) {
			d = [d objectForKey:@"response"];
			title = _L(NOTE_NEWRESPONSE);	
		}
		
		NSString* name = [users objectForKey:[request requestID]];
		NSString * content = [d objectForKey:@"content_raw"];
		NSString* msg = [NSString stringWithFormat:@"%@ %@ %@", name, [d objectForKey:@"qualifier"], [NSString stringWithUTF8String:[content UTF8String]]];
		[GrowlApplicationBridge notifyWithTitle:title description:msg notificationName:title iconData:[request responseData] priority:0 isSticky:NO clickContext:stringID];
		
		NSNumber* offset = [message objectForKey:@"new_offset"];
		NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"%@&offset=%@", channel, [offset stringValue]]];
		[messages removeObjectForKey:[request requestID]];
		[users removeObjectForKey:[request requestID]];
		[self SendRequest:url];
        
	}
}

- (void)requestFailed:(ASIHTTPRequest *)request {
	NSString* msg;
	if ([request responseStatusCode]==0) {
		msg = [NSString stringWithFormat:_L(@"HTTP Request Fail: %@"), [[request error] localizedDescription]];
	} else {
		msg = [NSString stringWithFormat:_L(@"HTTP Request Fail: %@"), [request responseStatusMessage]];
	}
	[GrowlApplicationBridge notifyWithTitle:_L(NOTE_ERROR) description:msg notificationName:NOTE_ERROR iconData:nil priority:0 isSticky:NO clickContext:nil];
	NSTimer *timer = [NSTimer timerWithTimeInterval:30 target:self selector:@selector(timerFireMethod:) userInfo:(id)request repeats:NO];
	[[NSRunLoop currentRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];  
    [[NSRunLoop currentRunLoop] run];
}

- (void)timerFireMethod:(NSTimer*)theTimer {
	ASIHTTPRequest *orig_request = [theTimer userInfo];
	[self SendRequest:[orig_request url] withID:[orig_request requestID]];
}
#pragma mark -
@end
