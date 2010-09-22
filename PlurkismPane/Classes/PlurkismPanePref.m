//Copyright 2010 Yi-Ta Chiang
//
//Licensed under the Apache License, Version 2.0 (the "License");
//you may not use this file except in compliance with the License.
//You may obtain a copy of the License at 
//
//http://www.apache.org/licenses/LICENSE-2.0


#import "PlurkismPanePref.h"
#import <ApplicationServices/ApplicationServices.h>


@implementation PlurkismPanePref
- (NSURL*) FindURLForbundleIdentifier:(NSString*) bundleIdentifier {
	NSArray *urls = nil;
	_LSCopyAllApplicationURLs(&urls);
	if(urls == nil) {
		return nil;
	}
	int i;
	for(i=0;i<[urls count];i++){
		NSBundle* bundle = [NSBundle bundleWithPath:[[urls objectAtIndex:i] path]];
		if([[bundle bundleIdentifier] isEqualToString:bundleIdentifier]) {
			NSURL* ret = [NSURL URLWithString:[[urls objectAtIndex:i] absoluteString]];
			[urls release];
			return ret;
		}
	}
	[urls release];
	return nil;
}

- (NSURL*) FindAndUpdateAPPLocation {
	//find & verify app location in pref
	CFPropertyListRef value = [self getPrefValue:KEY_PATH withAPP:CFSTR(APP_NAME) andType:CFStringGetTypeID()];
	NSURL* app = nil;
	BOOL willSearch = YES;
	if (value) {
		NSURL* url = [NSURL URLWithString:(NSString*)value];
		NSBundle* bundle = [NSBundle bundleWithURL:url];
		if (bundle!=nil && [[bundle bundleIdentifier] isEqualToString:NS_APP_NAME]) {
			app = url;
			willSearch = NO;
		} 
	}
	
	//research app if not found
	if (willSearch) {
		app = [self FindURLForbundleIdentifier:NS_APP_NAME];
		if(app == nil) {
			NSRunAlertPanel(@"Program not found",
							[NSString stringWithFormat:@"%@ program is not found", NS_APP_NAME],
							@"OK", NULL, NULL);
			CFRelease(value);
			return nil;
		} else {
			CFPreferencesSetAppValue(KEY_PATH, [app absoluteString] , CFSTR(APP_NAME));
			CFPreferencesAppSynchronize(CFSTR(APP_NAME));
		}
		
	}
	return app;
}

- (BOOL) willStartAtLogin
{	
	
	NSURL* app = [self FindAndUpdateAPPLocation];
	//search in login item
	Boolean foundIt=false;
    LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    if (loginItems) {
        UInt32 seed = 0U;
        NSArray *currentLoginItems = [NSMakeCollectable(LSSharedFileListCopySnapshot(loginItems, &seed)) autorelease];
        for (id itemObject in currentLoginItems) {
            LSSharedFileListItemRef item = (LSSharedFileListItemRef)itemObject;
			
            UInt32 resolutionFlags = kLSSharedFileListNoUserInteraction | kLSSharedFileListDoNotMountVolumes;
            CFURLRef URL = NULL;
            OSStatus err = LSSharedFileListItemResolve(item, resolutionFlags, &URL, NULL);
            if (err == noErr) {
                foundIt = CFEqual(URL, app);
                CFRelease(URL);
				
                if (foundIt)
                    break;
            }
        }
        CFRelease(loginItems);
    }
    return (BOOL)foundIt;
}

-(void) setStartAtLogin:(BOOL)enabled
{
	NSURL* itemURL = [self FindAndUpdateAPPLocation];
    LSSharedFileListItemRef existingItem = NULL;
	
    LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    if (loginItems) {
        UInt32 seed = 0U;
        NSArray *currentLoginItems = [NSMakeCollectable(LSSharedFileListCopySnapshot(loginItems, &seed)) autorelease];
        for (id itemObject in currentLoginItems) {
            LSSharedFileListItemRef item = (LSSharedFileListItemRef)itemObject;
			
            UInt32 resolutionFlags = kLSSharedFileListNoUserInteraction | kLSSharedFileListDoNotMountVolumes;
            CFURLRef URL = NULL;
            OSStatus err = LSSharedFileListItemResolve(item, resolutionFlags, &URL, /*outRef*/ NULL);
            if (err == noErr) {
                Boolean foundIt = CFEqual(URL, itemURL);
                CFRelease(URL);
				
                if (foundIt) {
                    existingItem = item;
                    break;
                }
            }
        }
		
        if (enabled && (existingItem == NULL)) {
            LSSharedFileListInsertItemURL(loginItems, kLSSharedFileListItemLast,
                                          NULL, NULL, (CFURLRef)itemURL, 
										  (CFDictionaryRef)[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] 
																					   forKey:@"com.apple.loginitem.HideOnLaunch"], 
										  NULL);
			
        } else if (!enabled && (existingItem != NULL))
            LSSharedFileListItemRemove(loginItems, existingItem);
		
        CFRelease(loginItems);
    }       
}

- (void) mainViewDidLoad
{
	CFPropertyListRef value = [self getPrefValue:KEY_DEBUG withAPP:CFSTR(APP_NAME) andType:CFBooleanGetTypeID()];
	CFPropertyListRef account = [self getPrefValue:KEY_USERNAME withAPP:CFSTR(APP_NAME) andType:CFStringGetTypeID()];
	
	if(value!=NULL && CFGetTypeID(value) == CFBooleanGetTypeID()) {
		[debug setState:CFBooleanGetValue(value)];
	} else {
		[debug setState:NO];
	}
	
	if(value!=NULL) {
		CFRelease(value);
	}
	if(account!=NULL && CFGetTypeID(account) == CFStringGetTypeID()) {
		[userid setStringValue:(NSString*)account];
	}
	if(account!=NULL) {
		CFRelease(account);
	}
	has_autostart = [self willStartAtLogin];
	[autostart setState:[self willStartAtLogin]];
	[[about mainFrame] loadHTMLString:[NSString stringWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForResource:@"about" ofType:@"htm"] encoding:NSUTF8StringEncoding error:nil] baseURL:[NSURL URLWithString:@"http://about.htm"]];
}

