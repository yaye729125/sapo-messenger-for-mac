//
//  LPChatRoomsListController.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPChatRoomsListController.h"
#import "LPAccount.h"

#import "LFAppController.h"


@implementation LPChatRoomsListController

- init
{
	return [self initWithWindowNibName:@"ChatRoomsList"];
}

- (void)dealloc
{
	[m_chatRooms release];
	[m_account release];
	[super dealloc];
}

- (void)awakeFromNib
{
	[m_roomsArrayController setSortDescriptors:[NSArray arrayWithObject:[m_roomsTableColumn sortDescriptorPrototype]]];
}

- (LPAccount *)account
{
	return m_account;
}

- (void)setAccount:(LPAccount *)account
{
	[m_account release];
	m_account = [account retain];
}

- (NSArray *)chatRooms
{
	return m_chatRooms;
}

- (void)setChatRooms:(NSArray *)chatRooms
{
	if (chatRooms != m_chatRooms) {
		[m_chatRooms release];
		m_chatRooms = [chatRooms retain];
	}
}

- (IBAction)fetchChatRooms:(id)sender
{
#warning USING LFAppController DIRECTLY
	[LFAppController fetchChatRoomsList];
}

@end
