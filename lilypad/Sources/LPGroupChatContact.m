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
#import "LPGroupChat.h"


static NSString *UserPresentableNicknameUsingVerboseWhitespaceDescriptions	(NSString *rawNickname) __attribute__ ((unused));
static NSString *UserPresentableNicknameByMakingSpacesAtBothEndsVisible		(NSString *rawNickname) __attribute__ ((unused));


static NSString *
UserPresentableNicknameUsingVerboseWhitespaceDescriptions(NSString *rawNickname)
{
	NSMutableString *convertedNickname = [NSMutableString string];
	
	NSCharacterSet *whitespaceSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
	NSCharacterSet *nonWhitespaceSet = [whitespaceSet invertedSet];
	
	NSRange searchRange = NSMakeRange(0, [rawNickname length]);
	NSRange whitespaceRange;
	
	do {
		whitespaceRange = [rawNickname rangeOfCharacterFromSet:whitespaceSet options:0 range:searchRange];
		
		[convertedNickname appendString:[rawNickname substringWithRange:(whitespaceRange.location != NSNotFound ?
																		 NSMakeRange(searchRange.location,
																					 whitespaceRange.location - searchRange.location) :
																		 searchRange)]];
		
		if (whitespaceRange.location != NSNotFound) {
			searchRange.length -= whitespaceRange.location - searchRange.location;
			searchRange.location = whitespaceRange.location;
			
			NSRange nonWhitespaceRange = [rawNickname rangeOfCharacterFromSet:nonWhitespaceSet options:0 range:searchRange];
			
			// Replace it
			whitespaceRange.length = ( nonWhitespaceRange.location != NSNotFound ?
									  nonWhitespaceRange.location :
									  [rawNickname length] ) - whitespaceRange.location;
			
			[convertedNickname appendFormat:NSLocalizedString(@"(%d spaces)", @""), whitespaceRange.length];
			
			searchRange.location += whitespaceRange.length;
			searchRange.length -= whitespaceRange.length;
		}
	} while ((whitespaceRange.location != NSNotFound) && (searchRange.length > 0));
	
	return convertedNickname;
}


static NSString *
UserPresentableNicknameByMakingSpacesAtBothEndsVisible(NSString *rawNickname)
{
	NSMutableString *convertedNickname = [[rawNickname mutableCopy] autorelease];
	
	NSCharacterSet *whitespaceSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
	NSCharacterSet *nonWhitespaceSet = [whitespaceSet invertedSet];
	
	NSRange wholeStringRange = NSMakeRange(0, [rawNickname length]);
	NSRange foundRange;
	
	NSString *whitespaceGraphicalRepresentationStr = [NSString stringWithFormat:@"%C", 0x2423];
	
	// Left end
	foundRange = [rawNickname rangeOfCharacterFromSet:whitespaceSet options:NSAnchoredSearch];
	
	if (foundRange.location != NSNotFound) {
		foundRange = [rawNickname rangeOfCharacterFromSet:nonWhitespaceSet];
		
		int i;
		int startIndex = 0;
		int endIndex = ( foundRange.location != NSNotFound ? foundRange.location : wholeStringRange.length );
		
		for (i = startIndex; i < endIndex; ++i)
			[convertedNickname replaceCharactersInRange:NSMakeRange(i, 1) withString:whitespaceGraphicalRepresentationStr];
	}
	
	// Right end
	foundRange = [rawNickname rangeOfCharacterFromSet:whitespaceSet options:( NSAnchoredSearch | NSBackwardsSearch )];
	
	if (foundRange.location != NSNotFound) {
		foundRange = [rawNickname rangeOfCharacterFromSet:nonWhitespaceSet options:NSBackwardsSearch];
		
		int i;
		int startIndex = wholeStringRange.length - 1;
		int endIndex = ( foundRange.location != NSNotFound ? foundRange.location : -1 );
		
		for (i = startIndex; i > endIndex; --i)
			[convertedNickname replaceCharactersInRange:NSMakeRange(i, 1) withString:whitespaceGraphicalRepresentationStr];
	}
	
	return convertedNickname;
}


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

+ (LPGroupChatContact *)groupChatContactWithNickame:(NSString *)nickname realJID:(NSString *)jid role:(NSString *)role affiliation:(NSString *)affiliation groupChat:(LPGroupChat *)gc
{
	return [[[[self class] alloc] initWithNickname:nickname realJID:jid role:role affiliation:affiliation groupChat:gc] autorelease];
}

- initWithNickname:(NSString *)nickname realJID:(NSString *)jid role:(NSString *)role affiliation:(NSString *)affiliation groupChat:(LPGroupChat *)gc
{
	if (self = [super init]) {
		m_nickname = [nickname copy];
		m_userPresentableNickname = [UserPresentableNicknameByMakingSpacesAtBothEndsVisible(m_nickname) copy];
		m_realJID = [jid copy];
		m_role = [role copy];
		m_affiliation = [affiliation copy];
		
		m_groupChat = gc;
	}
	return self;
}

- (void)dealloc
{
	[m_nickname release];
	[m_userPresentableNickname release];
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

- (NSString *)userPresentableNickname
{
	return [[m_userPresentableNickname copy] autorelease];
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

- (NSString *)attributesDescription
{
	return ([self isGagged] ? NSLocalizedString(@"(gagged)", @"") : @"");
}

- (BOOL)isGagged
{
	return m_isGagged;
}

- (void)setGagged:(BOOL)flag
{
	m_isGagged = flag;
}

- (LPGroupChat *)groupChat
{
	return [[m_groupChat retain] autorelease];
}

- (NSString *)JIDInGroupChat
{
	return [NSString stringWithFormat:@"%@/%@", [[self groupChat] roomJID], [self nickname]];
}


- (void)handleChangedNickname:(NSString *)newNickname
{
	if (newNickname != m_nickname) {
		[self willChangeValueForKey:@"nickname"];
		[m_nickname release];
		m_nickname = [newNickname copy];
		[self didChangeValueForKey:@"nickname"];
		
		[self willChangeValueForKey:@"userPresentableNickname"];
		[m_userPresentableNickname release];
		m_userPresentableNickname = [UserPresentableNicknameByMakingSpacesAtBothEndsVisible(newNickname) copy];
		[self didChangeValueForKey:@"userPresentableNickname"];
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
