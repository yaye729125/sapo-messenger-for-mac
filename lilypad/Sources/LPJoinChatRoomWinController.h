//
//  LPJoinChatRoomWinController.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


@class LPAccountsController;
@class LPAccount;
@class LPGroupChat;


@interface LPJoinChatRoomWinController : NSWindowController
{
	id			m_delegate;
	
	LPAccount	*m_account;
	
	NSString	*m_host;
	NSString	*m_room;
	NSString	*m_nickname;
	NSString	*m_password;
	
	BOOL		m_requestChatHistory;
	
	// NIB stuff
	IBOutlet NSView				*m_advancedOptionsView;
	IBOutlet NSArrayController	*m_accountsCtrl;
}

- initWithDelegate:(id)delegate;

- (LPAccountsController *)accountsController;

- (LPAccount *)account;
- (void)setAccount:(LPAccount *)account;

- (NSString *)host;
- (void)setHost:(NSString *)aHost;
- (NSString *)room;
- (void)setRoom:(NSString *)aRoom;
- (NSString *)nickname;
- (void)setNickname:(NSString *)aNickname;
- (NSString *)password;
- (void)setPassword:(NSString *)aPassword;
- (BOOL)requestChatHistory;
- (void)setRequestChatHistory:(BOOL)flag;

- (NSString *)roomJID;
- (BOOL)canJoin;

- (IBAction)join:(id)sender;
- (IBAction)cancel:(id)sender;

- (IBAction)toggleAdvancedOptionsView:(id)sender;

@end


@interface NSObject (LPJoinChatRoomWinControllerDelegate)
- (void)joinController:(LPJoinChatRoomWinController *)joinCtrl showWindowForChatRoom:(LPGroupChat *)groupChat;
@end
