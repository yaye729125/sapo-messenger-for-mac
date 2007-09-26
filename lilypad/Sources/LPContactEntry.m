//
//  LPContactEntry.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <QuartzCore/CoreImage.h>

#import "LPContactEntry.h"
#import "LPContact.h"
#import "LPRoster.h"
#import "LPAccountsController.h"
#import "LPAccount.h"
#import "LPServerItemsInfo.h"
#import "LPSapoAgents.h"
#import "LFAppController.h"
#import "NSString+JIDAdditions.h"
#import "NSImage+AvatarAdditions.h"


@implementation LPContactEntry

+ (void)initialize
{
	[self setKeys:[NSArray arrayWithObject:@"address"]
			triggerChangeNotificationsForDependentKey:@"humanReadableAddress"];
	[self setKeys:[NSArray arrayWithObject:@"status"]
			triggerChangeNotificationsForDependentKey:@"online"];
	[self setKeys:[NSArray arrayWithObjects:@"status", @"online", nil]
			triggerChangeNotificationsForDependentKey:@"avatar"];
	[self setKeys:[NSArray arrayWithObjects:@"status", @"online", nil]
			triggerChangeNotificationsForDependentKey:@"framedAvatar"];
	[self setKeys:[NSArray arrayWithObject:@"availableResources"]
			triggerChangeNotificationsForDependentKey:@"allResourcesDescription"];
	
	// We don't need to do this for the statusMessage key because it is always modified when the status is modified
	// in handlePresenceChangedWithStatus:statusMessage:
	// [self setKeys:[NSArray arrayWithObject:@"status"] triggerChangeNotificationsForDependentKey:@"statusMessage"];
}


+ entryWithAddress:(NSString *)address account:(LPAccount *)account
{
	return [[[[self class] alloc] initWithAddress:address account:account] autorelease];
}

// Designated initializer
- initWithAddress:(NSString *)address account:(LPAccount *)account
{
	if (self = [super init]) {
		m_account = [account retain];
		m_address = [address copy];
		m_status = LPStatusOffline;
		m_statusMessage = [@"" copy];
		m_availableResources = [[NSArray alloc] init];
		m_capsFeaturesByResource = [[NSMutableDictionary alloc] init];
		m_resourcesClientInfo = [[NSMutableDictionary alloc] init];
	}
	return self;
}

- init
{
	return [self initWithAddress:nil account:nil];
}

- (void)dealloc
{
	[m_account release];
	[m_address release];
	[m_subscription release];
	[m_avatar release];
	[m_cachedOfflineAvatar release];
	[m_statusMessage release];
	[m_contact release];
	[m_availableResources release];
	[m_capsFeaturesByResource release];
	[m_resourcesClientInfo release];
	[super dealloc];
}

- (LPAccount *)account
{
	return [[m_account retain] autorelease];
}

- (NSString *)address
{
	return [[m_address copy] autorelease];
}

- (NSString *)humanReadableAddress
{
	NSString *address = nil;
	
	if ([m_address isPhoneJID]) {
		address = [m_address userPresentablePhoneNrRepresentation];
	}
	else {
		NSDictionary *sapoAgents = [[[self account] sapoAgents] dictionaryRepresentation];
		address = [m_address userPresentableJIDAsPerAgentsDictionary:sapoAgents];
	}
	
	/* Temporary fix to be able to see the account associated with each JID. */
	return [NSString stringWithFormat:@"%@    (account \"%@\")", address, [[self account] description]];
}

- (NSString *)subscription
{
	return [[m_subscription copy] autorelease];
}

- (BOOL)isWaitingForAuthorization
{
	return m_waitingForAuthorization;
}

- (LPContact *)contact
{
	return [[m_contact retain] autorelease];
}

- (void)moveToContact:(LPContact *)destination
{
	[LFAppController rosterEntryChangeContact:[self ID] origin:[[self contact] ID] destination:[destination ID]];
}

#pragma mark Avatar

