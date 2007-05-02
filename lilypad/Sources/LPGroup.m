//
//  LPGroup.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPGroup.h"
#import "LPContact.h"
#import "LPRoster.h"
#import "LFAppController.h"


static LPGroupType
LPGroupTypeFromTypeNameString (NSString *typeName)
{
	if ([typeName isEqualToString:@"NoGroup"]) {
		return LPNoGroupType;
	}
	else if ([typeName isEqualToString:@"User"]) {
		return LPUserGroupType;
	}
	else if ([typeName isEqualToString:@"Agents"]) {
		return LPAgentsGroupType;
	}
	else if ([typeName isEqualToString:@"NotInList"]) {
		return LPNotInListGroupType;
	}
	else {
		[NSException raise:@"LPInvalidGroupTypeStringException"
					format:@"The group type name string refers an unknown group type"];
		return -1;
	}
}


@implementation LPGroup

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key
{
	if ([key isEqualToString:@"name"]) {
		// We only want to notify of changes to "name" when the corresponding notification comes from the leapfrog
		// bridge and not when setName: is invoked.
		return NO;
	}
	else {
		return [super automaticallyNotifiesObserversForKey:key];
	}
}

+ groupWithName:(NSString *)name
{
	return [[[[self class] alloc] initWithName:name] autorelease];
}

- initWithName:(NSString *)name
{
	if (self = [super init]) {
		m_name = [name copy];
		m_contacts = [[NSMutableArray alloc] init];
	}
	return self;
}

- init
{
	return [self initWithName:nil];
}

- (void)dealloc
{
	[m_name release];
	[m_contacts release];
	[super dealloc];
}

// This doesn't copy anything, only increases the retain count of the instance
- (id)copyWithZone:(NSZone *)zone
{
	return [self retain];
}

- (LPGroupType)type
{
	return m_type;
}

- (NSString *)name
{
	return [[m_name copy] autorelease];
}

- (void)setName:(NSString *)newName
{
	[LFAppController rosterGroupRename:[self ID] name:newName];
}

- (NSArray *)contacts
{
	return [[m_contacts copy] autorelease];
}


- (LPContact *)addNewContactWithName:(NSString *)contactName
{
	LPContact *contact = [LPContact contactWithName:contactName];
	[self addContact:contact];
	return contact;
}


- (void)addContact:(LPContact *)contact
{
	NSParameterAssert(contact);
	NSAssert(([self roster] != nil),
			 @"The group must belong to a roster before a contact can be added");
	NSAssert((([contact roster] == [self roster]) || ([contact roster] == nil)),
			 @"The contact can't belong to a different roster");
	NSAssert1((([[self roster] contactForName:[contact name]] == nil)
			   || ([[self roster] contactForName:[contact name]] == contact)),
			  @"There is already a contact named \"%@\"", [contact name]);
	
	if ([contact roster] == nil) {
		// This contact isn't present in any roster yet
		int newContactID = [[LFAppController rosterContactAdd:[self ID] name:[contact name] pos:(-1)] intValue];
		
		if (newContactID != LPInvalidID) {
			/* We will add it to the roster indexes right away because if we only did that in the 
			leapfrogBridge_rosterContactAdded method of the roster, a new LPContact instance would
			be created. But we want to keep and index this one. */
			[[self roster] registerContact:contact forID:newContactID];
		}
	}
	else {
		// This contact was already present in some other group of the roster
		[LFAppController rosterContactAddGroup:[contact ID] groupId:[self ID]];
	}
}


- (void)removeContact:(LPContact *)contact
{
	NSParameterAssert(contact);
	NSAssert(([[contact groups] containsObject:self]), @"The contact doesn't belong to this group");
	
	[LFAppController rosterContactRemoveGroup:[contact ID] groupId:[self ID]];
}


#pragma mark -
#pragma mark Roster Events Handlers


- (void)handleGroupChangedWithProperties:(NSDictionary *)properties
{
	[self willChangeValueForKey:@"type"];
	m_type = LPGroupTypeFromTypeNameString([properties objectForKey:@"type"]);
	[self didChangeValueForKey:@"type"];
	
	[self willChangeValueForKey:@"name"];
	[m_name release];
	
	switch (m_type) {
		case LPNoGroupType:
			m_name = [[NSString alloc] initWithString:@"# NO GROUP # (header: debug only)"];
			break;
			
		case LPNotInListGroupType:
			m_name = [[NSString alloc] initWithString:@"# NOT IN LIST # (group: debug only)"];
			break;
			
		default:
			m_name = [[properties objectForKey:@"name"] copy];
	}
	[self didChangeValueForKey:@"name"];
}

- (void)handleAdditionOfContact:(LPContact *)contact
{
	[self willChangeValueForKey:@"contacts"];
	[m_contacts addObject:contact];
	[self didChangeValueForKey:@"contacts"];
}

- (void)handleRemovalOfContact:(LPContact *)contact
{
	[self willChangeValueForKey:@"contacts"];
	[m_contacts removeObject:contact];
	[self didChangeValueForKey:@"contacts"];
}

@end
