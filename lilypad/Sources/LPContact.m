//
//  LPContact.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPContact.h"
#import "LPContactEntry.h"
#import "LPGroup.h"
#import "LPRoster.h"
#import "LFAppController.h"
#import "NSImage+AvatarAdditions.h"

#warning Estes devem dar para apagar depois de tratar dos outros warnings
#import "LPAccountsController.h"
#import "LPAccount.h"


@implementation LPContact

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key
{
	if ([key isEqualToString:@"name"] || [key isEqualToString:@"altName"]) {
		// We only want to notify of changes to these keys when the corresponding notification comes
		// from the leapfrog bridge and not when the setters are invoked.
		return NO;
	}
	else {
		return [super automaticallyNotifiesObserversForKey:key];
	}
}

+ (void)initialize
{
	NSArray *statusKeyArray = [NSArray arrayWithObject:@"status"];
	
	[self setKeys:statusKeyArray triggerChangeNotificationsForDependentKey:@"online"];
	
	// We don't need to do this for the statusMessage key because it is always modified when the status is modified
	// in handlePresenceChangedWithStatus:statusMessage:
	// [self setKeys:statusKeyArray triggerChangeNotificationsForDependentKey:@"statusMessage"];
	
	[self setKeys:[NSArray arrayWithObjects:@"preferredContactEntry", @"chatContactEntries", nil] triggerChangeNotificationsForDependentKey:@"mainContactEntry"];
	[self setKeys:[NSArray arrayWithObject:@"avatar"]
		triggerChangeNotificationsForDependentKey:@"framedAvatar"];
}


+ contactWithName:(NSString *)name
{
	return [[[[self class] alloc] initWithName:name] autorelease];
}

// Designated initializer
- initWithName:(NSString *)name
{
	if (self = [super init]) {
		m_creationDate = [[NSDate alloc] init];
		
		m_name = [name copy];
		m_altName = [@"" copy];
		m_avatar = [[NSImage imageNamed:@"defaultAvatar"] retain];
		m_statusMessage = [@"" copy];
		m_groups = [[NSMutableArray alloc] init];
		m_contactEntries = [[NSMutableArray alloc] init];
		m_chatContactEntries = [[NSMutableArray alloc] init];
		m_smsContactEntries = [[NSMutableArray alloc] init];
	}
	return self;
}

- init
{
	return [self initWithName:nil];
}

- (void)dealloc
{
	[m_creationDate release];
	
	[m_name release];
	[m_altName release];
	[m_avatar release];
	[m_statusMessage release];
	[m_groups release];
	[m_contactEntries release];
	[m_chatContactEntries release];
	[m_smsContactEntries release];
	[m_preferredContactEntry release];
	[super dealloc];
}

// This doesn't copy anything, only increases the retain count of the instance
- (id)copyWithZone:(NSZone *)zone
{
	return [self retain];
}

- (NSDate *)creationDate
{
	return m_creationDate;
}

