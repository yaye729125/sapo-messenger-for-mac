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


@interface LPJoinChatRoomWinController : NSWindowController
{
	id			m_delegate;
	
	NSString	*m_host;
	NSString	*m_room;
	NSString	*m_nickname;
	NSString	*m_password;
	
	BOOL		m_requestChatHistory;
}

- initWithDelegate:(id)delegate;

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

- (IBAction)join:(id)sender;
- (IBAction)cancel:(id)sender;

@end


@interface NSObject (LPJoinChatRoomWinControllerDelegate)
- (void)joinChatRoomWithParametersFromController:(LPJoinChatRoomWinController *)ctrl;
@end
