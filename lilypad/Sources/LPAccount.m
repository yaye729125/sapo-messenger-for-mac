//
//  LPAccount.m
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Authors: Joao Pavao <jpavao@co.sapo.pt>
//           Jason Kim <jason@512k.org>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPAccount.h"
#import "LPChat.h"
#import "LPChatsManager.h"
#import "LPGroupChat.h"
#import "LPRoster.h"
#import "LPContact.h"
#import "LPContactEntry.h"
#import "LPFileTransfer.h"
#import "LPServerItemsInfo.h"
#import "LPSapoAgents.h"
#import "LFAppController.h"
#import "LFPlatformBridge.h"
#import "LPKeychainManager.h"
#import "LPPubManager.h"

#import <AddressBook/AddressBook.h>
#import <SystemConfiguration/SystemConfiguration.h>


#import <netinet/in.h>
#import <arpa/inet.h>


#ifndef REACHABILITY_DEBUG
#define REACHABILITY_DEBUG (BOOL)0
#endif


@interface LPAccount ()  // Private Methods
- (NSString *)p_computerNameForLocation;
- (void)p_updateLocationFromChangedComputerName;

// The actual accessors for these two attributes
- (void)p_setStatus:(LPStatus)theStatus;
- (void)p_setStatusMessage:(NSString *)theStatus;
- (NSString *)p_statusMessage;
- (void)p_setTargetStatus:(LPStatus)theStatus;
- (void)p_setOnlineStatus:(LPStatus)theStatus message:(NSString *)theMessage saveToServer:(BOOL)saveFlag;
- (void)p_setOnlineStatus:(LPStatus)theStatus message:(NSString *)theMessage saveToServer:(BOOL)saveFlag alsoSaveStatusMessage:(BOOL)saveMsg;

- (void)p_setAutomaticReconnectionStatus:(LPAutoReconnectStatus)status;

- (void)p_setAvatar:(NSImage *)avatar;
- (void)p_changeAndAnnounceAvatar:(NSImage *)avatar;

- (void)p_setSMSCredit:(int)credit freeMessages:(int)freeMsgs totalSent:(int)totalSent;

- (NSString *)p_lastAttemptedServerHost;
- (void)p_setLastAttemptedServerHost:(NSString *)host;
- (BOOL)p_lastConnectionAttemptDidFail;
- (void)p_setLastConnectionAttemptDidFail:(BOOL)flag;
@end



#pragma mark -
#pragma mark LPAccountAutomaticReconnectionContext


@interface LPAccountAutomaticReconnectionContext : NSObject
{
	SCNetworkReachabilityRef	m_serverHostReachabilityRef;
	LPAccount					*m_account;
	NSString					*m_observedLocalAddress;
	NSString					*m_observedRemoteAddress;
	
	LPAutoReconnectStatus		m_autoReconnectStatus;
	
	SCNetworkConnectionFlags	m_lastNetworkConnectionFlags;
	LPStatus					m_lastOnlineStatus;
	NSString					*m_lastOnlineStatusMessage;
	
	NSTimer						*m_lastScheduledReconnectionTimer;
	NSTimer						*m_connectionTimeoutTimer;
}

- initForObservingConnectionWithLocalAddress:(NSString *)localAddress remoteAddress:(NSString *)remoteAddress account:(LPAccount *)account;

- (LPAccount *)account;
- (NSString *)observedConnectionLocalAddress;
- (NSString *)observedConnectionRemoteAddress;
- (void)setObservedConnectionWithLocalAddress:(NSString *)localAddress remoteAddress:(NSString *)remoteAddress;

- (BOOL)isInTheMidstOfAutomaticReconnection;
- (LPAutoReconnectStatus)automaticReconnectionStatus;

- (SCNetworkConnectionFlags)lastNetworkConnectionFlags;
- (void)setLastNetworkConnectionFlags:(SCNetworkConnectionFlags)flags;

- (void)cancelAllTimers;

- (void)handleNetworkInterfaceDown;
- (void)handleNetworkInterfaceUp;

- (void)handleConnectionClosedByServer;
- (void)handleConnectionErrorWithName:(NSString *)errorName;

- (void)handleConnectionWasReEstablishedSuccessfully;
@end


@interface LPAccountAutomaticReconnectionContext ()  // Private Methods
- (void)p_setObservedNetworkReachabilityRef:(SCNetworkReachabilityRef)reachabilityRef;
- (void)p_setAutomaticReconnectionStatus:(LPAutoReconnectStatus)status;
- (void)p_setupReconnectTimerWithTimeInterval:(NSTimeInterval)timeInterval;
- (void)p_setupConnectionTimeoutTimerWithTimeInterval:(NSTimeInterval)timeInterval;
- (void)p_reconnect:(NSTimer *)timer;
- (void)p_reconnectTimedOut:(NSTimer *)timer;
@end



// Network Reachability Callback
static void
LPAccountServerHostReachabilityDidChange (SCNetworkReachabilityRef targetRef,
										  SCNetworkConnectionFlags flags,
										  void *info)
{
	LPAccountAutomaticReconnectionContext *context = (LPAccountAutomaticReconnectionContext *)info;
	LPAccount *account = [context account];
	
	BOOL isReachableImmediately = ((flags & kSCNetworkFlagsReachable) && !(flags & kSCNetworkFlagsConnectionRequired));
	LPDebugLog(REACHABILITY_DEBUG,
			   @"Account %@: REACHABILITY: Did Change: Reachable? %@ (flags: %d)",
			   account,
			   (isReachableImmediately ? @"YES" : @"NO"),
			   flags);
	
	if ([context lastNetworkConnectionFlags] != flags) {
		if (!isReachableImmediately) {
			LPDebugLog(REACHABILITY_DEBUG, @"Account %@: REACHABILITY: Did Change: Setting as OFFLINE", account);
			[context handleNetworkInterfaceDown];
		}
		else {
			LPDebugLog(REACHABILITY_DEBUG, @"Account %@: REACHABILITY: Did Change: Setting up reconnection timer.", account);
			[context handleNetworkInterfaceUp];
		}
		
		[context setLastNetworkConnectionFlags:flags];
	}
}



@implementation LPAccountAutomaticReconnectionContext

- initForObservingConnectionWithLocalAddress:(NSString *)localAddress remoteAddress:(NSString *)remoteAddress account:(LPAccount *)account
{
	if (self = [self init]) {
		m_account = [account retain];
		m_lastScheduledReconnectionTimer = nil;
		m_connectionTimeoutTimer = nil;
		
		[self p_setAutomaticReconnectionStatus:LPAutoReconnectIdle];
		[self setObservedConnectionWithLocalAddress:localAddress remoteAddress:remoteAddress];
		
		LPDebugLog(REACHABILITY_DEBUG, @"Account %@: reconnection context initted for connection with local address: %@ / remote address: %@",
				   m_account,
				   (m_observedLocalAddress ? m_observedLocalAddress : @"(none)"),
				   (m_observedRemoteAddress ? m_observedRemoteAddress : @"(none)"));
	}
	return self;
}


- (void)dealloc
{
	[self p_setObservedNetworkReachabilityRef:NULL];
	[self cancelAllTimers];
	
	[m_account release];
	[m_observedLocalAddress release];
	[m_observedRemoteAddress release];
	[m_lastOnlineStatusMessage release];
	
	[super dealloc];
}


- (LPAccount *)account
{
	return m_account;
}

- (NSString *)observedConnectionLocalAddress
{
	return m_observedLocalAddress;
}

- (NSString *)observedConnectionRemoteAddress
{
	return m_observedRemoteAddress;
}