- (void)p_recalculateContactProperties
{
	// The main contact entry avatar takes precedence over the others
	LPContactEntry	*mainEntry = [self mainContactEntry];
	LPContactEntry	*selectedEntryForCustomAvatar = ([mainEntry hasCustomAvatar] ? mainEntry : nil);
	BOOL			selectedEntryForCustomAvatarIsOffline = (selectedEntryForCustomAvatar ? (![mainEntry isOnline]) : YES);
	LPStatus		selectedStatus = LPStatusOffline;
	NSString		*selectedStatusMessage = nil;
	BOOL			selectedWasOnlineBeforeDisconnecting = NO;
	
	NSEnumerator *entriesEnumerator = [m_chatContactEntries objectEnumerator];
	LPContactEntry *entry;
	
	while (entry = [entriesEnumerator nextObject]) {
		LPStatus entryStatus = [entry status];
		
		// Select an avatar
		if ([entry hasCustomAvatar] &&
			( selectedEntryForCustomAvatar == nil ||
			  ( selectedEntryForCustomAvatarIsOffline && (entryStatus != LPStatusOffline) )))
		{
			selectedEntryForCustomAvatar = entry;
			selectedEntryForCustomAvatarIsOffline = (entryStatus == LPStatusOffline);
		}
		
		if (selectedWasOnlineBeforeDisconnecting == NO)
			selectedWasOnlineBeforeDisconnecting = [entry wasOnlineBeforeDisconnecting];
		
		// Skip offline and "ignore_presences" (sapo:agents) entries from here on. The avatar is selected
		// before bailing out so that we can still select the first offline 
		if ([entry presenceShouldBeIgnored] || entryStatus == LPStatusOffline)
			continue;
		
		// Select a status
		if (selectedStatus == LPStatusOffline && entryStatus != LPStatusOffline)
			selectedStatus = entryStatus;
		
		// Select a status message
		if (selectedStatusMessage == nil) {
			NSString *entryMessage = [entry statusMessage];
			if (entryMessage && [entryMessage length] > 0) {
				selectedStatusMessage = entryMessage;
			}
		}
	}
	
	// Sanitize the properties to default values if needed
	NSImage *selectedAvatar = nil;
	
	if (selectedEntryForCustomAvatar) {
		selectedAvatar = ( selectedStatus != LPStatusOffline ?
						   [selectedEntryForCustomAvatar onlineAvatar] :
						   [selectedEntryForCustomAvatar offlineAvatar] );
	}
	else {
		if (mainEntry)
			selectedAvatar = [mainEntry avatar];
		else if ([m_smsContactEntries count] > 0)
			selectedAvatar = [[m_smsContactEntries objectAtIndex:0] avatar];
		else
			selectedAvatar = [NSImage imageNamed:@"defaultAvatar"];
	}
	if (selectedStatusMessage == nil)
		selectedStatusMessage = @"";
	
	// Finally update our properties
	m_wasOnlineBeforeDisconnecting = selectedWasOnlineBeforeDisconnecting;
	
	if (selectedAvatar != m_avatar) {
		[self willChangeValueForKey:@"avatar"];
		[m_avatar release];
		m_avatar = [selectedAvatar retain];
		[self didChangeValueForKey:@"avatar"];
	}
	if (selectedStatus != m_status) {
		[self willChangeValueForKey:@"status"];
		m_status = selectedStatus;
		[self didChangeValueForKey:@"status"];
	}
	if (selectedStatusMessage != m_statusMessage) {
		[self willChangeValueForKey:@"statusMessage"];
		[m_statusMessage release];
		m_statusMessage = [selectedStatusMessage copy];
		[self didChangeValueForKey:@"statusMessage"];
	}
}

- (int)p_indexForNewContactEntry:(LPContactEntry *)entry inArray:(NSArray *)list
{
	int newEntryMultiContactPriority = [entry multiContactPriority];
	int listCount = [list count];
	int destinationIndex;
	
	for (destinationIndex = 0; destinationIndex < listCount; ++destinationIndex) {
		LPContactEntry *entryAtIndex = [list objectAtIndex:destinationIndex];
		int multiContactPriorityAtIndex = [entryAtIndex multiContactPriority];
		
		if ((multiContactPriorityAtIndex > newEntryMultiContactPriority) ||
			( (multiContactPriorityAtIndex == newEntryMultiContactPriority) &&
			  ([[entry address] caseInsensitiveCompare:[entryAtIndex address]] == NSOrderedAscending) ))
		{
			break;
		}
	}
	
	return destinationIndex;
}

- (void)p_classifyContactEntry:(LPContactEntry *)entry
{
	int			index;
	NSIndexSet	*changedIndexes;
	BOOL		canChat = [entry canDoChat];
	BOOL		canSMS = [entry canDoSMS];
	
	index = [m_chatContactEntries indexOfObject:entry];
	if (index == NSNotFound && canChat) {
		index = [self p_indexForNewContactEntry:entry inArray:m_chatContactEntries];
		changedIndexes = [NSIndexSet indexSetWithIndex:index];
		
		[self willChange:NSKeyValueChangeInsertion valuesAtIndexes:changedIndexes forKey:@"chatContactEntries"];
		[m_chatContactEntries insertObject:entry atIndex:index];
		[self didChange:NSKeyValueChangeInsertion valuesAtIndexes:changedIndexes forKey:@"chatContactEntries"];
	}
	else if (index != NSNotFound && !canChat) {
		changedIndexes = [NSIndexSet indexSetWithIndex:index];
		
		[self willChange:NSKeyValueChangeRemoval valuesAtIndexes:changedIndexes forKey:@"chatContactEntries"];
		[m_chatContactEntries removeObjectAtIndex:index];
		[self didChange:NSKeyValueChangeRemoval valuesAtIndexes:changedIndexes forKey:@"chatContactEntries"];
	}
	
	
	index = [m_smsContactEntries indexOfObject:entry];
	if (index == NSNotFound && canSMS) {
		index = [self p_indexForNewContactEntry:entry inArray:m_smsContactEntries];
		changedIndexes = [NSIndexSet indexSetWithIndex:index];
		
		[self willChange:NSKeyValueChangeInsertion valuesAtIndexes:changedIndexes forKey:@"smsContactEntries"];
		[m_smsContactEntries insertObject:entry atIndex:index];
		[self didChange:NSKeyValueChangeInsertion valuesAtIndexes:changedIndexes forKey:@"smsContactEntries"];
	}
	else if (index != NSNotFound && !canSMS) {
		changedIndexes = [NSIndexSet indexSetWithIndex:index];
		
		[self willChange:NSKeyValueChangeRemoval valuesAtIndexes:changedIndexes forKey:@"smsContactEntries"];
		[m_smsContactEntries removeObjectAtIndex:index];
		[self didChange:NSKeyValueChangeRemoval valuesAtIndexes:changedIndexes forKey:@"smsContactEntries"];
	}
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:@"avatar"] ||
		[keyPath isEqualToString:@"statusMessage"])
	{
		// Propagate changes
		[self p_recalculateContactProperties];
	}
	else if ([keyPath isEqualToString:@"status"]) {
		// Propagate changes
		[self p_recalculateContactProperties];
		[self willChangeValueForKey:@"mainContactEntry"];
		[self didChangeValueForKey:@"mainContactEntry"];
	}
	else if ([keyPath isEqualToString:@"capabilitiesFlags"]) {
		[self p_classifyContactEntry:object];
		[self p_recalculateContactProperties];
	}
	else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

