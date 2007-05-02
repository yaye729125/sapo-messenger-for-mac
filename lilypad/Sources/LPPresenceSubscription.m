//
//  LPPresenceSubscription.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPPresenceSubscription.h"
#import "LFAppController.h"
#import "LPRoster.h"
#import "LPContact.h"
#import "LPContactEntry.h"


@implementation LPPresenceSubscription

+ (LPPresenceSubscription *)presenceSubscriptionWithState:(LPPresenceSubscriptionState)state contactEntry:(LPContactEntry *)entry date:(NSDate *)date
{
	return [[[[self class] alloc] initWithState:state contactEntry:entry date:date] autorelease];
}

- initWithState:(LPPresenceSubscriptionState)state contactEntry:(LPContactEntry *)entry date:(NSDate *)date
{
	if (self = [super init]) {
		m_date = [date retain];
		m_state = state;
		m_contactEntry = [entry retain];
		
		if (state != LPAuthorizationGranted)
			m_requiresUserIntervention = YES;
	}
	return self;
}

- (void)dealloc
{
	[m_date release];
	[m_contactEntry release];
	[super dealloc];
}

- (NSDate *)date
{
	return [[m_date retain] autorelease];
}

- (LPPresenceSubscriptionState)state
{
	return m_state;
}

- (LPContactEntry *)contactEntry
{
	return [[m_contactEntry retain] autorelease];
}

- (void)p_didTakeAction
{
	if (m_requiresUserIntervention) {
		[self willChangeValueForKey:@"requiresUserIntervention"];
		m_requiresUserIntervention = NO;
		[self didChangeValueForKey:@"requiresUserIntervention"];
	}
}

- (void)approveRequest
{
	[LFAppController rosterEntryAuthGrant:[m_contactEntry ID]];
	
	NSString *entrySubscription = [m_contactEntry subscription];
	
	if ([entrySubscription length] == 0 ||
		[entrySubscription isEqualToString:@"none"] ||
		[entrySubscription isEqualToString:@"from"])
	{
		// We only need to ask for the authorization from the new entry because the core already adds the entry to
		// our roster automatically when we grant them our authorization in the line of code above.
		[LFAppController rosterEntryAuthRequest:[m_contactEntry ID]];
	}
	
	[self p_didTakeAction];
}

- (void)rejectRequest
{
	[LFAppController rosterEntryAuthReject:[m_contactEntry ID]];
	[self p_didTakeAction];
}

- (void)sendRequest
{
	[LFAppController rosterEntryAuthRequest:[m_contactEntry ID]];
	[self p_didTakeAction];
}

- (void)removeContactEntry
{
	LPContactEntry *entry = [self contactEntry];
	LPContact *contact = [entry contact];
	
	if ([[contact contactEntries] count] == 1)
		[[entry roster] removeContact:contact];
	else
		[contact removeContactEntry:entry];
	
	[self p_didTakeAction];
}

- (BOOL)requiresUserIntervention
{
	return m_requiresUserIntervention;
}

@end