- (void)p_setObservedNetworkReachabilityRef:(SCNetworkReachabilityRef)reachabilityRef
{
	LPDebugLog(REACHABILITY_DEBUG, @"Account %@: started observing a different reachability ref: %p", m_account, reachabilityRef);
	
	// Release the previous values...
	if (m_serverHostReachabilityRef != NULL) {
		SCNetworkReachabilityUnscheduleFromRunLoop( m_serverHostReachabilityRef,
												   [[NSRunLoop currentRunLoop] getCFRunLoop],
												   kCFRunLoopDefaultMode );
		CFRelease(m_serverHostReachabilityRef);
		m_serverHostReachabilityRef = NULL;
	}
	
	if (reachabilityRef != NULL) {
		m_serverHostReachabilityRef = CFRetain(reachabilityRef);
		
		SCNetworkReachabilityGetFlags(m_serverHostReachabilityRef, &m_lastNetworkConnectionFlags);
		SCNetworkReachabilityContext context = { 0, (void *)self, NULL, NULL, NULL };
		
		if ( SCNetworkReachabilitySetCallback( m_serverHostReachabilityRef,
											  LPAccountServerHostReachabilityDidChange,
											  &context) )
		{
			SCNetworkReachabilityScheduleWithRunLoop( m_serverHostReachabilityRef,
													 [[NSRunLoop currentRunLoop] getCFRunLoop],
													 kCFRunLoopDefaultMode );
		}
	}
}

- (void)setObservedConnectionWithLocalAddress:(NSString *)localAddress remoteAddress:(NSString *)remoteAddress
{
	NSParameterAssert(localAddress);
	NSParameterAssert(remoteAddress);
	
	if (![localAddress isEqualToString:m_observedLocalAddress] || ![remoteAddress isEqualToString:m_observedRemoteAddress]) {
		
		LPDebugLog(REACHABILITY_DEBUG, @"Account %@: setObservedConnectionWith... %@ / %@",
				   m_account,
				   (localAddress ? localAddress : @"(none)"),
				   (remoteAddress ? remoteAddress : @"(none)"));
		
		// Release the previous values...
		[m_observedLocalAddress release];
		[m_observedRemoteAddress release];
		
		// ...and create some new ones.
		m_observedLocalAddress = [localAddress copy];
		m_observedRemoteAddress = [remoteAddress copy];
		
		
		// Setup the sockaddr structures
		struct sockaddr_in local_saddr, remote_saddr;
		
		bzero(&local_saddr, sizeof(struct sockaddr_in));
		bzero(&remote_saddr, sizeof(struct sockaddr_in));
		
		local_saddr.sin_len = remote_saddr.sin_len = sizeof(struct sockaddr_in);
		local_saddr.sin_family = remote_saddr.sin_family = AF_INET;
		
		inet_aton([localAddress UTF8String], &(local_saddr.sin_addr));
		inet_aton([remoteAddress UTF8String], &(remote_saddr.sin_addr));
		
		
		SCNetworkReachabilityRef reachabilityRef = SCNetworkReachabilityCreateWithAddressPair( CFAllocatorGetDefault(),
																							   (struct sockaddr *)&local_saddr,
																							   (struct sockaddr *)&remote_saddr );
		[self p_setObservedNetworkReachabilityRef:reachabilityRef];
	}
}

- (BOOL)isInTheMidstOfAutomaticReconnection
{
	return (m_autoReconnectStatus != LPAutoReconnectIdle);
}

- (LPAutoReconnectStatus)automaticReconnectionStatus
{
	return m_autoReconnectStatus;
}

- (void)p_setAutomaticReconnectionStatus:(LPAutoReconnectStatus)status
{
	m_autoReconnectStatus = status;
	[[self account] p_setAutomaticReconnectionStatus:status];
}

- (SCNetworkConnectionFlags)lastNetworkConnectionFlags
{
	return m_lastNetworkConnectionFlags;
}

- (void)setLastNetworkConnectionFlags:(SCNetworkConnectionFlags)flags
{
	m_lastNetworkConnectionFlags = flags;
}


#pragma mark Timers

- (void)cancelAllTimers
{
	LPDebugLog(REACHABILITY_DEBUG, @"Account %@: cancelling all timers", m_account);
	
	[m_connectionTimeoutTimer invalidate];
	[m_connectionTimeoutTimer release];
	m_connectionTimeoutTimer = nil;
	
	[m_lastScheduledReconnectionTimer invalidate];
	[m_lastScheduledReconnectionTimer release];
	m_lastScheduledReconnectionTimer = nil;
}

- (void)p_setupReconnectTimerWithTimeInterval:(NSTimeInterval)timeInterval
{
	LPDebugLog(REACHABILITY_DEBUG, @"Account %@: setting up reconnect timer with interval: %f s", m_account, timeInterval);
	
	[m_connectionTimeoutTimer invalidate];
	[m_connectionTimeoutTimer release];
	m_connectionTimeoutTimer = nil;
	
	[m_lastScheduledReconnectionTimer invalidate];
	[m_lastScheduledReconnectionTimer release];
	m_lastScheduledReconnectionTimer = [[NSTimer scheduledTimerWithTimeInterval:timeInterval
																		 target:self
																	   selector:@selector(p_reconnect:)
																	   userInfo:nil
																		repeats:NO] retain];
}

- (void)p_setupConnectionTimeoutTimerWithTimeInterval:(NSTimeInterval)timeInterval
{
	LPDebugLog(REACHABILITY_DEBUG, @"Account %@: setting up connection timeout timer with interval: %f s", m_account, timeInterval);
	
	[m_connectionTimeoutTimer invalidate];
	[m_connectionTimeoutTimer release];
	m_connectionTimeoutTimer = [[NSTimer scheduledTimerWithTimeInterval:timeInterval
																 target:self
															   selector:@selector(p_reconnectTimedOut:)
															   userInfo:nil
																repeats:NO] retain];
}


#pragma mark Callbacks for the reconnection timers

- (void)p_reconnect:(NSTimer *)timer
{
	LPDebugLog(REACHABILITY_DEBUG, @"Account %@: REACHABILITY: Reconnection timer fired. Connecting...", m_account);
	
	[m_account p_setOnlineStatus:m_lastOnlineStatus message:m_lastOnlineStatusMessage saveToServer:NO];
	
	[self p_setupConnectionTimeoutTimerWithTimeInterval:30.0];
}

- (void)p_reconnectTimedOut:(NSTimer *)timer
{
	LPDebugLog(REACHABILITY_DEBUG, @"Account %@: REACHABILITY: Reconnection attempt timed out.", m_account);
	
	[m_account p_setOnlineStatus:LPStatusOffline message:nil saveToServer:NO];
	
	if (m_autoReconnectStatus != LPAutoReconnectIdle) {
		[self p_setupReconnectTimerWithTimeInterval:20.0];
	}
}

#pragma mark Event Handlers

