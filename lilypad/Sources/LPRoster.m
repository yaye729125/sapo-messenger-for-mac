//
//  LPRoster.m
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPRoster.h"
#import "LPGroup.h"
#import "LPContact.h"
#import "LPContactEntry.h"
#import "LPAccountsController.h"
#import "LPAccount.h"
#import "LPPresenceSubscription.h"
#import "LFAppController.h"


@interface LPRoster ()  // Private Bridge Notification Handlers
- (void)leapfrogBridge_rosterGroupAdded:(int)groupID :(NSDictionary *)groupProps;
- (void)leapfrogBridge_rosterGroupRemoved:(int)groupID;
- (void)leapfrogBridge_rosterGroupChanged:(int)groupID :(NSDictionary *)groupProps;
- (void)leapfrogBridge_rosterContactAdded:(int)groupID :(int)contactID :(NSDictionary *)contactProps;
- (void)leapfrogBridge_rosterContactRemoved:(int)contactID;
- (void)leapfrogBridge_rosterContactChanged:(int)contactID :(NSDictionary *)contactProps;
- (void)leapfrogBridge_rosterContactGroupAdded:(int)contactID :(int)groupID;
- (void)leapfrogBridge_rosterContactGroupRemoved:(int)contactID :(int)groupID;
- (void)leapfrogBridge_rosterContactGroupChanged:(int)contactID :(int)oldGroupID :(int)newGroupID;
- (void)leapfrogBridge_rosterEntryAdded:(int)contactID :(int)entryID :(NSDictionary *)entryProps;
- (void)leapfrogBridge_rosterEntryRemoved:(int)entryID;
- (void)leapfrogBridge_rosterEntryChanged:(int)entryID :(NSDictionary *)entryProps;
- (void)leapfrogBridge_presenceUpdated:(int)entryID :(NSString *)status :(NSString *)statusMessage;
- (void)leapfrogBridge_nicknameUpdated:(int)entryID :(NSString *)nickname;
- (void)leapfrogBridge_avatarChanged:(int)entryID :(NSString *)typeOfData :(NSData *)data;
- (void)leapfrogBridge_authGranted:(int)entryID;
- (void)leapfrogBridge_authRequest:(int)entryID :(NSString *)nick :(NSString *)reason;
- (void)leapfrogBridge_authLost:(int)entryID;
- (void)leapfrogBridge_infoReady:(int)transID :(NSDictionary *)infoMap;
- (void)leapfrogBridge_infoPublished:(int)transID;
- (void)leapfrogBridge_infoError:(int)transID :(NSString *)message;
@end


static LPRoster *s_sharedRoster = nil;


@implementation LPRoster

+ (void)initialize
{
	if (self == [LPRoster class]) {
		[self setKeys:[NSArray arrayWithObject:@"allGroups"] triggerChangeNotificationsForDependentKey:@"sortedUserGroups"];
	}
}

+ (LPRoster *)roster
{
	if (s_sharedRoster == nil) {
		s_sharedRoster = [[LPRoster alloc] init];
	}
	return s_sharedRoster;
}

- init
{
	if (self = [super init]) {
		m_allContacts = [[NSMutableArray alloc] init];
		m_allGroups = [[NSMutableArray alloc] init];
		
		m_groupsByID = [[NSMutableDictionary alloc] init];
		m_contactsByID = [[NSMutableDictionary alloc] init];
		m_contactEntriesByID = [[NSMutableDictionary alloc] init];
		
		[LFPlatformBridge registerNotificationsObserver:self];

		// This will send us notifications announcing the default groups of the core
		[LFAppController rosterStart];
	}
	return self;
}

- (void)dealloc
{
	[LFPlatformBridge unregisterNotificationsObserver:self];
	
	[m_allContacts release];
	[m_allGroups release];
	
	[m_groupsByID release];
	[m_contactsByID release];
	[m_contactEntriesByID release];
	
	[super dealloc];
}

- (id)delegate
{
	return m_delegate;
}

- (void)setDelegate:(id)delegate
{
	m_delegate = delegate;
}


