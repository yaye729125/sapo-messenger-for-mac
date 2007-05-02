//
//  LPRosterItem.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPRosterItem.h"


@implementation LPRosterItem

- init
{
	if (self = [super init])
		m_ID = LPInvalidID;
	return self;
}

- (int)ID
{
	return m_ID;
}

- (LPRoster *)roster
{
	return m_roster;
}

- (void)setID:(int)ID roster:(LPRoster *)roster
{
	[self willChangeValueForKey:@"ID"];
	m_ID = ID;
	[self didChangeValueForKey:@"ID"];
	
	[self willChangeValueForKey:@"roster"];
	m_roster = roster;
	[self didChangeValueForKey:@"roster"];
}

@end
