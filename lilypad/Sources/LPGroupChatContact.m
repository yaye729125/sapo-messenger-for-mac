//
//  LPGroupChatContact.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPGroupChatContact.h"


@implementation NSString (RoleCompare)

- (NSComparisonResult)roleCompare:(NSString *)aContactRole
{
	static NSArray *orderedRoles = nil;
	if (orderedRoles == nil)
		orderedRoles = [[NSArray alloc] initWithObjects:@"visitor", @"participant", @"moderator", nil];
	
	int myRoleIndex = [orderedRoles indexOfObject:self];
	int otherContactRoleIndex = [orderedRoles indexOfObject:aContactRole];
	
	if (myRoleIndex == otherContactRoleIndex)
		return NSOrderedSame;
	else if (myRoleIndex < otherContactRoleIndex)
		return NSOrderedAscending;
	else
		return NSOrderedDescending;
}

@end


@implementation LPGroupChatContact

+ (LPGroupChatContact *)groupChatContactWithNickame:(NSString *)nickname realJID:(NSString *)jid role:(NSString *)role affiliation:(NSString *)affiliation
{
	return [[[[self class] alloc] initWithNickname:nickname realJID:jid role:role affiliation:affiliation] autorelease];
}

- initWithNickname:(NSString *)nickname realJID:(NSString *)jid role:(NSString *)role affiliation:(NSString *)affiliation
{
	if (self = [super init]) {
		m_nickname = [nickname copy];
		m_realJID = [jid copy];
		m_role = [role copy];
		m_affiliation = [affiliation copy];
	}
	return self;
}

- (void)dealloc
{
	[m_nickname release];
	[m_realJID release];
	[m_role release];
	[m_affiliation release];
	[m_statusMessage release];
	[super dealloc];
}

- (NSString *)nickname
{
	return [[m_nickname copy] autorelease];
}

- (NSString *)realJID
{
	return [[m_realJID copy] autorelease];
}

- (NSString *)role
{
	return [[m_role copy] autorelease];
}

- (NSString *)affiliation
{
	return [[m_affiliation copy] autorelease];
}

- (LPStatus)status
{
	return m_status;
}

- (NSString *)statusMessage
{
	return [[m_statusMessage copy] autorelease];
}


- (void)handleChangedNickname:(NSString *)newNickname
{
	if (newNickname != m_nickname) {
		[self willChangeValueForKey:@"nickname"];
		[m_nickname release];
		m_nickname = [newNickname copy];
		[self didChangeValueForKey:@"nickname"];
	}
}

- (void)handleChangedRole:(NSString *)newRole orAffiliation:(NSString *)newAffiliation
{
	if (newRole != m_role) {
		[self willChangeValueForKey:@"role"];
		[m_role release];
		m_role = [newRole copy];
		[self didChangeValueForKey:@"role"];
	}
	
	if (newAffiliation != m_affiliation) {
		[self willChangeValueForKey:@"affiliation"];
		[m_affiliation release];
		m_affiliation = [newAffiliation copy];
		[self didChangeValueForKey:@"affiliation"];
	}
}

- (void)handleChangedStatus:(LPStatus)newStatus statusMessage:(NSString *)message
{
	if (newStatus != m_status) {
		[self willChangeValueForKey:@"status"];
		m_status = newStatus;
		[self didChangeValueForKey:@"status"];
	}
	
	if (message != m_statusMessage) {
		[self willChangeValueForKey:@"statusMessage"];
		[m_statusMessage release];
		m_statusMessage = [message copy];
		[self didChangeValueForKey:@"statusMessage"];
	}
}

@end
