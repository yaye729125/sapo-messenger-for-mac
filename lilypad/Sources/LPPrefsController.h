//
//  LPPrefsController.h
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Authors: Joao Pavao <jpavao@co.sapo.pt>
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
	IBOutlet NSView				*m_generalView;
	IBOutlet NSView				*m_accountsView;
	IBOutlet NSView				*m_advancedView;
	IBOutlet NSWindow			*m_msnRegistrationSheet;
	IBOutlet NSController		*m_defaultAccountController;
	IBOutlet NSArrayController	*m_accountsController;
	
	// General prefs:
	IBOutlet NSPopUpButton		*m_downloadsFolderPopUpButton;
	
	IBOutlet NSPopUpButton		*m_defaultURLHandlerPopUpButton;
	BOOL						m_needsToUpdateURLHandlerMenu;
	
	// Accounts prefs:
	IBOutlet NSTableView		*m_accountsTable;
	IBOutlet NSTabView			*m_accountTabView;
	IBOutlet NSPopUpButton		*m_accountKindPopUp;
	IBOutlet NSTextField		*m_accountJIDLabel;
	IBOutlet NSTextField		*m_accountJIDField;
	IBOutlet NSTextField		*m_accountJIDDomainLabel;
	
	// MSN Account prefs:
	IBOutlet NSTextField		*m_msnTransportStatusView;
	IBOutlet NSButton			*m_msnRegistrationButton;
	IBOutlet NSButton			*m_msnLoginButton;
	IBOutlet NSTextField		*m_msnEmailField;
	IBOutlet NSTextField		*m_msnPasswordField;
	IBOutlet NSButton			*m_msnRegisterOKButton;
}

- (void)initializePrefPanes;
- (void)addAdvancedPrefsPane;

- (LPAccountsController *)accountsController;

// General prefs
- (IBAction)chooseDownloadsFolder:(id)sender;
- (IBAction)openChatTranscriptsFolder:(id)sender;

- (NSString *)defaultURLHandlerBundleID;
- (void)setDefaultURLHandlerBundleID:(NSString *)bundleID;

// Accounts prefs
- (IBAction)addAccount:(id)sender;
- (IBAction)removeAccount:(id)sender;
- (IBAction)accountKindSelectionDidChange:(id)sender;

// MSN Account prefs
- (IBAction)registerMSNTransport:(id)sender;
- (IBAction)loginToMSNTransport:(id)sender;

- (IBAction)okRegisterMSN:(id)sender;
- (IBAction)cancelRegisterMSN:(id)sender;

// Advanced prefs
- (NSArray *)appcastFeeds;

@end