- (void)handleNetworkInterfaceDown
{
	LPDebugLog(REACHABILITY_DEBUG, @"Account %@: Interface going DOWN!", m_account);
	
	m_lastOnlineStatus = [m_account targetStatus];
	
	[m_lastOnlineStatusMessage release];
	m_lastOnlineStatusMessage = [[m_account p_statusMessage] copy];
	
	// Set our status to offline in case the core hasn't noticed that we no longer have a working network connection :)
	[m_account p_setOnlineStatus:LPStatusOffline message:nil saveToServer:NO];
	
	
	// Check whether there is an alternate interface immediately available.
	// The interface used for our connection may have gone down, but there may be another interface currently UP that allows us to
	// establish another connection to our server right away.
	BOOL alternateRouteExists = NO;
	
	SCNetworkReachabilityRef reachabilityRef = SCNetworkReachabilityCreateWithName( CFAllocatorGetDefault(),
																				    [[self observedConnectionRemoteAddress] UTF8String] );
	if (reachabilityRef) {
		SCNetworkConnectionFlags flags;
		SCNetworkReachabilityGetFlags(reachabilityRef, &flags);
		
		alternateRouteExists = ((flags & kSCNetworkFlagsReachable) && !(flags & kSCNetworkFlagsConnectionRequired));
	}
	
	
	if (alternateRouteExists) {
		LPDebugLog(REACHABILITY_DEBUG, @"Account %@: Alternate route exists!", m_account);
		
		[self p_setAutomaticReconnectionStatus:LPAutoReconnectUsingMultipleRetryAttempts];
		[self p_setObservedNetworkReachabilityRef:NULL];
		[self p_setupReconnectTimerWithTimeInterval:5.0];
	}
	else {
		LPDebugLog(REACHABILITY_DEBUG, @"Account %@: No alternate route exists. Waiting for an interface to come up...", m_account);
		
		// Wait for some interface to go up
		[self p_setAutomaticReconnectionStatus:LPAutoReconnectWaitingForInterfaceToGoUp];
		
		// Cleanup the reconnection timers
		[self cancelAllTimers];
		
		// Stop observing the local/remote socket pair (which was specific for this interface) and simply start observing
		// the reachability of the server, no matter what route is taken to get to it.
		[self p_setObservedNetworkReachabilityRef:reachabilityRef];
		
		[m_observedLocalAddress release];
		m_observedLocalAddress = nil;
	}
	
	if (reachabilityRef)
		CFRelease(reachabilityRef);
}


- (void)handleNetworkInterfaceUp
{
	LPDebugLog(REACHABILITY_DEBUG, @"Account %@: Interface going UP!", m_account);
	
	if (m_autoReconnectStatus == LPAutoReconnectWaitingForInterfaceToGoUp) {
		if ([m_account status] == LPStatusOffline) {
			// Allow some seconds for things to calm down after the interface has just come up. iChat also does this
			// and it's probably a good idea.
			[self p_setupReconnectTimerWithTimeInterval:5.0];
		}
	}
}


- (void)handleConnectionClosedByServer
{
	LPDebugLog(REACHABILITY_DEBUG, @"Account %@: connection CLOSED by server!", m_account);
	
	// Start trying to connect repeatedly
	[self p_setAutomaticReconnectionStatus:LPAutoReconnectUsingMultipleRetryAttempts];
	
	m_lastOnlineStatus = [m_account targetStatus];
	
	[m_lastOnlineStatusMessage release];
	m_lastOnlineStatusMessage = [[m_account p_statusMessage] copy];
	
	[self p_setupReconnectTimerWithTimeInterval:20.0];
}


- (void)handleConnectionErrorWithName:(NSString *)errorName
{
	LPDebugLog(REACHABILITY_DEBUG, @"Account %@: connection ERROR from server: %@!", m_account, errorName);
	
	if (m_autoReconnectStatus != LPAutoReconnectIdle) {
		// Change our auto-reconnect mode
		[self p_setAutomaticReconnectionStatus:LPAutoReconnectUsingMultipleRetryAttempts];
		
		m_lastOnlineStatus = [m_account targetStatus];
		
		[m_lastOnlineStatusMessage release];
		m_lastOnlineStatusMessage = [[m_account p_statusMessage] copy];
		
		[self p_setupReconnectTimerWithTimeInterval:20.0];
	}
}


- (void)handleConnectionWasReEstablishedSuccessfully
{
	LPDebugLog(REACHABILITY_DEBUG, @"Account %@: connection REESTABLISHED successfully!", m_account);
	
	[self p_setAutomaticReconnectionStatus:LPAutoReconnectIdle];
	[self cancelAllTimers];
	
	[m_lastOnlineStatusMessage release];
	m_lastOnlineStatusMessage = nil;
}


@end



#pragma mark -
#pragma mark LPAccount


// Notifications
NSString *LPAccountWillChangeStatusNotification			= @"LPAccountWillChangeStatusNotification";
NSString *LPAccountDidChangeStatusNotification			= @"LPAccountDidChangeStatusNotification";
NSString *LPAccountDidChangeTransportInfoNotification	= @"LPAccountDidChangeTransportInfoNotification";
NSString *LPAccountDidReceiveXMLStringNotification		= @"LPAccountDidReceiveXMLStringNotification";
NSString *LPAccountDidSendXMLStringNotification			= @"LPAccountDidSendXMLStringNotification";

// Notifications user info dictionary keys
NSString *LPXMLString			= @"LPXMLString";


@implementation LPAccount


+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key
{
	if ([key isEqualToString:@"status"] || [key isEqualToString:@"statusMessage"] || [key isEqualToString:@"avatar"]) {
		return NO;
	} else {
		return [super automaticallyNotifiesObserversForKey:key];
	}
}


+ (void)initialize
{
	if (self == [LPAccount class]) {
		NSArray *statusKeyArray = [NSArray arrayWithObject:@"status"];
		
		[self setKeys:statusKeyArray triggerChangeNotificationsForDependentKey:@"online"];
		[self setKeys:statusKeyArray triggerChangeNotificationsForDependentKey:@"offline"];
		[self setKeys:statusKeyArray triggerChangeNotificationsForDependentKey:@"statusMessage"];
	}
}


- initWithUUID:(NSString *)uuid
{
	return [self initWithUUID:uuid roster:[LPRoster roster]];
}


- initWithUUID:(NSString *)uuid roster:(LPRoster *)roster
{
    if (self = [super init]) {
		m_UUID = [uuid copy];
		
        [self p_setStatus: LPStatusOffline];
        [self p_setStatusMessage: @""];
		[self p_setTargetStatus: LPStatusOffline];
		[self p_setAutomaticReconnectionStatus:LPAutoReconnectIdle];
		
		// Setup the avatar with the last known good image
		NSData *avatarData = [[NSUserDefaults standardUserDefaults] objectForKey:@"Last Known Self Avatar"];
		if (avatarData)
			m_avatar = [[NSUnarchiver unarchiveObjectWithData:avatarData] retain];
		
		[self setEnabled:NO];
		[self setJID:nil];
		[self setLocation:@""];
		[self setLocationUsesComputerName:YES];
		[self setCustomServerHost:@""];
		[self setUsesCustomServerHost:NO];
		[self setUsesSSL:NO];
		
		m_pubManager = [[LPPubManager alloc] init];
		m_transportAgentsRegistrationStatus = [[NSMutableDictionary alloc] init];
		
		m_smsCredit = m_smsNrOfFreeMessages = m_smsTotalSent = LPAccountSMSCreditUnknown;
		
		m_roster = [roster retain];
		
		// Register for notifications that will make us automatically go offline
		[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
															   selector:@selector(workspaceWillSleep:)
																   name:NSWorkspaceWillSleepNotification
																 object:[NSWorkspace sharedWorkspace]];
    }
    return self;
}