#pragma mark -
#pragma mark Registration in the Roster internal tables


- (void)registerGroup:(LPGroup *)group forID:(int)groupID
{
	NSParameterAssert(group);
	
	NSAssert((groupID != LPInvalidID), @"Can't add a group with an invalid ID to the indexes");
	NSAssert(([self groupForID:groupID] == nil), @"There's already a group registered with this ID");
	
	NSIndexSet *changedIndexes = [NSIndexSet indexSetWithIndex:[m_allGroups count]];
	
	[self willChange:NSKeyValueChangeInsertion valuesAtIndexes:changedIndexes forKey:@"allGroups"];
	[m_allGroups addObject:group];
	[m_groupsByID setObject:group forKey:[NSNumber numberWithInt:groupID]];
	[group setID:groupID roster:self];
	[self didChange:NSKeyValueChangeInsertion valuesAtIndexes:changedIndexes forKey:@"allGroups"];
}

- (void)unregisterGroup:(LPGroup *)group
{
	NSParameterAssert(group);
	
	int groupID = [group ID];
	
	int idx = [m_allGroups indexOfObject:group];
	NSIndexSet *changedIndexes = [NSIndexSet indexSetWithIndex:idx];
	
	[self willChange:NSKeyValueChangeRemoval valuesAtIndexes:changedIndexes forKey:@"allGroups"];
	[m_allGroups removeObjectAtIndex:idx];
	[group setID:LPInvalidID roster:nil];
	[m_groupsByID removeObjectForKey:[NSNumber numberWithInt:groupID]];
	[self didChange:NSKeyValueChangeRemoval valuesAtIndexes:changedIndexes forKey:@"allGroups"];
}

- (void)registerContact:(LPContact *)contact forID:(int)contactID
{
	NSParameterAssert(contact);

	NSAssert((contactID != LPInvalidID), @"Can't add a contact with an invalid ID to the indexes");
	NSAssert(([self contactForID:contactID] == nil), @"There's already a contact registered with this ID");

	NSIndexSet *changedIndexes = [NSIndexSet indexSetWithIndex:[m_allContacts count]];
	
	[self willChange:NSKeyValueChangeInsertion valuesAtIndexes:changedIndexes forKey:@"allContacts"];
	[m_allContacts addObject:contact];
	[m_contactsByID setObject:contact forKey:[NSNumber numberWithInt:contactID]];
	[contact setID:contactID roster:self];
	[self didChange:NSKeyValueChangeInsertion valuesAtIndexes:changedIndexes forKey:@"allContacts"];
}

- (void)unregisterContact:(LPContact *)contact
{
	NSParameterAssert(contact);
	
	int contactID = [contact ID];
	
	int idx = [m_allContacts indexOfObject:contact];
	NSIndexSet *changedIndexes = [NSIndexSet indexSetWithIndex:idx];
	
	[self willChange:NSKeyValueChangeRemoval valuesAtIndexes:changedIndexes forKey:@"allContacts"];
	[m_allContacts removeObjectAtIndex:idx];
	[contact setID:LPInvalidID roster:nil];
	[m_contactsByID removeObjectForKey:[NSNumber numberWithInt:contactID]];
	[self didChange:NSKeyValueChangeRemoval valuesAtIndexes:changedIndexes forKey:@"allContacts"];
}

- (void)registerContactEntry:(LPContactEntry *)entry forID:(int)entryID
{
	NSParameterAssert(entry);

	NSAssert((entryID != LPInvalidID), @"Can't add an entry with an invalid ID to the indexes");
	NSAssert(([self contactEntryForID:entryID] == nil), @"There's already an entry registered with this ID");
	
	[self willChangeValueForKey:@"allContactEntries"];
	[m_contactEntriesByID setObject:entry forKey:[NSNumber numberWithInt:entryID]];
	[entry setID:entryID roster:self];
	[self didChangeValueForKey:@"allContactEntries"];
}

