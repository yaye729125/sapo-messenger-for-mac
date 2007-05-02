//
//  LFPlatformBridge.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Authors: Joao Pavao <jppavao@criticalsoftware.com>
//           Jason Kim <jason@512k.org>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//
//
// Defines a class that abstracts the lower-level Leapfrog core into several utility methods
// (including a private one for use by the C wrapper functions). The primary one that other
// classes will call is invokeMethodWithName:isOneway:arguments:, which performs automatic type
// conversion of the appropriate native data types (such as NSString). It also defines a simple
// subclass, LFBoolean, which is a class that represents a single boolean value.
//
// Method calls are forwarded in a notification-like scheme, where registered "receivers" who
// implement the corresponding method become recipients of the message. This means that more than
// one object can actually "receive" a method call from the other side; the order of invocation
// is to be considered arbitrary.
//

#import <Cocoa/Cocoa.h>
#import "LFBoolean.h"
#import "LFObjectAdditions.h"
#import "leapfrog_platform.h"


@interface LFPlatformBridge : NSObject
+ (void)waitUntilPlatformBridgeIsInitialized;
+ (void)registerNotificationsObserver:(id)observer;
+ (void)unregisterNotificationsObserver:(id)observer;
+ (id)invokeMethodWithName:(NSString *)methodName isOneway:(BOOL)isOneway arguments:(id)firstArg, ...;

/*!
    @abstract   Shuts down the platform bridge.
    @discussion Shuts down the platform bridge. This method should be invoked after having sent a "systemQuit"
				message to the other side of the bridge. It tells the bridge that it shouldn't forward any more
				invocations to the other side, which ends up avoiding some deadlock situations that could arise
				upon application termination.
*/
+ (void)shutdown;
@end