- (void)dealloc
{
	[[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
	
	[LFAppController removeAccountWithUUID:[self UUID]];
	
	// Clear the observation of our notifications
	[self setDelegate:nil];
	
	[m_automaticReconnectionContext cancelAllTimers];
	[m_automaticReconnectionContext release];
	
	[m_pubManager release];
	[m_transportAgentsRegistrationStatus release];
	
    [m_UUID release];
	[m_description release];
	[m_name release];
    [m_JID release];
    [m_password release];
    [m_statusMessage release];
	[m_avatar release];
	[m_serverItemsInfo release];
	[m_sapoAgents release];
	[m_sapoChatOrderDict release];
    [m_customServerHost release];
	[m_lastAttemptedServerHost release];
	[m_lastSuccessfullyConnectedServerHost release];
	
	[m_lastRegisteredMSNEmail release];
	[m_lastRegisteredMSNPassword release];
	
	[m_roster release];
	
    [super dealloc];
}


#pragma mark -
#pragma mark Private


- (NSString *)p_computerNameForLocation
{
	// Get the more user-friendly computer name set by the user in the "Sharing" System Preferences
	NSString *location = (NSString *)SCDynamicStoreCopyComputerName(NULL, NULL);
	[location autorelease];
	
	if ([location length] == 0)
		return [[NSProcessInfo processInfo] processName];
	else
		return location;
}

- (void)p_updateLocationFromChangedComputerName
{
	if ([self locationUsesComputerName] && [self isOffline])
		[self setLocation:[self p_computerNameForLocation]];
}


/* This is the actual accessor for this value. The only thing it does is change the value of the "status" attribute
in a KVO-compliant way. */
- (void)p_setStatus:(LPStatus)theStatus
{
	if (m_status != theStatus) {
		NSDictionary *userInfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:theStatus] forKey:@"NewStatus"];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:LPAccountWillChangeStatusNotification
															object:self
														  userInfo:userInfo];
		
		[self willChangeValueForKey:@"status"];
		m_status = theStatus;
		[self didChangeValueForKey:@"status"];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:LPAccountDidChangeStatusNotification
															object:self
														  userInfo:userInfo];
	}
}


/* This is the actual accessor for this value. The only thing it does is change the value of the "statusMessage"
attribute in a KVO-compliant way. */
- (void)p_setStatusMessage:(NSString *)theStatusMessage
{
	if (m_statusMessage != theStatusMessage) {
		[self willChangeValueForKey:@"statusMessage"];
		[m_statusMessage release];
        m_statusMessage = [theStatusMessage copy];
		[self didChangeValueForKey:@"statusMessage"];
	}
}


/* This is the actual accessor for this value. The method -statusMessage: returns the current status message
suitable to be displayed to the user. For example, if the status is Offline, -statusMessage: will always return
@"Offline" while this one actually returns the status message that was last set on this account. */
- (NSString *)p_statusMessage
{
	return m_statusMessage;
}


- (void)p_setTargetStatus:(LPStatus)theStatus
{
	if (m_targetStatus != theStatus) {
		[self willChangeValueForKey:@"targetStatus"];
		m_targetStatus = theStatus;
		[self didChangeValueForKey:@"targetStatus"];
	}
}


- (void)p_setOnlineStatus:(LPStatus)theStatus message:(NSString *)theMessage saveToServer:(BOOL)saveFlag
{
	[self p_setOnlineStatus:theStatus message:theMessage saveToServer:saveFlag alsoSaveStatusMessage:YES];
}


- (void)p_setOnlineStatus:(LPStatus)theStatus message:(NSString *)theMessage saveToServer:(BOOL)saveFlag alsoSaveStatusMessage:(BOOL)saveMsg
{
	if (([self status] == LPStatusOffline) && (theStatus != LPStatusOffline)) {
		// We're going to get connected. Make sure we have a JID defined, at least.
		if ([[self JID] isEqualToString:@""]) {
			if ([m_delegate respondsToSelector:@selector(account:didReceiveErrorNamed:errorKind:errorCode:)]) {
				[m_delegate account:self didReceiveErrorNamed:@"NoJabberIDError" errorKind:0 errorCode:0];
			}
		}
		else {
			// If we use an empty server hostname, then the core will try to discover it using DNS SRV
			NSString *serverHost = ( ( [self p_lastConnectionAttemptDidFail] &&
									   ([[self lastSuccessfullyConnectedServerHost] length] > 0) &&
									   ![[self p_lastAttemptedServerHost] isEqualToString:[self lastSuccessfullyConnectedServerHost]] ) ?
									 [self lastSuccessfullyConnectedServerHost] :
									 ( [self usesCustomServerHost] ? [self customServerHost] : @"") );
			
			if (serverHost == nil) serverHost = @"";
			[self p_setLastAttemptedServerHost:serverHost];
			
			LPDebugLog(REACHABILITY_DEBUG, @"Account %@: opening connection to %@", self, ([serverHost length] > 0 ? serverHost : @"(empty)"));
			
			[LFAppController setAttributesOfAccountWithUUID:[self UUID]
														JID:[self JID]
													   host:serverHost
												   password:[self password]
												   resource:[self location]
													 useSSL:[self usesSSL]];
			
			// Set the custom data transfer proxy only if the user has defined one
			NSString *dataTransferProxy = [[NSUserDefaults standardUserDefaults] objectForKey:@"DataTransferProxy"];
			if (dataTransferProxy && [dataTransferProxy length] > 0)
				[LFAppController setCustomDataTransferProxy:dataTransferProxy];
			
			
			// Reset the server items info and sapo agents info
			NSString *serverHostDomain = ([serverHost length] > 0 ? serverHost : [[self JID] JIDHostnameComponent]);
			
			[self willChangeValueForKey:@"serverItemsInfo"];
			[m_serverItemsInfo release];
			m_serverItemsInfo = [[LPServerItemsInfo alloc] initWithServerHost:serverHostDomain];
			[self didChangeValueForKey:@"serverItemsInfo"];
			
			[self willChangeValueForKey:@"sapoAgents"];
			[m_sapoAgents release];
			m_sapoAgents = [[LPSapoAgents alloc] initWithServerHost:serverHostDomain];
			[self didChangeValueForKey:@"sapoAgents"];
			
			[m_sapoChatOrderDict release]; m_sapoChatOrderDict = nil;
			
			[self p_setLastConnectionAttemptDidFail:NO];
			[self p_setStatus:LPStatusConnecting];
			
			[LFAppController setStatus:LPStatusStringFromStatus(theStatus) message:theMessage
					forAccountWithUUID:[self UUID]
						  saveToServer:saveFlag alsoSaveStatusMessage:saveMsg];
		}
	}
	else {
		[LFAppController setStatus:LPStatusStringFromStatus(theStatus) message:theMessage
				forAccountWithUUID:[self UUID]
					  saveToServer:saveFlag alsoSaveStatusMessage:saveMsg];
	}
}


- (void)p_setAutomaticReconnectionStatus:(LPAutoReconnectStatus)status
{
	if (status != m_automaticReconnectionStatus) {
		[self willChangeValueForKey:@"automaticReconnectionStatus"];
		m_automaticReconnectionStatus = status;
		[self didChangeValueForKey:@"automaticReconnectionStatus"];
	}
}


/* This is the actual accessor for this value. The only thing it does is change the value of the "avatar"
attribute in a KVO-compliant way. */
- (void)p_setAvatar:(NSImage *)avatar
{
	if (m_avatar != avatar) {
		[self willChangeValueForKey:@"avatar"];
		[m_avatar release];
		m_avatar = [avatar retain];
		[self didChangeValueForKey:@"avatar"];
		
		if (avatar) {
			// Save it in the user defaults as the last known good avatar
			NSData *archivedImage = [NSArchiver archivedDataWithRootObject:avatar];
			[[NSUserDefaults standardUserDefaults] setObject:archivedImage forKey:@"Last Known Self Avatar"];
		}
		else {
			[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"Last Known Self Avatar"];
		}
	}
}


- (void)p_changeAndAnnounceAvatar:(NSImage *)avatar
{
	NSData *pngImageData = nil;
	
	if (avatar) {
		NSBitmapImageRep *bitmapRepresentation = [NSBitmapImageRep imageRepWithData:[avatar TIFFRepresentation]];
		pngImageData = [bitmapRepresentation representationUsingType:NSPNGFileType properties:nil];
	}
	
	// Send the image data to the core
	[LFAppController avatarPublish:pngImageData type:@"PNG"];
}


- (void)p_setSMSCredit:(int)credit freeMessages:(int)freeMsgs totalSent:(int)totalSent
{
	[self willChangeValueForKey:@"SMSCreditValues"];
	m_smsCredit = credit;
	m_smsNrOfFreeMessages = freeMsgs;
	m_smsTotalSent = totalSent;
	[self didChangeValueForKey:@"SMSCreditValues"];
}