- (void)unregisterContactEntry:(LPContactEntry *)entry
{
	NSParameterAssert(entry);

	int entryID = [entry ID];
	
	[self willChangeValueForKey:@"allContactEntries"];
	[entry setID:LPInvalidID roster:nil];
	[m_contactEntriesByID removeObjectForKey:[NSNumber numberWithInt:entryID]];
	[self didChangeValueForKey:@"allContactEntries"];
}

#pragma mark -

- (LPGroup *)groupForID:(int)groupID
{
	return [m_groupsByID objectForKey:[NSNumber numberWithInt:groupID]];
}

- (LPContact *)contactForID:(int)contactID
{
	return [m_contactsByID objectForKey:[NSNumber numberWithInt:contactID]];
}

- (LPContactEntry *)contactEntryForID:(int)entryID
{
	return [m_contactEntriesByID objectForKey:[NSNumber numberWithInt:entryID]];
}

#pragma mark -

- (LPGroup *)groupForHiddenContacts
{
	NSEnumerator *groupEnum = [m_groupsByID objectEnumerator];
	LPGroup *group = nil;
	
	while (group = [groupEnum nextObject])
		if ([group type] == LPNotInListGroupType)
			break;
	
	return group;
}

#pragma mark -

- (LPGroup *)groupForName:(NSString *)groupName
{
	NSEnumerator *groupEnum = [m_groupsByID objectEnumerator];
	LPGroup *group = nil;
	
	if (groupName == nil || [groupName length] == 0) {
		// empty string: return the group used for contacts having no group
		while (group = [groupEnum nextObject]) {
			if ([group type] == LPNoGroupType)
				break;
		}
	}
	else {
		while (group = [groupEnum nextObject]) {
			if ([group type] != LPNotInListGroupType
				&& [groupName caseInsensitiveCompare:[group name]] == NSOrderedSame)
				break;
		}
	}
	return group;
}

- (LPContact *)contactForName:(NSString *)contactName
{
	NSEnumerator *contactEnum = [m_contactsByID objectEnumerator];
	LPContact *contact = nil;
	
	while (contact = [contactEnum nextObject]) {
		if ([contact isInUserRoster]
			&& [contactName caseInsensitiveCompare:[contact name]] == NSOrderedSame)
			break;
	}
	return contact;
}

- (LPContactEntry *)contactEntryInAnyAccountForAddress:(NSString *)entryAddress
{
	return [self contactEntryForAddress:entryAddress account:nil];
}

- (LPContactEntry *)contactEntryInAnyAccountForAddress:(NSString *)entryAddress
					 createNewHiddenWithNameIfNotFound:(NSString *)name
{
	return [self contactEntryForAddress:entryAddress account:nil createNewHiddenWithNameIfNotFound:name];
}

- (LPContactEntry *)contactEntryInAnyAccountForAddress:(NSString *)entryAddress
					 createNewHiddenWithNameIfNotFound:(NSString *)name
									   createInAccount:(LPAccount *)accountForNewEntry
{
	NSParameterAssert(entryAddress);
	NSParameterAssert(name);
	NSParameterAssert(accountForNewEntry);
	
	LPContactEntry *entry = [self contactEntryInAnyAccountForAddress:entryAddress];
	
	if (entry == nil) {
		// Create a new one
		LPGroup *group = [self groupForHiddenContacts];
		LPContact *contact = [group addNewContactWithName:name];
		entry = [contact addNewContactEntryWithAddress:entryAddress account:accountForNewEntry reason:@""];
	}
	
	return entry;
}

- (LPContactEntry *)contactEntryInAnyAccountForAddress:(NSString *)entryAddress
							searchOnlyUserAddedEntries:(BOOL)userAddedOnly
{
	return [self contactEntryForAddress:entryAddress account:nil searchOnlyUserAddedEntries:userAddedOnly];
}


- (LPContactEntry *)contactEntryForAddress:(NSString *)entryAddress account:(LPAccount *)account
{
	return [self contactEntryForAddress:entryAddress account:account searchOnlyUserAddedEntries:NO];
}

