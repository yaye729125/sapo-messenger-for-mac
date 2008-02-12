//
//  LFPlatformBridge.m
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Authors: Joao Pavao <jpavao@co.sapo.pt>
//           Jason Kim <jason@512k.org>
//
//	For more information on licensing, read the README file.
//	Para mais informa›es sobre o licenciamento, leia o ficheiro README.
//

#import "LFPlatformBridge.h"


#ifndef LFBRIDGE_DEBUG
#define LFBRIDGE_DEBUG (BOOL)0
#endif


// These globals are used with an NSConditionLock to implement "real" return values.
#define LFPlatformBridgeReturnWaitingCondition	0
#define LFPlatformBridgeReturnDoneCondition		1

// Constants for the condition lock that controls the leapfrog platform initialization sequence.
#define LFPlatformBridgeNotInitedYetCondition	0
#define LFPlatformBridgeAlreadyInitedCondition	1


SEL MakeSelector(NSString *methodName, unsigned int argCount);


static struct leapfrog_callbacks *s_callbacks;
static BOOL s_isShutdown = NO;


@interface LFPlatformBridge (Private)
/*
 * The next two methods shall be used to synchronize the initialization of the bridge.
 * By encapsulating all the lock operations inside these two class methods we can guarantee that
 * the lock will be correctly allocated and initialized whenever we try to use it from any
 * thread, thanks to the runtime calling the +initialize method always in a thread-safe way.
 */
/*!
 * @abstract Marks the beginning of a critical region that initializes the bridge.
 * @result TRUE if the initialization can proceed.
 */
+ (BOOL)p_shouldInitPlatformBridge;
/*!
 * @abstract Marks the end of a critical region that initializes the bridge. Shall only be called
 *     if it was preceeded by a call to p_shouldInitPlatformBridge that returned TRUE.
 */
+ (void)p_didInitPlatformBridge;

+ (int)p_processReceivedInvocationWithName:(NSString *)methodName argumentsData:(NSData *)argData;
+ (void)p_dispatchBridgeNotificationWithSelector:(SEL)selector arguments:(NSArray *)args;
@end


#pragma mark -
#pragma mark Wrapper Functions


void leapfrog_platform_init(leapfrog_platform_t *instance, struct leapfrog_callbacks *callbacks)
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	if ([LFPlatformBridge p_shouldInitPlatformBridge]) {
		// Note: The instance argument is currently ignored.
		s_callbacks = (struct leapfrog_callbacks*) malloc(sizeof(struct leapfrog_callbacks));
		memcpy(s_callbacks, callbacks, sizeof(struct leapfrog_callbacks));
		
		LPDebugLog(LFBRIDGE_DEBUG, @"BRIDGE: Lilypad has been initialized.");
		
		[LFPlatformBridge p_didInitPlatformBridge];
	}
	
	[pool release];
}


int leapfrog_platform_invokeMethod(leapfrog_platform_t *instance, const char *methodName, const leapfrog_args_t *lf_args)
{
	NSString *methodString;
	NSData *argData;
	int result;

	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	{
		argData = [NSData dataWithBytes:lf_args->data length:lf_args->size];
		methodString = [NSString stringWithCString:methodName encoding:NSASCIIStringEncoding];
		result = [LFPlatformBridge p_processReceivedInvocationWithName:methodString argumentsData:argData];
	}
	[pool release];
	
	return result;
}


int leapfrog_platform_checkMethod(leapfrog_platform_t *instance, const char *method, const leapfrog_args_t *args)
{
	// TODO.
	LPDebugLog(LFBRIDGE_DEBUG, @"BRIDGE: checkMethod is not implemented (%s)", method);
	return 1;
}


#pragma mark -
#pragma mark LFPlatformBridge


// These are static because they are used by class methods.
static id				s_returnValue;
static NSConditionLock	*s_platformBridgeInitLock;	// used to synchronize the initialization of the bridge
static NSConditionLock	*s_returnLock;
static NSLock			*s_notificationsObserversLock;
static NSMutableArray	*s_notificationsObservers;


@implementation LFPlatformBridge

+ (void)initialize
{
	if (self == [LFPlatformBridge class]) {
		s_platformBridgeInitLock = [[NSConditionLock alloc] initWithCondition:LFPlatformBridgeNotInitedYetCondition];
		s_notificationsObserversLock = [[NSLock alloc] init];
	}
}


+ (void)waitUntilPlatformBridgeIsInitialized
{
	[s_platformBridgeInitLock lockWhenCondition:LFPlatformBridgeAlreadyInitedCondition];
	[s_platformBridgeInitLock unlock];
}


+ (void)registerNotificationsObserver:(id)observer
{
	[s_notificationsObserversLock lock];

	if (s_notificationsObservers == nil)
		s_notificationsObservers = [[NSMutableArray alloc] init];
	
	[s_notificationsObservers addObject:observer];
	
	[s_notificationsObserversLock unlock];
	
	LPDebugLog(LFBRIDGE_DEBUG, @"BRIDGE: Registered observer: %@", observer);
}