#pragma mark -
#pragma mark Accessors


- (NSString *)UUID
{
    return [[m_UUID copy] autorelease]; 
}


- (NSString *)description
{
	return [[m_description copy] autorelease]; 
}

- (void)setDescription:(NSString *)theDescription
{
    if (m_description != theDescription) {
        [m_description release];
        m_description = [theDescription copy];
    }
}

- (BOOL)validateDescription:(id *)ioValue error:(NSError **)outError
{
	if ([*ioValue length] == 0)
		*ioValue = [self JID];
	return YES;
}


- (BOOL)isEnabled
{
	return m_enabled;
}

- (void)setEnabled:(BOOL)enabled
{
	m_enabled = enabled;
}


- (NSString *)name
{
    return [[m_name copy] autorelease]; 
}

- (void)setName:(NSString *)theName
{
    if (m_name != theName) {
        [m_name release];
        m_name = [theName copy];
    }
}


- (NSString *)JID
{
    return [[m_JID copy] autorelease]; 
}

- (void)setJID:(NSString *)theJID
{
    if (m_JID != theJID) {
		NSString *oldHostname = [m_JID JIDHostnameComponent];
		
 		// The description should be the same as the JID, unless it has already been customized.
		if ([m_description length] == 0 || [m_description isEqualToString:m_JID])
			[self setDescription:theJID];
		
		[m_JID release];
        m_JID = [theJID copy];
		
		if (![oldHostname isEqualToString:[m_JID JIDHostnameComponent]]) {
			[self p_setLastConnectionAttemptDidFail:NO];
			[self setLastSuccessfullyConnectedServerHost:nil];
		}
    }
}


- (NSString *)password
{
    return [[m_password copy] autorelease]; 
}

- (void)setPassword:(NSString *)thePassword
{
    if (m_password != thePassword) {
        [m_password release];
        m_password = [thePassword copy];
    }
}


- (NSString *)location
{
	return [[m_location copy] autorelease];
}

- (void)setLocation:(NSString *)theLocation
{
	if (m_location != theLocation) {
		[m_location release];
		m_location = [theLocation copy];
	}
}

- (BOOL)validateLocation:(id *)ioValue error:(NSError **)outError
{
	if (*ioValue == nil)
		*ioValue = @"";
	return YES;
}


- (NSString *)customServerHost
{
    return [[m_customServerHost copy] autorelease]; 
}

- (void)setCustomServerHost:(NSString *)theServerHost
{
    if (m_customServerHost != theServerHost) {
        [m_customServerHost release];
        m_customServerHost = [theServerHost copy];
		
		if ([self usesCustomServerHost]) {
			[self p_setLastConnectionAttemptDidFail:NO];
			[self setLastSuccessfullyConnectedServerHost:nil];
		}
    }
}


- (BOOL)usesCustomServerHost
{
    return m_usesCustomServerHost;
}

- (void)setUsesCustomServerHost:(BOOL)flag
{
	if (m_usesCustomServerHost != flag) {
		[self p_setLastConnectionAttemptDidFail:NO];
		[self setLastSuccessfullyConnectedServerHost:nil];
	}
	
    m_usesCustomServerHost = flag;
}


- (BOOL)usesSSL
{
    return m_usesSSL;
}

- (void)setUsesSSL:(BOOL)flag
{
    m_usesSSL = flag;
}


- (BOOL)locationUsesComputerName
{
	return m_locationUsesComputerName;
}

- (void)setLocationUsesComputerName:(BOOL)flag
{
	// Was it just changed from OFF to ON?
	if (!m_locationUsesComputerName && flag)
		[self setLocation:[self p_computerNameForLocation]];
	
	m_locationUsesComputerName = flag;
}


- (NSString *)p_lastAttemptedServerHost
{
	return [[m_lastAttemptedServerHost copy] autorelease];
}

- (void)p_setLastAttemptedServerHost:(NSString *)host
{
	if (host != m_lastAttemptedServerHost) {
		[m_lastAttemptedServerHost release];
		m_lastAttemptedServerHost = [host copy];
	}
}


- (NSString *)lastSuccessfullyConnectedServerHost
{
	return [[m_lastSuccessfullyConnectedServerHost copy] autorelease];
}

- (void)setLastSuccessfullyConnectedServerHost:(NSString *)host
{
	if (host != m_lastSuccessfullyConnectedServerHost) {
		[m_lastSuccessfullyConnectedServerHost release];
		m_lastSuccessfullyConnectedServerHost = [host copy];
	}
}


- (BOOL)p_lastConnectionAttemptDidFail
{
	return m_lastConnectionAttemptDidFail;
}

- (void)p_setLastConnectionAttemptDidFail:(BOOL)flag
{
	m_lastConnectionAttemptDidFail = flag;
}


- (NSString *)lastRegisteredMSNEmail
{
	return [[m_lastRegisteredMSNEmail copy] autorelease];
}

- (void)setLastRegisteredMSNEmail:(NSString *)username
{
	if (m_lastRegisteredMSNEmail != username) {
		[m_lastRegisteredMSNEmail release];
		m_lastRegisteredMSNEmail = [username copy];
	}
}

- (NSString *)lastRegisteredMSNPassword
{
	return [[m_lastRegisteredMSNPassword copy] autorelease];
}

- (void)setLastRegisteredMSNPassword:(NSString *)password
{
	if (m_lastRegisteredMSNPassword != password) {
		[m_lastRegisteredMSNPassword release];
		m_lastRegisteredMSNPassword = [password copy];
	}
}


- (void)registerWithTransportAgent:(NSString *)transportAgent username:(NSString *)username password:(NSString *)password
{
	if ([self isOnline]) {
		[self setLastRegisteredMSNEmail:username];
		[self setLastRegisteredMSNPassword:password];
		
		[LFAppController transportRegister:transportAgent username:username password:password onAccountWithUUID:[self UUID]];
	}
}

- (void)unregisterWithTransportAgent:(NSString *)transportAgent
{
	if ([self isOnline]) {
		[LFAppController transportUnregister:transportAgent onAccountWithUUID:[self UUID]];
	}
}


- (NSString *)usernameRegisteredWithTransportAgent:(NSString *)transportAgent
{
	return [[m_transportAgentsRegistrationStatus objectForKey:transportAgent] objectForKey:@"username"];
}

- (BOOL)isRegisteredWithTransportAgent:(NSString *)transportAgent
{
	return [[[m_transportAgentsRegistrationStatus objectForKey:transportAgent] objectForKey:@"isRegistered"] boolValue];
}

- (BOOL)isLoggedInWithTransportAgent:(NSString *)transportAgent
{
	return [[[m_transportAgentsRegistrationStatus objectForKey:transportAgent] objectForKey:@"isLoggedIn"] boolValue];
}


#pragma mark -


- (LPStatus)status
{
    return m_status; 
}

- (NSString *)statusMessage
{
	LPStatus myStatus = [self status];
	NSString *actualStatusMessage = [self p_statusMessage];
	
	if (myStatus == LPStatusConnecting) {
		// Return the default built-in status message for the current status
		return NSLocalizedStringFromTable( LPStatusStringFromStatus(myStatus), @"Status", @"" );
	}
	else {
		return [actualStatusMessage prettyStatusString];
	}
}

- (void)setStatusMessage:(NSString *)theStatusMessage
{
	if ([self isOnline])
		[self setStatusMessage:theStatusMessage saveToServer:YES];
}


- (void)setStatusMessage:(NSString *)theStatusMessage saveToServer:(BOOL)saveFlag
{
	if ([self isOnline])
		[self setTargetStatus:[self targetStatus] message:theStatusMessage
				 saveToServer:saveFlag alsoSaveStatusMessage:YES];
}