- (LPContactEntry *)contactEntryForAddress:(NSString *)entryAddress account:(LPAccount *)account
		 createNewHiddenWithNameIfNotFound:(NSString *)name
{
	NSParameterAssert(entryAddress);
	NSParameterAssert(name);
	
	LPContactEntry *entry = [self contactEntryForAddress:entryAddress account:account];
	
	if (entry == nil) {
		// If we're creating a new entry, then we really need an account
		LPAccount *actualAccount = (account != nil ?
									account :
									[[LPAccountsController sharedAccountsController] defaultAccount]);
		
		// Create a new one
		LPGroup *group = [self groupForHiddenContacts];
		LPContact *contact = [group addNewContactWithName:name];
		entry = [contact addNewContactEntryWithAddress:entryAddress account:actualAccount reason:@""];
	}
	
	return entry;
}

- (LPContactEntry *)contactEntryForAddress:(NSString *)entryAddress account:(LPAccount *)account searchOnlyUserAddedEntries:(BOOL)userAddedOnly
{
	NSParameterAssert(entryAddress);
	
	NSEnumerator *entriesEnum = [m_contactEntriesByID objectEnumerator];
	LPContactEntry *entry = nil;
	
	while (entry = [entriesEnum nextObject]) {
		if ((!userAddedOnly || [entry isInUserRoster])
			&& [entryAddress caseInsensitiveCompare:[entry address]] == NSOrderedSame
#warning Choose the account more carefully, dont just pick the first one that comes up.
			&& (account == nil || [entry account] == account))
			break;
	}
	return entry;
}


#pragma mark -
#pragma mark Groups, Contacts and Entries


- (LPGroup *)addNewGroupWithName:(NSString *)groupName
{
	LPGroup *group = [LPGroup groupWithName:groupName];
	[self addGroup:group];
	return group;
}


- (void)addGroup:(LPGroup *)group
{
	NSParameterAssert(group);
	NSAssert(([group roster] == nil), @"The group can't already be a member of a roster");
	NSAssert1(([self groupForName:[group name]] == nil),
			  @"There is already a group named \"%@\"", [group name]);
	
	int newGroupID = [[LFAppController rosterGroupAddWithName:[group name] pos:(-1)] intValue];
	
	if (newGroupID != LPInvalidID) {
		// We will add it to our indexes right away because if we only did that in leapfrogBridge_rosterGroupAdded
		// a new LPGroup instance would be created. But we want to keep and index this one.
		[self registerGroup:group forID:newGroupID];
	}
}


- (void)removeGroup:(LPGroup *)group
{
	NSParameterAssert(group);
	NSAssert(([group ID] != LPInvalidID), @"The group must have a valid ID");

	[LFAppController rosterGroupRemove:[group ID]];
}


- (void)removeContact:(LPContact *)contact
{
	NSParameterAssert(contact);
	NSAssert(([contact ID] != LPInvalidID), @"The contact must have a valid ID");

	[LFAppController rosterContactRemove:[contact ID]];
}


- (NSString *)uniqueNameForCopyOfContact:(LPContact *)originalContact
{
	NSString *baseNameForCopy = [NSString stringWithFormat:@"%@%@", [originalContact name], NSLocalizedString(@" - Copy", @"contact copy suffix")];
	NSString *nameForCopy = baseNameForCopy;
	unsigned int copyCounter = 1;
	
	while ([self contactForName:nameForCopy] != nil) {
		++copyCounter;
		nameForCopy = [NSString stringWithFormat:@"%@ %d", baseNameForCopy, copyCounter];
	}
	return nameForCopy;
}


- (NSArray *)allGroups
{
	return [[m_allGroups retain] autorelease];
}


- (NSArray *)sortedUserGroups
{
	NSMutableArray *userGroups = [NSMutableArray array];
	NSEnumerator *groupEnum = [[self allGroups] objectEnumerator];
	LPGroup *group;
	
	while (group = [groupEnum nextObject]) {
		if ([group type] == LPUserGroupType) {
			[userGroups addObject:group];
		}
	}

	static NSArray *groupsSortDescriptors = nil;
	if (groupsSortDescriptors == nil) {
		NSSortDescriptor *sortDescr = [[NSSortDescriptor alloc] initWithKey:@"name"
																  ascending:YES
																   selector:@selector(caseInsensitiveCompare:)];
		
		groupsSortDescriptors = [[NSArray alloc] initWithObjects:sortDescr, nil];
		[sortDescr release];
	}
	
	[userGroups sortUsingDescriptors:groupsSortDescriptors];
	return userGroups;
}