+ (void)unregisterNotificationsObserver:(id)observer
{
	[s_notificationsObserversLock lock];
	[s_notificationsObservers removeObject:observer];
	[s_notificationsObserversLock unlock];
	
	LPDebugLog(LFBRIDGE_DEBUG, @"BRIDGE: Unregistered observer: %@", observer);
}


+ (id)invokeMethodWithName:(NSString *)methodName isOneway:(BOOL)isOneway arguments:(id)firstArg, ...
{
	// If we have already been shut down, just bail out and do nothing
	if (s_isShutdown) return nil;
	
	NSMutableArray *args = [[NSMutableArray alloc] init];
	NSData *argData;
	id currentArg;
	id returnValue = nil;
	va_list va_args;
	int result;

	// Compile varargs into array.
	if (firstArg) {
		[args addObject:firstArg];
		
		// Iterate through remaining arguments.
		va_start(va_args, firstArg);
		while (currentArg = va_arg(va_args, id)) {
			[args addObject:currentArg];
		}
		va_end(va_args);
	}

	argData = [args encodedBridgeData];
	
	
	leapfrog_args_t lf_args;
	
	lf_args.size = [argData length];
	lf_args.data = (unsigned char *)[argData bytes];
	
	// Initialize and wait for lock.
	if (!isOneway) {
		if (s_returnLock == nil) {
			s_returnLock = [[NSConditionLock alloc] initWithCondition:LFPlatformBridgeReturnWaitingCondition];
		} else {
			[s_returnLock lock];
			[s_returnLock unlockWithCondition:LFPlatformBridgeReturnWaitingCondition];
		}
	}
	   
	LPDebugLog(LFBRIDGE_DEBUG, @"BRIDGE: Invoking '%@' on other side of bridge ...", methodName);
	result = s_callbacks->invokeMethod((leapfrog_platform_t *) 1, [methodName UTF8String], &lf_args);
	
	if (result == 0) {
		[NSException raise:@"LFInvalidInvocationException"
					format:@"Couldn't invoke method %@ with arguments %@", methodName, args];
	}
	else if (!isOneway) {
		// This will block until the _ret method is called ...
		[s_returnLock lockWhenCondition:LFPlatformBridgeReturnDoneCondition];
		returnValue = s_returnValue;
		[s_returnLock unlock];
	}
	
	[args release];
	
	return [returnValue autorelease]; // the returnValue was originally retained in p_processReceivedInvocationWithName:argumentsData:
}


+ (void)shutdown
{
	s_isShutdown = YES;
}


@end


@implementation LFPlatformBridge (Private)


+ (BOOL)p_shouldInitPlatformBridge
{
	if ([s_platformBridgeInitLock tryLockWhenCondition:LFPlatformBridgeNotInitedYetCondition]) {
		return YES;
	} else {
		// Couldn't get the lock, there's something wrong going on.
		[NSException raise:@"LFPlatformBridgeInitException" format:@"The platform bridge is being inited more than once."];
		return NO;
	}
}


+ (void)p_didInitPlatformBridge
{
	[s_platformBridgeInitLock unlockWithCondition:LFPlatformBridgeAlreadyInitedCondition];
}


+ (int)p_processReceivedInvocationWithName:(NSString *)methodName argumentsData:(NSData *)argData
{
	LPDebugLog(LFBRIDGE_DEBUG, @"BRIDGE: Processing received invocation '%@' on this side of the bridge ...", methodName);
	
	NSArray	*args = [NSObject decodeObjectWithBridgeData:argData];
	
	// Sanity check: Make sure we received an array of args.
	if (![args isKindOfClass:[NSArray class]]) {
		[NSException raise:@"LFInvalidInvocationException" 
					format:@"Received argument list of unexpected type (%@)", [args class]];	
	}
	
	// See if the method is actually a return value
	if ([methodName hasSuffix:@"_ret"]) {
		if (s_returnLock && [s_returnLock condition] == LFPlatformBridgeReturnWaitingCondition) {
			// WARNING: There is currently no check to ensure that the *correct* return value was
			// returned; it is technically (but not practically) possible that we somehow get a
			// bad or unexpected return value, and we should probably check for this eventually.
			[s_returnLock lock];
			
			if ([args count] > 0)
				s_returnValue = [[args objectAtIndex:0] retain];
			else
				s_returnValue = nil;
			
			[s_returnLock unlockWithCondition:LFPlatformBridgeReturnDoneCondition];
		}
	}
	else {
		/* Replace the "notify_" prefix with a prefix of our own so that the bridge notifications observers are easy to spot
		in the code. Also, there's the convention (in Cocoa) that a notification receiving method usually has a name starting
		with something similar to the name of the class that emits the notifications. This is the closer to that convention
		that we can get. The underscore was kept because it helps to differentiate the methods that respond to notifications from
		the bridge from those methods that respond to conventional Cocoa notifications. To the seasoned Cocoa programmer it feels
		like the method has something different just by looking at the name. :-) */
		if ([methodName hasPrefix:@"notify_"]) {
			methodName = [@"leapfrogBridge_" stringByAppendingString:[methodName substringFromIndex:7]];
		}
		
		[self p_dispatchBridgeNotificationWithSelector:MakeSelector(methodName, [args count]) arguments:args];
	}
	
	return 0;
}


