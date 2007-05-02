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
@class LPEditContactController, LPContact, LPFileTransfersController, LPSapoAgentsDebugWinCtrl;
@class LPAvatarEditorController;
@class SUUpdater, CTBadge;
@class LPMessageCenter, LPMessageCenterWinController;
@class LPAccount, LPStatusMenuController;


@interface LPUIController : NSObject
{
	IBOutlet NSMenu				*m_statusMenu;
	IBOutlet NSMenu				*m_debugMenu;
	IBOutlet NSMenu				*m_groupsMenu;
	IBOutlet NSMenu				*m_addContactSupermenu;
	IBOutlet SUUpdater			*m_appUpdater;
	
	NSMenuItem					*m_XMLConsoleMenuItem;
	
	LPAccountsController		*m_accountsController;
	NSMutableDictionary			*m_statusMenuControllers; // Account UUID (NSString) --> Status Menu Controller (LPStatusMenuController)
	
	LPMessageCenter				*m_messageCenter;
	LPMessageCenterWinController *m_messageCenterWinController;
	
	NSMutableDictionary			*m_authorizationAlertsByJID;
	
	LPPrefsController			*m_prefsController;
	LPRosterController			*m_rosterController;
	LPAvatarEditorController	*m_avatarEditorController;
	LPFileTransfersController	*m_fileTransfersController;
	LPXmlConsoleController		*m_xmlConsoleController;
	LPSapoAgentsDebugWinCtrl	*m_sapoAgentsDebugWinCtrl;
	
	NSMutableDictionary			*m_chatControllersByContact;		// LPContact --> LPChatController
	NSMutableDictionary			*m_editContactControllersByContact;	// LPContact --> LPEditContactController
	NSMutableDictionary			*m_smsSendingControllersByContact;	// LPContact --> LPSendSMSController
	
	CTBadge						*m_appIconBadge;
	unsigned int				m_totalNrOfUnreadMessages;
	
	NSURL						*m_provideFeedbackURL;
}

- (LPStatusMenuController *)sharedStatusMenuControllerForAccount:(LPAccount *)account;

- (LPAccountsController *)accountsController;
- (LPRosterController *)rosterController;
- (LPAvatarEditorController *)avatarEditorController;
- (LPFileTransfersController *)fileTransfersController;
- (LPMessageCenterWinController *)messageCenterWindowController;

- (void)showWindowForChatWithContact:(LPContact *)contact;
- (void)showWindowForEditingContact:(LPContact *)contact;
- (void)showWindowForSendingSMSWithContact:(LPContact *)contact;

- (void)updateXMLConsoleMenuItemVisibility;

// Actions
- (IBAction)setStatusMessage:(id)sender;
- (IBAction)showRoster:(id)sender;
- (IBAction)showAvatarEditor:(id)sender;
- (IBAction)showFileTransfers:(id)sender;
- (IBAction)showMessageCenter:(id)sender;
- (IBAction)showXmlConsole:(id)sender;
- (IBAction)showSapoAgentsDebugWindow:(id)sender;
- (IBAction)reportBug:(id)sender;
- (IBAction)provideFeedback:(id)sender;

/*!
 * @abstract Application termination sequence helper.
 * @discussion This method is invoked from the alt thread to signal that the application can really terminate.
 * @param arg This is expected to be an NSNumber containing a boolean value that indicates whether the application
 *		should really be terminated or if the termination process should be cancelled.
 */
- (void)confirmPendingTermination:(id)arg;

@end