- (LPStatus)targetStatus
{
	return m_targetStatus;
}


- (void)setTargetStatus:(LPStatus)theStatus
{
	[self setTargetStatus:theStatus saveToServer:YES];
}


- (void)setTargetStatus:(LPStatus)theStatus saveToServer:(BOOL)saveFlag
{
	[self setTargetStatus:theStatus message:[self p_statusMessage] saveToServer:saveFlag alsoSaveStatusMessage:NO];
}


- (void)setTargetStatus:(LPStatus)theStatus message:(NSString *)theMessage saveToServer:(BOOL)saveFlag
{
	[self setTargetStatus:theStatus message:theMessage saveToServer:saveFlag alsoSaveStatusMessage:YES];
}


- (void)setTargetStatus:(LPStatus)theStatus message:(NSString *)theMessage saveToServer:(BOOL)saveFlag alsoSaveStatusMessage:(BOOL)saveMsg
{
	if (theStatus == LPStatusOffline) {
		[m_automaticReconnectionContext cancelAllTimers];
		[m_automaticReconnectionContext release];
		m_automaticReconnectionContext = nil;
		
		[self p_setAutomaticReconnectionStatus:LPAutoReconnectIdle];
	}
	
	[self p_setTargetStatus:theStatus];
	[self p_setOnlineStatus:theStatus message:theMessage saveToServer:saveFlag alsoSaveStatusMessage:saveMsg];
}

- (BOOL)isOnline
{
	LPStatus myStatus = [self status];
    return ((myStatus != LPStatusOffline) && (myStatus != LPStatusConnecting));
}


- (BOOL)isOffline
{
	return ([self status] == LPStatusOffline);
}


- (BOOL)isDebugger
{
	return m_isDebugger;
}


- (BOOL)isTryingToAutoReconnect
{
	return [m_automaticReconnectionContext isInTheMidstOfAutomaticReconnection];
}


- (LPAutoReconnectStatus)automaticReconnectionStatus
{
	return m_automaticReconnectionStatus;
}


- (NSImage *)avatar
{
	if (m_avatar)
		return [[m_avatar retain] autorelease];
	else
		return [NSImage imageNamed:@"defaultAvatar"];
}

- (void)setAvatar:(NSImage *)avatar
{
	[self p_setAvatar:avatar];
	
	if ([self isOnline])
		[self p_changeAndAnnounceAvatar:avatar];
}

- (LPServerItemsInfo *)serverItemsInfo
{
	return [[m_serverItemsInfo retain] autorelease];
}

- (LPSapoAgents *)sapoAgents
{
	return [[m_sapoAgents retain] autorelease];
}

- (NSDictionary *)sapoChatOrderDictionary
{
	return [[m_sapoChatOrderDict retain] autorelease];
}

- (LPPubManager *)pubManager
{
	return [[m_pubManager retain] autorelease];
}

- (int)SMSCreditAvailable
{
	return m_smsCredit;
}


- (int)nrOfFreeSMSMessagesAvailable
{
	return m_smsNrOfFreeMessages;
}


- (int)nrOfSMSMessagesSentThisMonth
{
	return m_smsTotalSent;
}


- (id)delegate
{
	return m_delegate;
}

- (void)setDelegate:(id)delegate
{
	NSNotificationCenter *notifCenter = [NSNotificationCenter defaultCenter];
	
	[notifCenter removeObserver:m_delegate name:LPAccountWillChangeStatusNotification object:self];
	[notifCenter removeObserver:m_delegate name:LPAccountDidChangeStatusNotification object:self];
	[notifCenter removeObserver:m_delegate name:LPAccountDidChangeTransportInfoNotification object:self];
	[notifCenter removeObserver:m_delegate name:LPAccountDidReceiveXMLStringNotification object:self];
	[notifCenter removeObserver:m_delegate name:LPAccountDidSendXMLStringNotification object:self];
	
	m_delegate = delegate;
	
	if ([m_delegate respondsToSelector:@selector(accountWillChangeStatus:)]) {
		[notifCenter addObserver:m_delegate
						selector:@selector(accountWillChangeStatus:)
							name:LPAccountWillChangeStatusNotification
						  object:self];
	}
	if ([m_delegate respondsToSelector:@selector(accountDidChangeStatus:)]) {
		[notifCenter addObserver:m_delegate
						selector:@selector(accountDidChangeStatus:)
							name:LPAccountDidChangeStatusNotification
						  object:self];
	}
	if ([m_delegate respondsToSelector:@selector(accountDidChangeTransportInfo:)]) {
		[notifCenter addObserver:m_delegate
						selector:@selector(accountDidChangeTransportInfo:)
							name:LPAccountDidChangeTransportInfoNotification
						  object:self];
	}
	if ([m_delegate respondsToSelector:@selector(accountDidReceiveXMLString:)]) {
		[notifCenter addObserver:m_delegate
						selector:@selector(accountDidReceiveXMLString:)
							name:LPAccountDidReceiveXMLStringNotification
						  object:self];
	}
	if ([m_delegate respondsToSelector:@selector(accountDidSendXMLString:)]) {
		[notifCenter addObserver:m_delegate
						selector:@selector(accountDidSendXMLString:)
							name:LPAccountDidSendXMLStringNotification
						  object:self];
	}
}


- (LPRoster *)roster
{
	return [[m_roster retain] autorelease];
}


- (void)sendXMLString:(NSString *)str
{
	[LFAppController accountSendXml:[self UUID] :str];
}


#pragma mark -
#pragma mark NSWorkspace Notifications


- (void)workspaceWillSleep:(NSNotification *)notification
{
	[m_automaticReconnectionContext handleNetworkInterfaceDown];
}


@end


#pragma mark -


@implementation LPAccount (AccountsControllerInterface)

- (void)handleAccountConnectedToServerUsingLocalAddress:(NSString *)localAddress remoteAddress:(NSString *)remoteAddress
{
	LPDebugLog(REACHABILITY_DEBUG, @"Account %@: CONNECTED TO SERVER WITH ADDRESS PAIR: local: %@ / remote: %@",
			   self, localAddress, remoteAddress);
	
	[self setLastSuccessfullyConnectedServerHost:remoteAddress];
	
	if (m_automaticReconnectionContext == nil) {
		m_automaticReconnectionContext = [[LPAccountAutomaticReconnectionContext alloc] initForObservingConnectionWithLocalAddress:localAddress
																													 remoteAddress:remoteAddress
																														   account:self];
	} else {
		/*
		 * Always update the hostname being observed by our auto-reconnect manager, even if we're always connecting to the
		 * same server. We may be receiving an IP address from the core in the 'serverHost' argument, and if the server hostname
		 * is associated with several different IP addresses we may have been connected to a different IP address this time.
		 */
		[m_automaticReconnectionContext setObservedConnectionWithLocalAddress:localAddress remoteAddress:remoteAddress];
	}
}