- (NSArray *)allContacts
{
	return [[m_allContacts retain] autorelease];
}


- (NSArray *)allContactEntries
{
	return [m_contactEntriesByID allValues];
}


#pragma mark -
#pragma mark Bridge Notifications


#pragma mark Groups

- (void)leapfrogBridge_rosterGroupAdded:(int)groupID :(NSDictionary *)groupProps
{
	if ([self groupForID:groupID] == nil) {
		// We don't know this group yet.
		LPGroup *newGroup = [[LPGroup alloc] init];
		[self registerGroup:newGroup forID:groupID];
		[newGroup release];
	}
	[self leapfrogBridge_rosterGroupChanged:groupID :groupProps];
}


- (void)leapfrogBridge_rosterGroupRemoved:(int)groupID
{
	LPGroup *group = [self groupForID:groupID];
	NSAssert((group != nil), @"This group ID is unknown");
	[self unregisterGroup:group];
}


- (void)leapfrogBridge_rosterGroupChanged:(int)groupID :(NSDictionary *)groupProps
{
	NSAssert(([self groupForID:groupID] != nil), @"Unknown group ID");
	[[self groupForID:groupID] handleGroupChangedWithProperties:groupProps];
}


#pragma mark Contacts

- (void)leapfrogBridge_rosterContactAdded:(int)groupID :(int)contactID :(NSDictionary *)contactProps
{
	NSAssert(([self groupForID:groupID] != nil), @"Unknown group ID");
	
	if ([self contactForID:contactID] == nil) {
		// We don't know this contact yet.
		LPContact *newContact = [[LPContact alloc] init];
		[self registerContact:newContact forID:contactID];
		[newContact release];
	}
	
	[self leapfrogBridge_rosterContactChanged:contactID :contactProps];
	[self leapfrogBridge_rosterContactGroupAdded:contactID :groupID];
}


- (void)leapfrogBridge_rosterContactRemoved:(int)contactID
{
	NSAssert(([self contactForID:contactID] != nil), @"Unknown contact ID");

	LPContact *removedContact = [self contactForID:contactID];
	
	// Notify the groups that their contact is to be removed
	NSEnumerator *groupsEnumerator = [[removedContact groups] objectEnumerator];
	LPGroup *someGroup;
	
	while (someGroup = [groupsEnumerator nextObject]) {
		[someGroup handleRemovalOfContact:removedContact];
		[removedContact handleRemovalFromGroup:someGroup];
	}
	
	[self unregisterContact:removedContact];
}


- (void)leapfrogBridge_rosterContactChanged:(int)contactID :(NSDictionary *)contactProps
{
	NSAssert(([self contactForID:contactID] != nil), @"Unknown contact ID");
	[[self contactForID:contactID] handleContactChangedWithProperties:contactProps];
}


- (void)leapfrogBridge_rosterContactGroupAdded:(int)contactID :(int)groupID
{
	NSAssert(([self groupForID:groupID] != nil), @"Unknown group ID");
	NSAssert(([self contactForID:contactID] != nil), @"Unknown contact ID");
	
	LPGroup *group = [self groupForID:groupID];
	LPContact *contact = [self contactForID:contactID];
	
	[group handleAdditionOfContact:(LPContact *)contact];
	[contact handleAdditionToGroup:(LPGroup *)group];
}


- (void)leapfrogBridge_rosterContactGroupRemoved:(int)contactID :(int)groupID
{
	NSAssert(([self groupForID:groupID] != nil), @"Unknown group ID");
	NSAssert(([self contactForID:contactID] != nil), @"Unknown contact ID");
	
	LPGroup *group = [self groupForID:groupID];
	LPContact *contact = [self contactForID:contactID];
	
	[group handleRemovalOfContact:contact];
	[contact handleRemovalFromGroup:group];
}


