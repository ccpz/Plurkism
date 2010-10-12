//Copyright 2010 Yi-Ta Chiang
//
//Licensed under the Apache License, Version 2.0 (the "License");
//you may not use this file except in compliance with the License.
//You may obtain a copy of the License at 
//
//http://www.apache.org/licenses/LICENSE-2.0

#import <Foundation/Foundation.h>
#import "Growl.framework/Headers/Growl.h"
#import "Common.h"

#define NOTE_ERROR @"Error"
#define NOTE_INFO @"Info"
#define NOTE_NEWMESSAGE @"New Plurk Message"
#define NOTE_NEWRESPONSE @"New Plurk Response"

@interface PlurkismGrowlDelegate : NSObject<GrowlApplicationBridgeDelegate> {

}

@end