- (BOOL)hasCustomAvatar
{
	return (m_avatar != nil);
}

- (NSImage *)onlineAvatar
{
	if (m_avatar)
		return [[m_avatar retain] autorelease];
	else
		return [NSImage imageNamed:@"defaultAvatar"];
}

- (NSImage *)offlineAvatar
{
	if (m_cachedOfflineAvatar == nil) {
		NSImage *avatar = [self onlineAvatar];
		NSData *avatarImageData = [avatar TIFFRepresentation];
		CIImage *img = [[[CIImage alloc] initWithData:avatarImageData] autorelease];
		
		// Apply the filters
		CIImage *result;
		CIFilter *filter1 = [CIFilter filterWithName:@"CIColorControls"];
		[filter1 setDefaults];
		[filter1 setValue:img forKey:@"inputImage"];
		[filter1 setValue:[NSNumber numberWithFloat:0.0] forKey:@"inputSaturation"];
		[filter1 setValue:[NSNumber numberWithFloat:0.2] forKey:@"inputBrightness"];
		result = [filter1 valueForKey:@"outputImage"];
		
		//	CIFilter *filter2 = [CIFilter filterWithName:@"CIGaussianBlur"];
		//	[filter2 setDefaults];
		//	[filter2 setValue:result forKey:@"inputImage"];
		//	[filter2 setValue:[NSNumber numberWithFloat:0.7] forKey:@"inputRadius"];
		//	result = [filter2 valueForKey:@"outputImage"];
		
		NSCIImageRep *newBitmap = [NSCIImageRep imageRepWithCIImage:result];
		
		m_cachedOfflineAvatar = [[NSImage alloc] initWithSize:[avatar size]];
		[m_cachedOfflineAvatar addRepresentation:newBitmap];
	}
	
	return [[m_cachedOfflineAvatar retain] autorelease];
}

- (NSImage *)avatar
{
	return ([self isOnline] ? [self onlineAvatar] : [self offlineAvatar]);
}

- (NSImage *)framedAvatar
{
	return [[self avatar] framedAvatarImage];
}

#pragma mark Status

- (LPStatus)status
{
	return m_status;
}

- (NSString *)statusMessage
{
	return [[m_statusMessage copy] autorelease];
}

- (BOOL)isOnline
{
	return (m_status != LPStatusOffline);
}

- (BOOL)isInUserRoster
{
	return [[self contact] isInUserRoster];
}

- (BOOL)isRosterContact
{
	NSString *myUsername = [[self address] JIDUsernameComponent];
	return (myUsername != nil && [myUsername length] > 0);
}

- (BOOL)presenceShouldBeIgnored
{
	NSString *myHost = [[self address] JIDHostnameComponent];
	NSDictionary *sapoAgentsProps = [[[[self account] sapoAgents] dictionaryRepresentation] objectForKey:myHost];
	
	return ([sapoAgentsProps objectForKey:@"ignore_presences"] != nil);
}

- (int)multiContactPriority // smaller means higher priority
{
	LPAccount	*account = [self account];
	NSString	*myDomain = [[self address] JIDHostnameComponent];
	NSString	*priorityStr = nil;
	int			priority = 0;
	
	// Try sapo:chat-order first
	NSDictionary *sapoChatOrderDict = [account sapoChatOrderDictionary];
	
	if (sapoChatOrderDict != nil) {
		priorityStr = [sapoChatOrderDict objectForKey:myDomain];
		priority = (priorityStr ? [priorityStr intValue] : 100);
	}
	else {
		NSDictionary *sapoAgentsProps = [[[account sapoAgents] dictionaryRepresentation] objectForKey:myDomain];
		priorityStr = [sapoAgentsProps objectForKey:@"order"];
		priority = (priorityStr ? [priorityStr intValue] : INT_MAX);
	}
	
	return priority;
}

- (BOOL)wasOnlineBeforeDisconnecting
{
	return m_wasOnlineBeforeDisconnecting;
}

#pragma mark Capabilities