- (void)handleConnectionErrorWithName:(NSString *)errorName kind:(int)errorKind code:(int)errorCode
{
	BOOL propagateConnectionError = YES;
	static NSSet *recoverableConnectionErrors = nil;
	
	if (recoverableConnectionErrors == nil) {
		recoverableConnectionErrors = [[NSSet alloc] initWithObjects:@"GenericStreamError",
									   @"ConnectionTimeout", @"ConnectionRefused",
									   @"HostNotFound", @"UnknownHost", @"ProxyConnectionError", nil];
	}
	
	BOOL		gotRecoverableError = (errorName != nil && [recoverableConnectionErrors containsObject:errorName]);
	NSString	*lastSuccessfullyConnectedServerHost = [self lastSuccessfullyConnectedServerHost];
	
	// Can we try to recover from this error by trying to connect to our last known good server?
	if (gotRecoverableError) {
		[self p_setLastConnectionAttemptDidFail:YES];
		
		// Have we still not attempted yet to connect to the last successfully connected server host?
		if ([lastSuccessfullyConnectedServerHost length] > 0 &&
			![[self p_lastAttemptedServerHost] isEqualToString:lastSuccessfullyConnectedServerHost])
		{
			LPDebugLog(REACHABILITY_DEBUG,
					   @"Last connection attempt for account \"%@\" has failed. We will retry using the last server hostname"
					   @" that was known to work: %@",
					   self, [self lastSuccessfullyConnectedServerHost]);
			
			// Retry with the last known good server (it will be selected automatically)
			LPStatus status = [self targetStatus];
			
			NSInvocation *inv = [NSInvocation invocationWithMethodSignature:[self methodSignatureForSelector:@selector(setTargetStatus:)]];
			
			[inv setTarget:self];
			[inv setSelector:@selector(setTargetStatus:)];
			[inv setArgument:&status atIndex:2];
			[inv retainArguments];
			
			[inv performSelector:@selector(invoke) withObject:nil afterDelay:0.0];
			
			propagateConnectionError = NO;
		}
	}
	
	
	if (propagateConnectionError) {
		if ([m_automaticReconnectionContext isInTheMidstOfAutomaticReconnection]) {
			
			LPDebugLog(REACHABILITY_DEBUG, @"Account %@: passing connection error to auto-reconnect-context.", self);
			
			// Don't let the error reach the user-interface layer and notify our automatic reconnection context about the error
			// so that it can autonomously decide what to do next.
			[m_automaticReconnectionContext handleConnectionErrorWithName:errorName];
		}
		else {
			if (gotRecoverableError &&
				// Was our last connect attempt directed at the last successfully connected server host?
				([lastSuccessfullyConnectedServerHost length] > 0 &&
				 [[self p_lastAttemptedServerHost] isEqualToString:lastSuccessfullyConnectedServerHost])) {
				
				LPDebugLog(REACHABILITY_DEBUG,
						   @"Account %@: passing connection closed event to auto-reconnect-context after "
						   @"getting an error.", self);
				
				// Silently kick-off our automatic reconnection process if the connection was unexpectedly closed by the server
				[m_automaticReconnectionContext handleConnectionClosedByServer];
			}
			else {
				// Notify the delegate so that the error can be displayed to the user
				if ([m_delegate respondsToSelector:@selector(account:didReceiveErrorNamed:errorKind:errorCode:)]) {
					[m_delegate account:self didReceiveErrorNamed:errorName errorKind:errorKind errorCode:errorCode];
				}
			}
		}
	}
}

- (void)handleStatusUpdated:(NSString *)status message:(NSString *)statusMessage
{
	LPStatus myNewStatus = LPStatusFromStatusString(status);
	
	[self p_setStatus:myNewStatus];
	[self p_setStatusMessage:statusMessage];
	
	if ([m_automaticReconnectionContext isInTheMidstOfAutomaticReconnection] && myNewStatus != LPStatusOffline) {
		[m_automaticReconnectionContext handleConnectionWasReEstablishedSuccessfully];
	}
	
	// Update the location name if we need to (because the computer name may have changed, but we shouldn't modify the
	// location name while we're online as it is used for the jabber resource).
	if (myNewStatus == LPStatusOffline && [self locationUsesComputerName]) {
		NSString *computerName = [self p_computerNameForLocation];
		if (![computerName isEqualToString:[self location]]) {
			[self setLocation:computerName];
		}
	}
}

- (void)handleSavedStatusReceived:(NSString *)status message:(NSString *)statusMessage
{
	if ([m_delegate respondsToSelector:@selector(account:didReceiveSavedStatus:message:)]) {
		[m_delegate account:self didReceiveSavedStatus:LPStatusFromStatusString(status) message:statusMessage];
	}
}

- (void)handleSelfAvatarChangedWithType:(NSString *)type data:(NSData *)avatarData
{
	NSImage *avatarImage = [[NSImage alloc] initWithData:avatarData];
	
	[self p_setAvatar:avatarImage];
	[avatarImage release];
}

- (void)handleServerItemsUpdated:(NSArray *)items
{
	[m_serverItemsInfo handleServerItemsUpdated:items];
}

- (void)handleInfoUpdatedForServerItem:(NSString *)item withName:(NSString *)name identities:(NSArray *)identities features:(NSArray *)features
{
	[m_serverItemsInfo handleInfoUpdatedForServerItem:item withName:name identities:identities features:features];
}

- (void)handleSapoAgentsUpdated:(NSDictionary *)sapoAgents
{
	[m_sapoAgents handleSapoAgentsUpdated:sapoAgents];
}

- (void)handleAccountXmlIO:(NSString *)xml isInbound:(BOOL)isInbound
{
	[[NSNotificationCenter defaultCenter] postNotificationName:( isInbound ?
																 LPAccountDidReceiveXMLStringNotification :
																 LPAccountDidSendXMLStringNotification )
														object:self
													  userInfo:[NSDictionary dictionaryWithObject:xml forKey:LPXMLString]];
}

- (void)handleReceivedOfflineMessageAt:(NSString *)timestamp fromJID:(NSString *)jid nickname:(NSString *)nick subject:(NSString *)subject plainTextMessage:(NSString *)plainTextMessage XHTMLMessaage:(NSString *)XHTMLMessage URLs:(NSArray *)URLs
{
	if ([m_delegate respondsToSelector:@selector(account:didReceiveOfflineMessageFromJID:nick:timestamp:subject:plainTextVariant:XHTMLVariant:URLs:)]) {
		[m_delegate account:self didReceiveOfflineMessageFromJID:jid nick:nick timestamp:timestamp subject:subject plainTextVariant:plainTextMessage XHTMLVariant:XHTMLMessage URLs:URLs];
	}
}

