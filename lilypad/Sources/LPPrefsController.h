//
//  LPPrefsController.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Authors: Joao Pavao <jppavao@criticalsoftware.com>
//           Jason Kim <jason@512k.org>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//
//
// Manages the preferences window.
//

#import <Cocoa/Cocoa.h>
#import "JKPrefsController.h"


@class LPAccountsController;


@interface LPPrefsController : JKPrefsController
{
	IBOutlet NSView			*m_generalView;
	IBOutlet NSView			*m_accountView;
	IBOutlet NSView			*m_msnAccountView;
	IBOutlet NSView			*m_advancedView;
	IBOutlet NSWindow		*m_msnRegistrationSheet;
	IBOutlet NSController	*m_defaultAccountController;
	
	// General prefs:
	IBOutlet NSPopUpButton	*m_downloadsFolderPopUpButton;
	
	// MSN Account prefs:
	IBOutlet NSTextField	*m_msnTransportStatusView;
	IBOutlet NSButton		*m_msnRegistrationButton;
	IBOutlet NSButton		*m_msnLoginButton;
	IBOutlet NSTextField	*m_msnEmailField;
	IBOutlet NSTextField	*m_msnPasswordField;
	IBOutlet NSButton		*m_msnRegisterOKButton;
}
- (void)initializePrefPanes;
- (void)addAdvancedPrefsPane;

- (LPAccountsController *)accountsController;

// General prefs
- (IBAction)chooseDownloadsFolder:(id)sender;
- (IBAction)openChatTranscriptsFolder:(id)sender;

// MSN Account prefs
- (IBAction)registerMSNTransport:(id)sender;
- (IBAction)loginToMSNTransport:(id)sender;

- (IBAction)okRegisterMSN:(id)sender;
- (IBAction)cancelRegisterMSN:(id)sender;

// Advanced prefs
- (NSArray *)appcastFeeds;

@end