- (void)p_updateCapabilitiesOfResource:(NSString *)resourceName withFeatures:(NSArray *)capsFeatures
{
	if ([capsFeatures count] == 0)
		[m_capsFeaturesByResource removeObjectForKey:resourceName];
	else
		[m_capsFeaturesByResource setObject:[NSSet setWithArray:capsFeatures] forKey:resourceName];
}

- (LPEntryCapabilitiesFlags)capabilitiesFlags
{
	return m_capabilitiesCache;
}

- (BOOL)canDoChat
{
	return !(m_capabilitiesCache.noChatCapFlag);
}

- (BOOL)canDoSMS
{
	return m_capabilitiesCache.SMSCapFlag;
}

- (BOOL)canDoMUC
{
	return m_capabilitiesCache.MUCCapFlag;
}

- (BOOL)canDoFileTransfer
{
	return m_capabilitiesCache.fileTransferCapFlag;
}

- (NSArray *)availableResources
{
	return [[m_availableResources copy] autorelease];
}

- (BOOL)hasCapsFeature:(NSString *)capsFeature
{
	NSString *resource = [self resourceWithCapsFeature:capsFeature];
	return (resource && ([resource length] > 0));
}

- (NSString *)resourceWithCapsFeature:(NSString *)capsFeature
{
	NSEnumerator *resourceEnum = [m_capsFeaturesByResource keyEnumerator];
	NSString *resource = nil;
	
	while (resource = [resourceEnum nextObject]) {
		if ([[m_capsFeaturesByResource objectForKey:resource] containsObject:capsFeature])
			break;
	}
	
	return resource;
}

- (NSString *)allResourcesDescription
{
	NSMutableString *resultingString = [NSMutableString string];
	
	NSEnumerator *resourceEnumerator = [[self availableResources] objectEnumerator];
	NSString *resourceName;
	
	while (resourceName = [resourceEnumerator nextObject]) {
		NSString *headerStr = [NSString stringWithFormat:@"%@ (%@):\n", [self address], resourceName];
		NSString *resourcePropsStr = [self descriptionForResource:resourceName];
		
		[resultingString appendString:headerStr];
		[resultingString appendString:resourcePropsStr];
		[resultingString appendString:@"\n"];
	}
	
	return resultingString;
}

- (NSString *)descriptionForResource:(NSString *)resourceName
{
	/* This method returns a textual description of all	the properties of a given available resource. This
	enables us to show some	textual info in the GUI but it doesn't provide us with much flexibility in terms
	of the API available to	classes	that use LPContactEntry. */
	NSString *descr = @"";
	
	if ([m_availableResources containsObject:resourceName]) {
		NSDictionary	*properties = [LFAppController rosterEntryGetResourceProps:[self ID] :resourceName];
		id				clientInfo = [m_resourcesClientInfo objectForKey:resourceName];
		
		/*
		 * At this point, clientInfo may have one of three values:
		 *		- nil, which means that we have no client info available neither have we made any request for it;
		 *		- [NSNull null], which means that we have no client info available but we're waiting for the response
		 *			to a request we made earlier;
		 *		- an NSDictionary containing all the pertinent client info that we need.
		 */
		
		if (clientInfo == nil) {
			// Launch the request for client info
			[LFAppController rosterEntryResourceClientInfoGet:[self ID] :resourceName];
			// Remember that we are already waiting for the response from a version request
			[m_resourcesClientInfo setObject:[NSNull null] forKey:resourceName];
		}
		
		if (clientInfo == nil || clientInfo == [NSNull null]) {
			// Return a shorter description for now
			descr = [NSString stringWithFormat:@"\tStatus: %@\n\tStatus Message: \"%@\"\n\tLast Updated: %@\n\tCapabilities: %@\n",
				[properties objectForKey:@"show"],
				[properties objectForKey:@"status"],
				[properties objectForKey:@"last_updated"],
				[properties objectForKey:@"capabilities"]];
		}
		else {
			descr = [NSString stringWithFormat:@"\tStatus: %@\n\tStatus Message: \"%@\"\n\tLast Updated: %@\n\tClient Name: %@\n\tClient Version: %@\n\tOperating System: %@\n\tCapabilities: %@\n",
				[properties objectForKey:@"show"],
				[properties objectForKey:@"status"],
				[properties objectForKey:@"last_updated"],
				[clientInfo objectForKey:@"clientName"],
				[clientInfo objectForKey:@"clientVersion"],
				[clientInfo objectForKey:@"OSName"],
				[properties objectForKey:@"capabilities"]];
		}
	}
	
	return descr;
}