- (NSString *)name
{
	return [[m_name copy] autorelease];
}

- (void)setName:(NSString *)newName
{
	[LFAppController rosterContactRename:[self ID] name:newName];
}

- (NSString *)altName
{
	return [[m_altName copy] autorelease];
}

- (void)setAltName:(NSString *)newAltName
{
	[LFAppController rosterContactSetAlt:[self ID] altName:newAltName];
}

- (NSImage *)avatar
{
	return [[m_avatar retain] autorelease];
}

- (NSImage *)framedAvatar
{
	return [m_avatar framedAvatarImage];
}

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
	return ([self status] != LPStatusOffline);
}

- (BOOL)isInUserRoster
{
	BOOL inUserRoster = YES;
	NSEnumerator *groupEnum = [[self groups] objectEnumerator];
	LPGroup *group;
	
	while (group = [groupEnum nextObject]) {
		if ([group type] == LPNotInListGroupType) {
			inUserRoster = NO;
			break;
		}
	}
	return inUserRoster;
}

- (BOOL)wasOnlineBeforeDisconnecting
{
	return m_wasOnlineBeforeDisconnecting;
}

- (BOOL)canDoChat
{
	return [[self contactEntries] someItemInArrayPassesCapabilitiesPredicate:@selector(canDoChat)];
}

- (BOOL)canDoSMS
{
	return [[self contactEntries] someItemInArrayPassesCapabilitiesPredicate:@selector(canDoSMS)];
}

- (BOOL)canDoMUC
{
	return [[self contactEntries] someItemInArrayPassesCapabilitiesPredicate:@selector(canDoMUC)];
}

- (BOOL)canDoFileTransfer
{
	return [[self contactEntries] someItemInArrayPassesCapabilitiesPredicate:@selector(canDoFileTransfer)];
}

- (BOOL)isRosterContact
{
	BOOL result = NO;
	NSEnumerator *entryEnumerator = [[self contactEntries] objectEnumerator];
	LPContactEntry *entry;
	
	while (entry = [entryEnumerator nextObject]) {
		if ([entry isRosterContact]) {
			result = YES;
			break;
		}
	}
	return result;
}

- (NSArray *)groups
{
	return [[m_groups copy] autorelease];
}

- (NSArray *)contactEntries
{
	return [[m_contactEntries copy] autorelease];
}

- (LPContactEntry *)mainContactEntry
{
	LPContactEntry *entry = [self preferredContactEntry];
	
	if (entry && [entry isOnline]) {
		return entry;
	}
	else {
		NSEnumerator *entryEnum = [m_chatContactEntries objectEnumerator];
		
		while (entry = [entryEnum nextObject])
			if ([entry isOnline])
				break;
		
		if (entry == nil && [m_chatContactEntries count] > 0)
			entry = [m_chatContactEntries objectAtIndex:0];
		
		return [[entry retain] autorelease];
	}
}

- (LPContactEntry *)preferredContactEntry
{
	return [[m_preferredContactEntry retain] autorelease];
}

- (void)setPreferredContactEntry:(LPContactEntry *)entry
{
	if (entry != m_preferredContactEntry) {
		[m_preferredContactEntry release];
		m_preferredContactEntry = [entry retain];
		
		// Select the properties for the contact from the properties of all the available contact entries
		[self p_recalculateContactProperties];
	}
}