- (CFPropertyListRef) getPrefValue:(CFStringRef)key withAPP:(CFStringRef)app andType:(CFTypeID)type {
	CFPropertyListRef value = CFPreferencesCopyAppValue(key, app);
	if(value!=NULL && CFGetTypeID(value)==type)
	{
		return value;
	}else if (value!=NULL) {
		CFRelease(value);
	}
	return NULL;
}

- (NSPreferencePaneUnselectReply)shouldUnselect {
	OSStatus status;
	NSString* account_val = [userid stringValue];
	NSString* pw_val = [pass stringValue];
	BOOL debug_val = ([debug state]==NSOnState);
	BOOL send_login_notify = NO;
	BOOL send_config_notify = NO;
	
	//handle login item
	if (has_autostart != [autostart state]) {
		[self setStartAtLogin:[autostart state]];
	}
	
	//load data in preference file
	CFPropertyListRef account_old = [self getPrefValue:KEY_USERNAME withAPP:CFSTR(APP_NAME) andType:CFStringGetTypeID()];
	CFPropertyListRef debug_old = [self getPrefValue:KEY_DEBUG withAPP:CFSTR(APP_NAME) andType:CFBooleanGetTypeID()];
	BOOL debug_old_bool = (debug_old!=NULL && CFBooleanGetValue(debug_old));
	
	if(account_old==NULL || ![account_val isEqualToString:(NSString*)account_old]) {
		CFPreferencesSetAppValue(KEY_USERNAME, account_val, CFSTR(APP_NAME));
		send_login_notify = YES;
	}
	
	if (debug_val !=debug_old_bool) {
		CFPreferencesSetAppValue(KEY_DEBUG, ((debug_val==YES)?kCFBooleanTrue:kCFBooleanFalse) , CFSTR(APP_NAME));
		send_config_notify = YES;
	}
	
	SecKeychainItemRef itemRef = nil;
	UInt32 len;
	char* orig_pw;
	
	if([pw_val length]!=0) { // only need to change when user input some data
		
		//check if keychain has data
		status = SecKeychainFindGenericPassword(NULL,
												strlen(APP_NAME),
												APP_NAME,
												strlen([(NSString*)KEY_USERNAME UTF8String]),
												[(NSString*)KEY_USERNAME UTF8String],
												&len,
												(void**)&orig_pw,
												&itemRef);
		
		if (status == noErr) { // have save password already
			//compare original data
			char* pw_pad_null = malloc(sizeof(char)*(len+1));
			memcpy(pw_pad_null, orig_pw, len);
			pw_pad_null[len]='\0';
			if (![pw_val isEqualToString:[NSString stringWithUTF8String:pw_pad_null]]) { //value changed, modify data
				status =  SecKeychainItemModifyAttributesAndData(itemRef,
																 NULL,
																 strlen([pw_val UTF8String]),
                                                                 (const void*)[pw_val UTF8String]);
				if(status==noErr) {
					send_login_notify=YES;
				} else { // modify error
					CFStringRef str = SecCopyErrorMessageString(status, NULL);
					NSRunAlertPanel(@"Keychain data modify error",
									[NSString stringWithFormat:@"Error Code: %d, message:%@", status, str],
									@"OK", NULL, NULL);
					CFRelease(str);
				}
			}
		} else if(status == errSecItemNotFound) { //create new keychain record
			status = SecKeychainAddGenericPassword(NULL, 
												   strlen(APP_NAME),
												   APP_NAME,
												   strlen([(NSString*)KEY_USERNAME UTF8String]),
												   [(NSString*)KEY_USERNAME UTF8String],
												   strlen([pw_val UTF8String]),
												   (const void*)[pw_val UTF8String],
												   NULL);
			if(status ==noErr) {
				send_login_notify = YES;
			} else { // keychan create error
				CFStringRef str = SecCopyErrorMessageString(status, NULL);
				NSRunAlertPanel(@"Keychain data add error",
								[NSString stringWithFormat:@"Error Code: %d, message:%@", status, str],
								@"OK", NULL, NULL);
				CFRelease(str);
                
			}
			
		} else { //keychain read error
			CFStringRef str = SecCopyErrorMessageString(status, NULL);
			NSRunAlertPanel(@"Keychain data read error",
							[NSString stringWithFormat:@"Error Code: %d, message:%@", status, str],
							@"OK", NULL, NULL);
			CFRelease(str);
		}
		if (itemRef) CFRelease(itemRef);
	}
	
	CFPreferencesAppSynchronize(CFSTR(APP_NAME));
	
	if(send_login_notify) {
		[[NSDistributedNotificationCenter defaultCenter] postNotificationName:NOTIFY_LOGIN object:nil];
	}
	
	if(send_config_notify) {
		[[NSDistributedNotificationCenter defaultCenter] postNotificationName:NOTIFY_DEBUG object:nil];
	}
	
	if(account_old) CFRelease(account_old);
	if(debug_old) CFRelease(debug_old);
	
	return NSUnselectNow;
}

- (void)webView:(WebView *)webView decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id < WebPolicyDecisionListener >)listener {
	if([[[request URL] absoluteString] rangeOfString:@"about.htm"].location ==NSNotFound) {		
		[[NSWorkspace sharedWorkspace] openURL:[request URL]];
		[listener ignore];
	} else {
		[listener use];
	}
	
}
@end