- (void)leapfrogBridge_rosterContactGroupChanged:(int)contactID :(int)oldGroupID :(int)newGroupID
{
	[self leapfrogBridge_rosterContactGroupRemoved:contactID :oldGroupID];
	[self leapfrogBridge_rosterContactGroupAdded:contactID :newGroupID];
}


#pragma mark Entries

- (void)leapfrogBridge_rosterEntryAdded:(int)contactID :(int)entryID :(NSDictionary *)entryProps
{
	NSAssert(([self contactForID:contactID] != nil), @"Unknown contact ID");
	
	LPContactEntry *entry = [self contactEntryForID:entryID];
	
	if (entry == nil) {
		// We don't know this entry yet.
		entry = [[LPContactEntry alloc] init];
		[self registerContactEntry:entry forID:entryID];
		[entry release];
	}
	
	[self leapfrogBridge_rosterEntryChanged:entryID :entryProps];
	
	LPContact *contact = [self contactForID:contactID];
	
	[contact handleAdditionOfEntry:entry];
	[entry handleAdditionToContact:contact];
}


- (void)leapfrogBridge_rosterEntryRemoved:(int)entryID
{
	LPContactEntry *entry = [self contactEntryForID:entryID];

	NSAssert(([entry contact] != nil), @"This entry is not associated with a contact");
	NSAssert(([[entry contact] roster] == self), @"This entry's contact is not in this roster");
	
	LPContact *contact = [entry contact];
	
	[contact handleRemovalOfEntry:entry];
	[entry handleRemovalFromContact:contact];
	
	[self unregisterContactEntry:entry];
}


- (void)leapfrogBridge_rosterEntryChanged:(int)entryID :(NSDictionary *)entryProps
{
	NSAssert(([self contactEntryForID:entryID] != nil), @"Unknown entry ID");
	[[self contactEntryForID:entryID] handleContactEntryChangedWithProperties:entryProps];
}


- (void)leapfrogBridge_rosterEntryContactChanged:(int)entryID :(int)oldContactID :(int)newContactID
{
	LPContactEntry	*entry = [self contactEntryForID:entryID];
	LPContact		*oldContact = [self contactForID:oldContactID];
	LPContact		*newContact = [self contactForID:newContactID];
	
	NSAssert((entry      != nil), @"Unknown entry ID");
	NSAssert((newContact != nil), @"Unknown new contact ID");
	
	if (oldContact != nil) {
		//... it may have been already removed from the GUI
		[entry handleRemovalFromContact:oldContact];
		[oldContact handleRemovalOfEntry:entry];
	}
	[entry handleAdditionToContact:newContact];
	[newContact handleAdditionOfEntry:entry];
}


- (void)leapfrogBridge_rosterEntryResourceListChanged:(int)entryID :(NSArray *)resourceList
{
	NSAssert(([self contactEntryForID:entryID] != nil), @"Unknown entry ID");
	[[self contactEntryForID:entryID] handleAvailableResourcesListChanged:resourceList];
}


- (void)leapfrogBridge_rosterEntryResourceChanged:(int)entryID :(NSString *)resource
{
	NSAssert(([self contactEntryForID:entryID] != nil), @"Unknown entry ID");
	[[self contactEntryForID:entryID] handleResourcePropertiesChanged:resource];
}


- (void)leapfrogBridge_rosterEntryResourceCapabilitiesChanged:(int)entryID :(NSString *)resource :(NSArray *)capsFeatures
{
	NSAssert(([self contactEntryForID:entryID] != nil), @"Unknown entry ID");
	[[self contactEntryForID:entryID] handleResourceCapabilitiesChanged:resource withFeatures:capsFeatures];
}


- (void)leapfrogBridge_rosterEntryResourceClientInfoReceived:(int)entryID :(NSString *)resource :(NSString *)clientName :(NSString *)clientVersion :(NSString *)OSName
{
	NSAssert(([self contactEntryForID:entryID] != nil), @"Unknown entry ID");
	
	[[self contactEntryForID:entryID] handleReceivedClientName:clientName
												 clientVersion:clientVersion
														OSName:OSName
												   forResource:resource];
}