- (NSArray *)chatContactEntries
{
	return [[m_chatContactEntries retain] autorelease];
}

- (NSArray *)smsContactEntries
{
	return [[m_smsContactEntries retain] autorelease];
}

- (LPContactEntry *)p_firstContactEntryHavingCapsFeature:(NSString *)capsFeature negateTest:(BOOL)neg
{
	LPContactEntry *entry = nil;
	NSEnumerator *entryEnumerator = [[self contactEntries] objectEnumerator];
	
	while (entry = [entryEnumerator nextObject]) {
		BOOL hasFeature = [entry hasCapsFeature:capsFeature];
		if (neg ? !hasFeature : hasFeature) break;
	}
	
	return entry;
}

- (LPContactEntry *)firstContactEntryWithCapsFeature:(NSString *)capsFeature
{
	return [self p_firstContactEntryHavingCapsFeature:capsFeature negateTest:NO];
}

- (LPContactEntry *)firstContactEntryWithoutCapsFeature:(NSString *)capsFeature
{
	return [self p_firstContactEntryHavingCapsFeature:capsFeature negateTest:YES];
}

- (BOOL)p_someEntryHasCapsFeature:(NSString *)capsFeature negateTest:(BOOL)neg
{
	return ([self p_firstContactEntryHavingCapsFeature:capsFeature negateTest:neg] != nil);
}

- (BOOL)someEntryHasCapsFeature:(NSString *)capsFeature
{
	return [self p_someEntryHasCapsFeature:capsFeature negateTest:NO];
}

- (BOOL)someEntryDoesntHaveCapsFeature:(NSString *)capsFeature
{
	return [self p_someEntryHasCapsFeature:capsFeature negateTest:YES];
}

- (void)moveFromGroup:(LPGroup *)originGroup toGroup:(LPGroup *)destinationGroup
{
	NSAssert([[self groups] containsObject:originGroup], @"The contact is not a member of the specified 'originGroup'.");
	[LFAppController rosterContactChangeGroup:[self ID] origin:[originGroup ID] destination:[destinationGroup ID]];
}

- (LPContactEntry *)addNewContactEntryWithAddress:(NSString *)address account:(LPAccount *)account reason:(NSString *)reason
{
	LPContactEntry *entry = [LPContactEntry entryWithAddress:address account:account];
	[self addContactEntry:entry reason:reason];
	return entry;
}

- (void)addContactEntry:(LPContactEntry *)entry reason:(NSString *)reason
{
	NSParameterAssert(entry);
	NSAssert(([self roster] != nil), @"The contact must belong to a roster before an entry can be added");
	NSAssert(([entry roster] == nil), @"The entry can't already belong to a roster");
	NSAssert1(([[self roster] contactEntryForAddress:[entry address] account:[entry account] searchOnlyUserAddedEntries:YES] == nil),
			  @"There is already a contact entry having address \"%@\"", [entry address]);
	
	int entryID = [[LFAppController rosterEntryAddToContact:[self ID]
													address:[entry address]
												accountUUID:[[entry account] UUID]
													 myNick:[[entry account] name]
													 reason:reason
														pos:(-1)] intValue];
	
	if (entryID != LPInvalidID) {
		/* We will add it to the roster indexes right away because if we only did that in the 
		leapfrogBridge_rosterEntryAdded method of the roster, a new LPContactEntry instance would
		be created. But we want to keep and index this one. */
		[[self roster] registerContactEntry:entry forID:entryID];
	}
	
	// Connect them both right away so that operations that depend on this relationship can work as expected
	[self handleAdditionOfEntry:entry];
	[entry handleAdditionToContact:self];
}

- (void)removeContactEntry:(LPContactEntry *)entry
{
	NSParameterAssert(entry);
	NSAssert(([entry contact] == self), @"The entry doesn't belong to this contact");
	
	[LFAppController rosterEntryRemove:[entry ID]];
}

#pragma mark -
#pragma mark Roster Events Handlers


- (void)handleContactChangedWithProperties:(NSDictionary *)properties
{
	[self willChangeValueForKey:@"name"];
	[m_name release];
	m_name = [[properties objectForKey:@"name"] copy];
	[self didChangeValueForKey:@"name"];

	[self willChangeValueForKey:@"altName"];
	[m_altName release];
	m_altName = [[properties objectForKey:@"altName"] copy];
	[self didChangeValueForKey:@"altName"];
}