#pragma mark -
#pragma mark Roster Events Handlers


- (void)handleContactEntryChangedWithProperties:(NSDictionary *)properties
{
	NSString *accountUUID = [properties objectForKey:@"accountUUID"];
	LPAccount *account = [[LPAccountsController sharedAccountsController] accountForUUID:accountUUID];
	
	[self willChangeValueForKey:@"account"];
	[m_account release];
	m_account = [account retain];
	[self didChangeValueForKey:@"account"];
	
	[self willChangeValueForKey:@"address"];
	[m_address release];
	m_address = [[properties objectForKey:@"address"] copy];
	[self didChangeValueForKey:@"address"];
	
	[self willChangeValueForKey:@"subscription"];
	[m_subscription release];
	m_subscription = [[properties objectForKey:@"sub"] copy];
	[self didChangeValueForKey:@"subscription"];
	
	[self willChangeValueForKey:@"waitingForAuthorization"];
	m_waitingForAuthorization = [[properties objectForKey:@"ask"] boolValue];
	[self didChangeValueForKey:@"waitingForAuthorization"];
}

- (void)handleAdditionToContact:(LPContact *)contact
{
	if (contact != m_contact) {
		NSAssert((m_contact == nil), @"The entry can't be already associated with another contact");
		
		[self willChangeValueForKey:@"contact"];
		[m_contact release]; // This is not necessary if the condition in the assertion is always true, but it does no harm either
		m_contact = [contact retain];
		[self didChangeValueForKey:@"contact"];
	}
}

- (void)handleRemovalFromContact:(LPContact *)contact
{
	if (contact == m_contact) {
		[self willChangeValueForKey:@"contact"];
		[m_contact release];
		m_contact = nil;
		[self didChangeValueForKey:@"contact"];
	}
}

- (void)handlePresenceChangedWithStatus:(LPStatus)newStatus statusMessage:(NSString *)statusMessage
{
	/*
	 * Only process presence changes when the account is online, unless the jid's presence is
	 * changing to offline. This will prevent a jid from being marked as online when the account
	 * is in fact disconnected/offline.
	 */
	
	LPAccount *account = [self account];
	
	if ([account isOnline]) {
		m_wasOnlineBeforeDisconnecting = (newStatus != LPStatusOffline);
	}
	
	if ([account isOnline] || newStatus == LPStatusOffline) {
		
		[self willChangeValueForKey:@"status"];
		m_status = newStatus;
		[self didChangeValueForKey:@"status"];
		
		[self willChangeValueForKey:@"statusMessage"];
		[m_statusMessage release];
		m_statusMessage = [(((id)statusMessage == [NSNull null]) ?
							@"" :
							[statusMessage prettyStatusString]    ) copy];
		[self didChangeValueForKey:@"statusMessage"];
	}
	
	/*
	 * ...otherwise, do nothing! If the account is offline and we are receiving presenceChanged
	 * notifications stating that a jid changed status to something != offline, then we're
	 * probably receiving some pending notifications that were generated and enqueued prior to
	 * the account becoming offline. This may happen when the bridge is very busy or when the
	 * connection to the server drops while there were notifications still waiting to be delivered.
	 */
}