+ (void)p_dispatchBridgeNotificationWithSelector:(SEL)selector arguments:(NSArray *)args
{
	BOOL	invokeSuccess = NO;

	[s_notificationsObserversLock lock];
	/*
	 * We are keeping the lock for a long time (the iteration over the whole array). We could make a
	 * copy of the array and release the lock right away, before starting the iteration. But then we
	 * would be incurring in a penalty to every notification/method invocation requested by the other
	 * side of the bridge, by always having to do that copy. Let's assume that method invocations are
	 * much more frequent than adding and removing observers from the s_notificationsObservers array.
	 * This should be looked into more carefully when the app gets more mature, though.
	 * 
	 * TODO: check what is said in the previous paragraph, some weeks from now (09-Mar-2006).
	 */
	
	NSEnumerator	*targetEnumerator = [s_notificationsObservers objectEnumerator];
	id				target;
	
	while ((target = [targetEnumerator nextObject])) {
		NSEnumerator *argEnumerator = [args objectEnumerator];
		NSInvocation *invocation;
		
		// Prep invocation object.
		NSMethodSignature *signature = [target methodSignatureForSelector:selector];
		
		if (signature == nil) 
			continue;		
		else
			invocation = [NSInvocation invocationWithMethodSignature:signature];
		
		// Set invocation parameters.
		[invocation setSelector:selector];
		[invocation setTarget:target];
		
		// Add each argument to the invocation.
		int argIndex = 2; // skip self and _cmd
		id	argObject;
		while ((argObject = [argEnumerator nextObject])) {
			unsigned char	auxBuf[sizeof(long long)];  // Use long long to be able to hold the largest numeric values
			void			*arg = NULL;
			
			if ([argObject isKindOfClass:[LFBoolean class]]) {
				*((BOOL *)auxBuf) = [argObject boolValue];
				arg = auxBuf;
			}
			else if ([argObject isKindOfClass:[NSNumber class]]) {
				// What kind of int does the argument take?
				const char *argTypeEncoding = [signature getArgumentTypeAtIndex:argIndex];
				
				if (strcmp(argTypeEncoding, @encode(short)) == 0) {
					*((short *)auxBuf) = [argObject shortValue];
				}
				else if (strcmp(argTypeEncoding, @encode(unsigned short)) == 0) {
					*((unsigned short *)auxBuf) = [argObject unsignedShortValue];
				}
				else if (strcmp(argTypeEncoding, @encode(long)) == 0 || strcmp(argTypeEncoding, @encode(int)) == 0) {
					*((long *)auxBuf) = [argObject longValue];
				}
				else if (strcmp(argTypeEncoding, @encode(unsigned long)) == 0 || strcmp(argTypeEncoding, @encode(unsigned int)) == 0) {
					*((unsigned long *)auxBuf) = [argObject unsignedLongValue];
				}
				else if (strcmp(argTypeEncoding, @encode(long long)) == 0) {
					*((long long *)auxBuf) = [argObject longLongValue];
				}
				else if (strcmp(argTypeEncoding, @encode(unsigned long long)) == 0) {
					*((unsigned long long *)auxBuf) = [argObject unsignedLongLongValue];
				}
				arg = auxBuf;
			}
			else {
				arg = &argObject;
			}
			
			[invocation setArgument:arg atIndex:argIndex];
			++argIndex;
		}
		
		// Since the invocation will float around for a bit, it needs to retain references to
		// its arguments.
		[invocation retainArguments];
		
		// Enqueue invocation for execution on main thread.
		/* We don't want to disturb with our notifications if the application is in an event tracking loop or modal panel loop.
			This mimics the behavior of NSURLConnection and other classes that provide asynchronous notifications. */
		[invocation performSelectorOnMainThread:@selector(invoke)
									 withObject:nil
								  waitUntilDone:NO
										  modes:[NSArray arrayWithObject:NSDefaultRunLoopMode]];
		
		// LPDebugLog(LFBRIDGE_DEBUG, @"BRIDGE: Invoking selector '%@' on observer: %@", NSStringFromSelector(selector), target);
		
		invokeSuccess = YES;
	}
	
	[s_notificationsObserversLock unlock];
	
	if (!invokeSuccess)
		LPDebugLog(LFBRIDGE_DEBUG, @"BRIDGE: No observer for method '%@'[%d args]", NSStringFromSelector(selector), [args count]);
}


@end


#pragma mark -
#pragma mark Utility Functions


SEL MakeSelector(NSString *methodName, unsigned int argCount)
{
	NSMutableString *selectorString = [methodName mutableCopy];
	int i;

	for (i = 0; i < argCount; i++)
		[selectorString appendString:@":"];
	
	SEL selector = NSSelectorFromString(selectorString);
	[selectorString release];
	
	return selector;
}

