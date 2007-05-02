//
//  LPPlatform.m
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
// Implements Mac-specific platform calls to bootstrap application startup.
//

#include <stdio.h>
#import <Cocoa/Cocoa.h>
#import "leapfrog_platform.h"
#import "LFPlatformBridge.h"


/*
 * Cocoa needs to know that it is to be run in multi-threaded mode so that it can activate extra
 * safety measures to protect its internal data structures. When using NSThread to spawn new threads
 * this is taken care of automatically, but since we are using a second thread created in Qt code
 * and that thread ends up using Foundation and Cocoa methods in our own callbacks, we must notify
 * Cocoa about this manually before the callbacks get called for the first time.
 *
 * We're using a dummy class with a dummy method that does nothing just so that we can use it to
 * spawn the thread that will put the frameworks in multi-threaded mode.
 * 
 * Check the documentation on NSThread for more information.
 */
@interface LPPlatformCocoaMultiThreadingEnablerDummy : NSObject
+ (void)makeCocoaMultiThreadingAware:(id)ignoredArg;
@end

@implementation LPPlatformCocoaMultiThreadingEnablerDummy
+ (void)makeCocoaMultiThreadingAware:(id)ignoredArg { /* do nothing */ }
@end


#pragma mark -


LFP_EXPORT void mac_platform_init()
{
	// Initialize the conditional logging facilities
	LPDebugLogInit();
}

LFP_EXPORT void mac_platform_deinit()
{
	/* This function will never get called because Cocoa itself calls exit() somewhere inside
	NSApplicationMain(), so we will never be able to return from mac_platform_start() and
	should assume that the app dies in there. */
	return;
}

LFP_EXPORT int mac_platform_needs_main_thread()
{
	/* Force Cocoa to go into multi-threaded mode. See comments at the beginning of this file.
	 * 
	 * This would make more sense to be done in the mac_platform_init() function, but since the apple
	 * documentation says that "if you intend to use Cocoa calls, you must force Cocoa into its
	 * multithreaded mode before detaching any POSIX threads", and since the mac_platform_init()
	 * function is called when the secondary thread was already created, we'll do this in here instead
	 * because no threads have been spawned at this point.
	 */
	[NSThread detachNewThreadSelector:@selector(makeCocoaMultiThreadingAware:)
							 toTarget:[LPPlatformCocoaMultiThreadingEnablerDummy class]
						   withObject:nil];
	
	// Yes, we need to be in the main thread.
	return 1;
}

LFP_EXPORT void mac_platform_start(int argc, char **argv, void (*platform_ready)(void *i))
{
	// Execute the callback to get things rolling on the other side.
	platform_ready((void *) 1);
	
	// We should really wait until the Leapfrog bridge is completely initialized with the correct
	// references to the callbacks. When we start NSApplicationMain() we no longer have control over
	// what the objects in the GUI layer may do, and some object could try to use the bridge without
	// it being initialized. That would be bad, obviously.
	[LFPlatformBridge waitUntilPlatformBridgeIsInitialized];
	
	// Proceed with standard entry point.
	NSApplicationMain(argc, (const char**)argv);
}

LFP_EXPORT void mac_platform_stop()
{
	// mac_platform_stop() gets called by the core in the Alt thread
	
	// Ask the LPUIController to terminate. We are assuming that the termination request was triggered by the
	// user interface and that the global NSApp is already waiting for a confirmation about whether it should
	// proceed with termination or abort it.
	[[NSApp delegate] performSelectorOnMainThread:@selector(confirmPendingTermination:)
									   withObject:[NSNumber numberWithBool:YES]
									waitUntilDone:NO];
	
	// wait silently until the main thread kills us both
	[NSThread sleepUntilDate:[NSDate distantFuture]];
}

