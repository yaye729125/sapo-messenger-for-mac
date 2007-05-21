//
//  LPChatRoomsListController.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


@class LPAccount;


@interface LPChatRoomsListController : NSWindowController
{
	NSArray		*m_chatRooms;
	LPAccount	*m_account;
	
	// NIB stuff
	IBOutlet NSArrayController	*m_roomsArrayController;
	IBOutlet NSTableColumn		*m_roomsTableColumn;
}

- (LPAccount *)account;
- (void)setAccount:(LPAccount *)account;
- (NSArray *)chatRooms;
- (void)setChatRooms:(NSArray *)chatRooms;

- (IBAction)fetchChatRooms:(id)sender;

@end