- (void)handleReceivedHeadlineNotificationMessageFromChannel:(NSString *)channel itemURL:(NSString *)item_url flashURL:(NSString *)flash_url iconURL:(NSString *)icon_url nickname:(NSString *)nick subject:(NSString *)subject plainTextMessage:(NSString *)plainTextMessage XHTMLMessage:(NSString *)XHTMLMessage
{
	if ([m_delegate respondsToSelector:@selector(account:didReceiveHeadlineNotificationMessageFromChannel:subject:body:itemURL:flashURL:iconURL:)]) {
		
#warning We're trimming whitespace just because of the notifications from JN, which always start with a bunch of spaces.
		NSString *trimmedSubject = [subject stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		
		[m_delegate account:self didReceiveHeadlineNotificationMessageFromChannel:channel
					subject:trimmedSubject body:plainTextMessage itemURL:item_url flashURL:flash_url iconURL:icon_url];
	}
}

- (void)handleReceivedInvitationToGroupChat:(NSString *)roomJID from:(NSString *)sender reason:(NSString *)reason password:(NSString *)password
{
	if ([m_delegate respondsToSelector:@selector(account:didReceiveInvitationToRoomWithJID:from:reason:password:)]) {
		[m_delegate account:self didReceiveInvitationToRoomWithJID:roomJID from:sender reason:reason password:password];
	}
}

- (void)handleSMSCreditUpdated:(int)credit freeMessages:(int)free_msgs totalSent:(int)total_sent_this_month
{
	[self p_setSMSCredit:credit freeMessages:free_msgs totalSent:total_sent_this_month];
}

- (void)handleSMSSentWithResult:(int)result nrUsedMessages:(int)nr_used_msgs nrUsedChars:(int)nr_used_chars
			 destinationPhoneNr:(NSString *)destination_phone_nr body:(NSString *)body
						 credit:(int)credit freeMessages:(int)free_msgs totalSent:(int)total_sent_this_month
{
	NSString		*theJID = [[destination_phone_nr userPresentablePhoneNrRepresentation] internalPhoneJIDRepresentation];
	NSString		*address = [theJID bareJIDComponent];
	LPContactEntry	*entry = [[self roster] contactEntryForAddress:address account:self];
	
	NSAssert1(entry != nil, @"handleSMSSentWithResult:... JID <%@> isn't in the roster (not even invisible).", theJID);
	
	[[[LPChatsManager chatsManager] existingChatOrMakeNewWithContact:[entry contact]] handleResultOfSMSSentTo:theJID
																									 withBody:body
																								   resultCode:result
																								   nrUsedMsgs:nr_used_msgs
																								  nrUsedChars:nr_used_chars
																									newCredit:credit
																							  newFreeMessages:free_msgs
																						newTotalSentThisMonth:total_sent_this_month];
	
	// Also update the global credit if we can
	if (credit >= 0)
		[self handleSMSCreditUpdated:credit freeMessages:free_msgs totalSent:total_sent_this_month];
}

- (void)handleSMSReceivedAt:(NSString *)date_received fromPhoneNr:(NSString *)source_phone_nr body:(NSString *)body
					 credit:(int)credit freeMessages:(int)free_msgs totalSent:(int)total_sent_this_month
{
	NSString		*theJID = [[source_phone_nr userPresentablePhoneNrRepresentation] internalPhoneJIDRepresentation];
	NSString		*address = [theJID bareJIDComponent];
	LPContactEntry	*entry = [[self roster] contactEntryForAddress:address account:self];
	
	NSAssert1(entry != nil, @"handleSMSReceivedAt:... JID <%@> isn't in the roster (not even invisible).", theJID);
	
	[[[LPChatsManager chatsManager] existingChatOrMakeNewWithContact:[entry contact]] handleSMSReceivedFrom:theJID
																								   withBody:body
																								 dateString:date_received
																								  newCredit:credit
																							newFreeMessages:free_msgs
																					  newTotalSentThisMonth:total_sent_this_month];
	
	// Also update the global credit if we can
	if (credit >= 0)
		[self handleSMSCreditUpdated:credit freeMessages:free_msgs totalSent:total_sent_this_month];
}


//- (void)leapfrogBridge_serverItemsUpdated:(NSArray *)serverItems
//{
//	[m_serverItemsInfo handleServerItemsUpdated:serverItems];
//}
//
//
//- (void)leapfrogBridge_serverItemInfoUpdated:(NSString *)item :(NSString *)name :(NSArray *)features
//{
//	[m_serverItemsInfo handleInfoUpdatedForServerItem:item withName:name features:features];
//}
//
//
//- (void)leapfrogBridge_sapoAgentsUpdated:(NSDictionary *)sapoAgentsDescription
//{
//	[m_sapoAgents handleSapoAgentsUpdated:sapoAgentsDescription];
//}
//
//
//- (void)leapfrogBridge_chatRoomsListReceived:(NSString *)host :(NSArray *)roomsList
//{
//	// DEBUG
//	//NSLog(@"MUC ITEMS UPDATED:\nHost: %@\nRooms: %@\n", host, roomsList);
//	
//	if ([m_delegate respondsToSelector:@selector(account:didReceiveChatRoomsList:forHost:)]) {
//		[m_delegate account:self didReceiveChatRoomsList:roomsList forHost:host];
//	}
//}
//
//
//- (void)leapfrogBridge_chatRoomInfoReceived:(NSString *)roomJID :(NSDictionary *)infoDict
//{
//	// DEBUG
//	//NSLog(@"MUC ITEM INFO UPDATED:\nRoom JID: %@\nInfo: %@\n", roomJID, infoDict);
//	
//	if ([m_delegate respondsToSelector:@selector(account:didReceiveInfo:forChatRoomWithJID:)]) {
//		[m_delegate account:self didReceiveInfo:infoDict forChatRoomWithJID:roomJID];
//	}
//}


- (void)handleReceivedLiveUpdateURLString:(NSString *)urlString
{
	if ([m_delegate respondsToSelector:@selector(account:didReceiveLiveUpdateURL:)]) {
		[m_delegate account:self didReceiveLiveUpdateURL:urlString];
	}
}

- (void)handleReceivedSapoChatOrderDictionary:(NSDictionary *)orderDict
{
	[m_sapoChatOrderDict release];
	m_sapoChatOrderDict = [orderDict copy];
}

- (void)handleTransportRegistrationStatusUpdatedForAgent:(NSString *)transportAgent
											isRegistered:(BOOL)isRegistered
												username:(NSString *)registeredUsername
{
	NSMutableDictionary *statusDict = [m_transportAgentsRegistrationStatus objectForKey:transportAgent];
	
	if (statusDict == nil) {
		statusDict = [NSMutableDictionary dictionary];
		[m_transportAgentsRegistrationStatus setObject:statusDict forKey:transportAgent];
	}
	
	[statusDict setObject:[NSNumber numberWithBool:isRegistered] forKey:@"isRegistered"];
	[statusDict setObject:registeredUsername forKey:@"username"];
	
	// Notify observers about the change
	NSDictionary *userInfo = [NSDictionary dictionaryWithObject:transportAgent forKey:@"TransportAgent"];
	[[NSNotificationCenter defaultCenter] postNotificationName:LPAccountDidChangeTransportInfoNotification
														object:self
													  userInfo:userInfo];
}

- (void)handleTransportLoggedInStatusUpdatedForAgent:(NSString *)transportAgent isLoggedIn:(BOOL)isLoggedIn
{
	NSMutableDictionary *statusDict = [m_transportAgentsRegistrationStatus objectForKey:transportAgent];
	
	if (statusDict == nil) {
		statusDict = [NSMutableDictionary dictionary];
		[m_transportAgentsRegistrationStatus setObject:statusDict forKey:transportAgent];
	}
	
	[statusDict setObject:[NSNumber numberWithBool:isLoggedIn] forKey:@"isLoggedIn"];
	
	// Notify observers about the change
	NSDictionary *userInfo = [NSDictionary dictionaryWithObject:transportAgent forKey:@"TransportAgent"];
	[[NSNotificationCenter defaultCenter] postNotificationName:LPAccountDidChangeTransportInfoNotification
														object:self
													  userInfo:userInfo];
}

- (void)handleReceivedServerVarsDictionary:(NSDictionary *)varsDict
{
	[m_pubManager handleUpdatedServerVars:varsDict];
	
	if ([m_delegate respondsToSelector:@selector(account:didReceiveServerVarsDictionary:)]) {
		[m_delegate account:self didReceiveServerVarsDictionary:varsDict];
	}
}

- (void)handleSelfVCardChanged:(NSDictionary *)vCard
{
	NSString *fullname = [vCard objectForKey:@"fullname"];
	NSString *firstName = [vCard objectForKey:@"given"];
	NSString *lastName = [vCard objectForKey:@"family"];
	NSString *nickname = [vCard objectForKey:@"nickname"];
	
	NSString *resultingAccountName = nil;
	
	if ([fullname length] > 0) {
		resultingAccountName = fullname;
	}
	else if ([firstName length] > 0 && [lastName length] > 0) {
		resultingAccountName = [NSString stringWithFormat:@"%@ %@", firstName, lastName];
	}
	else if ([firstName length] > 0) {
		resultingAccountName = firstName;
	}
	else if ([lastName length] > 0) {
		resultingAccountName = lastName;
	}
	else if ([nickname length] > 0) {
		resultingAccountName = nickname;
	}
	
	if ([resultingAccountName length] > 0)
		[self setName:resultingAccountName];
}

- (void)handleDebuggerStatusChanged:(BOOL)isDebugger
{
	[self willChangeValueForKey:@"debugger"];
	m_isDebugger = isDebugger;
	[self didChangeValueForKey:@"debugger"];
}

@end
