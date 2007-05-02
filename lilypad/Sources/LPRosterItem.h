//
//  LPRosterItem.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


@class LPRoster;


@interface LPRosterItem : NSObject
{
	int			m_ID;
	LPRoster	*m_roster;
}

- (int)ID;
- (LPRoster *)roster;
- (void)setID:(int)ID roster:(LPRoster *)roster;

@end