- (void)handleAdditionToGroup:(LPGroup *)group
{
	if (![m_groups containsObject:group]) {
		NSIndexSet *changedIndexes = [NSIndexSet indexSetWithIndex:[m_groups count]];
		
		[self willChange:NSKeyValueChangeInsertion valuesAtIndexes:changedIndexes forKey:@"groups"];
		[m_groups addObject:group];
		[self didChange:NSKeyValueChangeInsertion valuesAtIndexes:changedIndexes forKey:@"groups"];
	}
}

- (void)handleRemovalFromGroup:(LPGroup *)group
{
	if ([m_groups containsObject:group]) {
		NSIndexSet *changedIndexes = [NSIndexSet indexSetWithIndex:[m_groups indexOfObject:group]];
		
		[self willChange:NSKeyValueChangeRemoval valuesAtIndexes:changedIndexes forKey:@"groups"];
		[m_groups removeObject:group];
		[self didChange:NSKeyValueChangeRemoval valuesAtIndexes:changedIndexes forKey:@"groups"];
	}
}

- (void)handleAdditionOfEntry:(LPContactEntry *)entry
{
	if (![m_contactEntries containsObject:entry]) {
		int index = [self p_indexForNewContactEntry:entry inArray:m_contactEntries];
		NSIndexSet *changedIndexes = [NSIndexSet indexSetWithIndex:index];
		
		[self willChange:NSKeyValueChangeInsertion valuesAtIndexes:changedIndexes forKey:@"contactEntries"];
		[m_contactEntries insertObject:entry atIndex:index];
		[self didChange:NSKeyValueChangeInsertion valuesAtIndexes:changedIndexes forKey:@"contactEntries"];
		
		[self p_classifyContactEntry:entry];	
		
		[entry addObserver:self forKeyPath:@"avatar" options:0 context:NULL];
		[entry addObserver:self forKeyPath:@"status" options:0 context:NULL];
		[entry addObserver:self forKeyPath:@"statusMessage" options:0 context:NULL];
		[entry addObserver:self forKeyPath:@"capabilitiesFlags" options:0 context:NULL];
		
		// Select the properties for the contact from the properties of all the available contact entries
		[self p_recalculateContactProperties];
	}
}

- (void)handleRemovalOfEntry:(LPContactEntry *)entry
{
	if ([m_contactEntries containsObject:entry]) {
		[entry removeObserver:self forKeyPath:@"avatar"];
		[entry removeObserver:self forKeyPath:@"status"];
		[entry removeObserver:self forKeyPath:@"statusMessage"];
		[entry removeObserver:self forKeyPath:@"capabilitiesFlags"];
		
		// Was it the preferred one?
		if (entry == m_preferredContactEntry)
			[self setPreferredContactEntry:nil];
		
		
		NSIndexSet *changedIndexes = [NSIndexSet indexSetWithIndex:[m_contactEntries indexOfObject:entry]];
		
		[self willChange:NSKeyValueChangeRemoval valuesAtIndexes:changedIndexes forKey:@"contactEntries"];
		[m_contactEntries removeObject:entry];
		[self didChange:NSKeyValueChangeRemoval valuesAtIndexes:changedIndexes forKey:@"contactEntries"];
		
		
		if ([m_chatContactEntries containsObject:entry]) {
			NSIndexSet *chatChangedIndexes = [NSIndexSet indexSetWithIndex:[m_chatContactEntries indexOfObject:entry]];
			
			[self willChange:NSKeyValueChangeRemoval valuesAtIndexes:chatChangedIndexes forKey:@"chatContactEntries"];
			[m_chatContactEntries removeObject:entry];
			[self didChange:NSKeyValueChangeRemoval valuesAtIndexes:chatChangedIndexes forKey:@"chatContactEntries"];
		}
		
		
		if ([m_smsContactEntries containsObject:entry]) {
			NSIndexSet *smsChangedIndexes = [NSIndexSet indexSetWithIndex:[m_smsContactEntries indexOfObject:entry]];
			
			[self willChange:NSKeyValueChangeRemoval valuesAtIndexes:smsChangedIndexes forKey:@"smsContactEntries"];
			[m_smsContactEntries removeObject:entry];
			[self didChange:NSKeyValueChangeRemoval valuesAtIndexes:smsChangedIndexes forKey:@"smsContactEntries"];
		}
		
		
		if ([m_contactEntries count] == 0) {
			[[self roster] removeContact:self];
		}
		else {
			// Select the properties for the contact from the properties of all the available contact entries
			[self p_recalculateContactProperties];
		}
	}
}

@end
