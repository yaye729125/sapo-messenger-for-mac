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
	LPAccount	*m_account;
	NSString	*m_selectedHost;
	
	id			m_delegate;
	
	// Temporary data storage
	NSMutableDictionary			*m_chatRoomsInfo;
	
	// NIB stuff
	IBOutlet NSArrayController	*m_roomsArrayController;
	IBOutlet NSTableView		*m_table;
	IBOutlet NSTableColumn		*m_initiallySortedColumn;
}

- initWithDelegate:(id)delegate;

- (LPAccount *)account;
- (void)setAccount:(LPAccount *)account;
- (NSString *)selectedHost;
- (void)setSelectedHost:(NSString *)aHost;

- (NSArray *)roomsAvailableInSelectedHost;

- (void)setChatRoomsList:(NSArray *)chatRooms forHost:(NSString *)host;
- (void)setInfo:(NSDictionary *)roomInfo forRoomWithJID:(NSString *)roomJID;

- (IBAction)fetchChatRooms:(id)sender;
- (IBAction)joinRoom:(id)sender;

@end


@interface NSObject (LPChatRoomsListControllerDelegate)
- (void)chatRoomsListCtrl:(LPChatRoomsListController *)ctrl joinChatRoomWithJID:(NSString *)roomJID;
@end