#pragma mark Presence

- (void)leapfrogBridge_presenceUpdated:(int)entryID :(NSString *)status :(NSString *)statusMessage
{
	NSAssert(([self contactEntryForID:entryID] != nil), @"Unkown contact entry ID");
	[[self contactEntryForID:entryID] handlePresenceChangedWithStatus: LPStatusFromStatusString(status)
														statusMessage: statusMessage];
}

- (void)leapfrogBridge_nicknameUpdated:(int)entryID :(NSString *)nickname
{
	NSAssert(([self contactEntryForID:entryID] != nil), @"Unkown contact entry ID");
	[[self contactEntryForID:entryID] handleNicknameDidChangeTo:nickname];
}


#pragma mark Avatar

- (void)leapfrogBridge_avatarChanged:(int)entryID :(NSString *)typeOfData :(NSData *)data
{
	NSAssert(([self contactEntryForID:entryID] != nil), @"Unkown contact entry ID");
	[[self contactEntryForID:entryID] handleAvatarChangedWithData:data];
}


#pragma mark Presence Subscriptions


- (void)leapfrogBridge_authGranted:(int)entryID
{
	LPContactEntry *entry = [self contactEntryForID:entryID];
	NSAssert1((entry != nil), @"%@: notification received for unknown contact entry!", NSStringFromSelector(_cmd));
	
	if (entry && [m_delegate respondsToSelector:@selector(roster:didReceivePresenceSubscriptionRequest:)]) {
		LPPresenceSubscription *presSub = [LPPresenceSubscription presenceSubscriptionWithState:LPAuthorizationGranted
																				   contactEntry:entry
																						   date:[NSDate date]];
		[m_delegate roster:self didReceivePresenceSubscriptionRequest:presSub];
	}
}


- (void)leapfrogBridge_authRequest:(int)entryID :(NSString *)nick :(NSString *)reason
{
	LPContactEntry *entry = [self contactEntryForID:entryID];
	NSAssert1((entry != nil), @"%@: notification received for unknown contact entry!", NSStringFromSelector(_cmd));
	
	if (entry) {
		if ([[entry address] isPhoneJID]) {
			// Phone contacts get automatically accepted
			[LFAppController rosterEntryAuthGrant:entryID];
		}
		else if ([m_delegate respondsToSelector:@selector(roster:didReceivePresenceSubscriptionRequest:)]) {
			LPPresenceSubscription *presSub = [LPPresenceSubscription presenceSubscriptionWithState:LPAuthorizationRequested
																					   contactEntry:entry
																						   nickname:nick
																							 reason:reason
																							   date:[NSDate date]];
			[m_delegate roster:self didReceivePresenceSubscriptionRequest:presSub];
		}
	}
}


- (void)leapfrogBridge_authLost:(int)entryID
{
	LPContactEntry *entry = [self contactEntryForID:entryID];
	NSAssert1((entry != nil), @"%@: notification received for unknown contact entry!", NSStringFromSelector(_cmd));
	
	if (entry) {
		LPPresenceSubscription *presSub = [LPPresenceSubscription presenceSubscriptionWithState:LPAuthorizationLost
																				   contactEntry:entry
																						   date:[NSDate date]];
		[m_delegate roster:self didReceivePresenceSubscriptionRequest:presSub];
	}
}


#pragma mark Contact Info

#warning TO DO: Contact Info

- (void)leapfrogBridge_infoReady:(int)transID :(NSDictionary *)infoMap
{
	NSLog(@"%@: not implemented yet", NSStringFromSelector(_cmd));
}


- (void)leapfrogBridge_infoPublished:(int)transID
{
	NSLog(@"%@: not implemented yet", NSStringFromSelector(_cmd));
}


- (void)leapfrogBridge_infoError:(int)transID :(NSString *)message
{
	NSLog(@"%@: not implemented yet", NSStringFromSelector(_cmd));
}


@end