- (void)handleAvatarChangedWithData:(NSData *)imageData
{
	NSImage *newAvatar = [[NSImage alloc] initWithData:imageData];
	
	[self willChangeValueForKey:@"framedAvatar"];
	[self willChangeValueForKey:@"onlineAvatar"];
	[self willChangeValueForKey:@"offlineAvatar"];
	[self willChangeValueForKey:@"avatar"];
	{
		[m_avatar release];
		m_avatar = newAvatar;
		[m_cachedOfflineAvatar release];
		m_cachedOfflineAvatar = nil;
	}
	[self didChangeValueForKey:@"avatar"];
	[self didChangeValueForKey:@"offlineAvatar"];
	[self didChangeValueForKey:@"onlineAvatar"];
	[self didChangeValueForKey:@"framedAvatar"];
}

- (void)handleAvailableResourcesListChanged:(NSArray *)newResourcesList
{
	NSSet *oldResourcesListSet = [NSSet setWithArray:m_availableResources];
	NSSet *newResourcesListSet = [NSSet setWithArray:newResourcesList];
	
	if ([newResourcesListSet isEqualToSet:oldResourcesListSet] == NO) {
		[self willChangeValueForKey:@"availableResources"];
		[m_availableResources release];
		m_availableResources = [newResourcesList copy];
		[self didChangeValueForKey:@"availableResources"];
		
		// clean up the no longer available resources from the dictionary of client info
		NSMutableSet *removedResources = [NSMutableSet setWithSet:oldResourcesListSet];
		[removedResources minusSet:newResourcesListSet];
		[m_resourcesClientInfo removeObjectsForKeys:[removedResources allObjects]];
	}
}

- (void)handleResourcePropertiesChanged:(NSString *)resourceName
{
	[self willChangeValueForKey:@"allResourcesDescription"];
	[self didChangeValueForKey:@"allResourcesDescription"];
}

- (void)handleResourceCapabilitiesChanged:(NSString *)resourceName withFeatures:(NSArray *)capsFeatures
{
	if ([self isOnline]) {
		[self p_updateCapabilitiesOfResource:resourceName withFeatures:capsFeatures];
		
		// Update our capabilities cache only if we're online. If we're offline, keep the last seen capabilities cached.
		[self willChangeValueForKey:@"capabilitiesFlags"];
		m_capabilitiesCache.noChatCapFlag = [self hasCapsFeature:@"http://messenger.sapo.pt/features/no_chat"];
		m_capabilitiesCache.SMSCapFlag = [self hasCapsFeature:@"sapo:sms"];
		m_capabilitiesCache.MUCCapFlag = [self hasCapsFeature:@"http://jabber.org/protocol/muc"];
		m_capabilitiesCache.fileTransferCapFlag = [self hasCapsFeature:@"http://jabber.org/protocol/si/profile/file-transfer"];
		[self didChangeValueForKey:@"capabilitiesFlags"];
		
		[self handleResourcePropertiesChanged:resourceName];
	}
}

- (void)handleReceivedClientName:(NSString *)clientName clientVersion:(NSString *)clientVersion OSName:(NSString *)OSName forResource:(NSString *)resource
{
	NSDictionary *clientInfoDict = [NSDictionary dictionaryWithObjectsAndKeys:
		clientName, @"clientName",
		clientVersion, @"clientVersion",
		OSName, @"OSName", nil];
	
	[m_resourcesClientInfo setObject:clientInfoDict forKey:resource];
	[self handleResourcePropertiesChanged:resource];
}

- (void)handleReceivedMessageActivity
{
	if (![self isOnline]) {
		[self willChangeValueForKey:@"status"];
		m_status = LPStatusInvisible;
		[self didChangeValueForKey:@"status"];
	}
	
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(p_checkOnlineStatus) object:nil];
	[self performSelector:@selector(p_checkOnlineStatus) withObject:nil afterDelay:300.0 /* 5 minutes */ ];
}

- (void)p_checkOnlineStatus
{
	if (m_status == LPStatusInvisible) {
		[self willChangeValueForKey:@"status"];
		m_status = LPStatusOffline;
		[self didChangeValueForKey:@"status"];
	}
}

@end
