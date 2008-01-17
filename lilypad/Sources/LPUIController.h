//
//  LPUIController.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Authors: Joao Pavao <jppavao@criticalsoftware.com>
//           Jason Kim <jason@512k.org>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


@class LPPrefsController, LPRosterController, LPXmlConsoleController, LPAccountsController;
@class LPEditContactController, LPContact, LPContactEntry, LPFileTransfersController, LPSapoAgentsDebugWinCtrl;
@class LPAvatarEditorController;
@class SUUpdater, CTBadge;
@class LPMessageCenter, LPMessageCenterWinController;
@class LPAccount, LPStatusMenuController;
@class LPChatRoomsListController, LPJoinChatRoomWinController;
@class LPGroupChat;


@interface LPUIController : NSObject
{
	IBOutlet NSMenu				*m_statusMenu;
	IBOutlet NSMenu				*m_debugMenu;
	IBOutlet NSMenu				*m_groupsMenu;
	IBOutlet NSMenu				*m_addContactSupermenu;
	IBOutlet NSMenu				*m_xmlConsolesPerAccountMenu;
	IBOutlet NSMenu				*m_discoDebugWindowsPerAccountMenu;
	IBOutlet SUUpdater			*m_appUpdater;
	
	LPAccountsController		*m_accountsController;
	LPStatusMenuController		*m_globalStatusMenuController;
	NSMutableDictionary			*m_statusMenuControllers; // Account UUID (NSString) --> Status Menu Controller (LPStatusMenuController)
	
	LPMessageCenter				*m_messageCenter;
	LPMessageCenterWinController *m_messageCenterWinController;
	
	NSMutableDictionary			*m_authorizationAlertsByJID;
	
	IBOutlet LPPrefsController	*m_prefsController;
	LPRosterController			*m_rosterController;
	LPAvatarEditorController	*m_avatarEditorController;
	LPFileTransfersController	*m_fileTransfersController;
	
	LPJoinChatRoomWinController	*m_joinChatRoomController;
	LPChatRoomsListController	*m_chatRoomsListController;
	
	NSMutableArray				*m_smsSendingControllers;
	NSMutableDictionary			*m_chatControllersByContact;		// LPContact --> LPChatController
	NSMutableDictionary			*m_editContactControllersByContact;	// LPContact --> LPEditContactController
	NSMutableDictionary			*m_groupChatControllersByAccountAndRoomJID;	// NSString (account UUID) --> NSMutDict
																			//    NSString (room JID) --> LPGroupChatController
	
	NSMutableDictionary			*m_xmlConsoleControllersByAccountUUID;		// NSString --> LPXmlConsoleController
	NSMutableDictionary			*m_sapoAgentsDebugWinCtrlsByAccountUUID;	// NSString --> LPSapoAgentsDebugWinCtrl
	
	CTBadge						*m_appIconBadge;
	unsigned int				m_totalNrOfUnreadMessages;
	
	NSURL						*m_provideFeedbackURL;
}

- (LPStatusMenuController *)globalStatusMenuController;
- (LPStatusMenuController *)sharedStatusMenuControllerForAccount:(LPAccount *)account;

- (LPAccountsController *)accountsController;
- (LPRosterController *)rosterController;
- (LPAvatarEditorController *)avatarEditorController;
- (LPFileTransfersController *)fileTransfersController;
- (LPMessageCenterWinController *)messageCenterWindowController;
- (LPJoinChatRoomWinController *)joinChatRoomWindowController;
- (LPChatRoomsListController *)chatRoomsListWindowController;

- (LPXmlConsoleController *)xmlConsoleForAccount:(LPAccount *)account;
- (LPSapoAgentsDebugWinCtrl *)sapoAgentsDebugWindowCtrlForAccount:(LPAccount *)account;

- (void)showWindowForChatWithContact:(LPContact *)contact;
- (void)showWindowForChatWithContactEntry:(LPContactEntry *)contactEntry;
- (void)showWindowForEditingContact:(LPContact *)contact;
- (void)showWindowForSendingSMSWithContacts:(NSArray *)contacts;
- (void)showWindowForGroupChat:(LPGroupChat *)groupChat;

- (void)enableDebugMenu;
- (BOOL)enableDebugMenuAndXMLConsoleIfModifiersCombinationIsPressedForAccount:(LPAccount *)account;

- (void)updateDefaultsFromBuild:(NSString *)fromBuild toCurrentBuild:(NSString *)toBuild;
- (void)enableCheckForUpdates;

- (LPGroupChat *)createNewInstantChatRoomAndShowWindow;

- (NSMenu *)pendingEventsMenu;
- (void)updateApplicationDockIconBadges;

// Actions
- (IBAction)toggleDisplayEmoticonImages:(id)sender;
- (IBAction)setStatusMessage:(id)sender;
- (IBAction)showRoster:(id)sender;
- (IBAction)showAvatarEditor:(id)sender;
- (IBAction)showFileTransfers:(id)sender;
- (IBAction)showMessageCenter:(id)sender;
- (IBAction)newChatWithPerson:(id)sender;
- (IBAction)newInstantChatRoom:(id)sender;
- (IBAction)showJoinChatRoom:(id)sender;
- (IBAction)showChatRoomsList:(id)sender;
- (IBAction)provideFeedback:(id)sender;
- (IBAction)showJoinChatRoom:(id)sender;

- (IBAction)showLicenseText:(id)sender;

// Debug Menu Actions
- (IBAction)showXmlConsole:(id)sender;
- (IBAction)showSapoAgentsDebugWindow:(id)sender;
- (IBAction)addAdvancedPrefsPane:(id)sender;
- (IBAction)toggleExtendedGetInfoWindow:(id)sender;
- (IBAction)toggleShowNonRosterContacts:(id)sender;
- (IBAction)toggleShowHiddenGroups:(id)sender;
- (IBAction)reportBug:(id)sender;
- (IBAction)showChatRoomsList:(id)sender;


/*!
 * @abstract Application termination sequence helper.
 * @discussion This method is invoked from the alt thread to signal that the application can really terminate.
 * @param arg This is expected to be an NSNumber containing a boolean value that indicates whether the application
 *		should really be terminated or if the termination process should be cancelled.
 */
- (void)confirmPendingTermination:(id)arg;

@end
