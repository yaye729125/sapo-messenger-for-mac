//
//  LPPrefsController.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Authors: Joao Pavao <jppavao@criticalsoftware.com>
//           Jason Kim <jason@512k.org>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPPrefsController.h"
#import "LPKeychainManager.h"
#import "LPAccountsController.h"
#import "LPAccount.h"
#import "LPSapoAgents.h"


@interface LPPrefsController (Private)
- (void)p_updateDownloadsFolderMenu;
- (void)p_updateGUIForTransportAgent:(NSString *)transportAgent ofAccount:(LPAccount *)account;
- (void)p_setButtonEnabled:(NSButton *)btn afterDelay:(float)delay;
- (void)p_setButtonDisabledAndCancelTimer:(NSButton *)btn;
@end


@implementation LPPrefsController

+ (void)initialize
{
	[[NSUserDefaults standardUserDefaults] registerDefaults:
		[NSDictionary dictionaryWithObject:[NSHomeDirectory() stringByAppendingPathComponent:@"Desktop"]
									forKey:@"DownloadsFolder"]];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[m_generalView release];
	[m_accountView release];
	[m_msnAccountView release];
	[m_advancedView release];
	[m_msnRegistrationSheet release];
	[m_defaultAccountController release];
	
	[super dealloc];
}

- (void)initializePrefPanes
{
	[self addPrefWithView:m_generalView
					label:NSLocalizedString(@"General", @"preference pane label")
					image:[NSImage imageNamed:@"GeneralPrefs"]
			   identifier:@"GeneralPrefs"];
	
	[self addPrefWithView:m_accountView
					label:NSLocalizedString(@"Accounts", @"preference pane label")
					image:[NSImage imageNamed:@"AccountPrefs"]
			   identifier:@"AccountPrefs"];
	
	[self addPrefWithView:m_msnAccountView
					label:NSLocalizedString(@"MSN Account", @"preference pane label")
					image:[NSImage imageNamed:@"MSNPrefs"]
			   identifier:@"MSNPrefs"];
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"IncludeAdvancedPrefs"]) {
		[self addAdvancedPrefsPane];
	}
}

- (void)addAdvancedPrefsPane
{
	[self addPrefWithView:m_advancedView
					label:NSLocalizedString(@"Advanced", @"preference pane label")
					image:[NSImage imageNamed:@"AdvancedPrefs"]
			   identifier:@"AdvancedPrefs"];
}

- (LPAccountsController *)accountsController
{
	return [LPAccountsController sharedAccountsController];
}

- (void)p_updateDownloadsFolderMenu
{
	id			folderItem = [m_downloadsFolderPopUpButton itemAtIndex:0];
	NSString	*folderPath = [[NSUserDefaults standardUserDefaults] stringForKey:@"DownloadsFolder"];
	NSString	*folderDisplayName = [[NSFileManager defaultManager] displayNameAtPath:folderPath];
	NSImage		*folderImage = [[NSWorkspace sharedWorkspace] iconForFile:folderPath];
	
	[folderImage setSize:NSMakeSize(16.0, 16.0)];
	
	[folderItem setTitle:folderDisplayName];
	[folderItem setImage:folderImage];
}

- (void)loadNib
{
	LPAccount	*account = [[self accountsController] defaultAccount];
	NSString	*transportAgent = [[account sapoAgents] hostnameForService:@"msn"];
	
	[NSBundle loadNibNamed:@"Preferences" owner:self];
	
	[self p_updateDownloadsFolderMenu];
	[self p_updateGUIForTransportAgent:transportAgent ofAccount:account];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(accountDidChangeTransportInfo:)
												 name:LPAccountDidChangeTransportInfoNotification
											   object:account];
}


#pragma mark -
#pragma mark NSWindow Delegate Methods


- (void)windowDidResignKey:(NSNotification *)aNotification
{
	// Try to commit any text field editing session
	NSWindow *win = [self window];
	[win makeFirstResponder:win];
}

- (void)windowWillClose:(NSNotification *)aNotification
{
	// The default account controller isn't committing changes automatically upon window close. Maybe it's because the
	// views with the text fields are not inserted in any windows when the nib is loaded, I don't know. We'll have to
	// do it manually.
	[m_defaultAccountController commitEditing];
}


#pragma mark -
#pragma mark Actions - General Prefs


- (IBAction)chooseDownloadsFolder:(id)sender
{
	NSOpenPanel	*op = [NSOpenPanel openPanel];
	
	[op setCanChooseFiles:NO];
	[op setCanChooseDirectories:YES];
	[op setCanCreateDirectories:YES];

	[op setResolvesAliases:YES];
	[op setAllowsMultipleSelection:NO];
	[op setPrompt:NSLocalizedString(@"Select", @"")];
	
	[op beginSheetForDirectory:nil
						  file:nil
						 types:nil
				modalForWindow:[self window]
				 modalDelegate:self
				didEndSelector:@selector(p_selectDownloadsFolderPanelDidEnd:returnCode:contextInfo:)
				   contextInfo:NULL];
}

- (void)p_selectDownloadsFolderPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSOKButton) {
		[[NSUserDefaults standardUserDefaults] setObject:[panel filename] forKey:@"DownloadsFolder"];
		[self p_updateDownloadsFolderMenu];
	}
	
	// Finish by re-selecting the item that references the selected folder (the first one)
	[m_downloadsFolderPopUpButton selectItemAtIndex:0];
}


- (IBAction)openChatTranscriptsFolder:(id)sender
{
	NSString *folderPath = LPChatTranscriptsFolderPath();
	
	if (folderPath == nil) {
		NSBeep();
	}
	else {
		[[NSWorkspace sharedWorkspace] openFile:folderPath];
	}
}


#pragma mark -
#pragma mark Actions - MSN Account Prefs - Private


- (void)p_enableButton:(NSButton *)btn
{
	[btn setEnabled:YES];
}

- (void)p_setButtonEnabled:(NSButton *)btn afterDelay:(float)delay
{
	[btn setEnabled:NO];
	[self performSelector:@selector(p_enableButton:) withObject:btn afterDelay:delay];
}

- (void)p_setButtonDisabledAndCancelTimer:(NSButton *)btn
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(p_enableButton:) object:btn];
	[btn setEnabled:NO];
}


- (void)p_updateGUIForTransportAgent:(NSString *)transportAgent ofAccount:(LPAccount *)account
{
	BOOL		isRegistered = [account isRegisteredWithTransportAgent:transportAgent];
	NSString	*registeredUsername = [account usernameRegisteredWithTransportAgent:transportAgent];
	BOOL		isLoggedIn = [account isLoggedInWithTransportAgent:transportAgent];
	
	if ([account isOffline]) {
		[m_msnTransportStatusView setStringValue:
			NSLocalizedString(@"The current MSN state is unknown.",
							  @"MSN transport state description")];
		
		[m_msnRegistrationButton setTitle:NSLocalizedString(@"Register...", @"MSN transport preferences button")];
		[m_msnRegistrationButton setEnabled:NO];
		
		[m_msnLoginButton setTitle:NSLocalizedString(@"Log In", @"MSN transport preferences button")];
		[self p_setButtonDisabledAndCancelTimer:m_msnLoginButton];
	}
	else {
		if (!isRegistered) {
			[m_msnTransportStatusView setStringValue:
				NSLocalizedString(@"You're not currently registered to the MSN transport.",
								  @"MSN transport state description")];
			
			[m_msnRegistrationButton setTitle:NSLocalizedString(@"Register...", @"MSN transport preferences button")];
			[m_msnRegistrationButton setEnabled:YES];
			
			[m_msnLoginButton setTitle:NSLocalizedString(@"Log In", @"MSN transport preferences button")];
			[self p_setButtonDisabledAndCancelTimer:m_msnLoginButton];
		}
		else if (!isLoggedIn) {
			[m_msnTransportStatusView setStringValue:
				[NSString stringWithFormat:
					NSLocalizedString(@"You're currently registered to the MSN transport with the email \"%@\", but you're not logged in to the service.",
								  @"MSN transport state description"),
					registeredUsername]];
			
			[m_msnRegistrationButton setTitle:NSLocalizedString(@"Unregister...", @"MSN transport preferences button")];
			[m_msnRegistrationButton setEnabled:YES];
			
			[m_msnLoginButton setTitle:NSLocalizedString(@"Log In", @"MSN transport preferences button")];
			[self p_setButtonEnabled:m_msnLoginButton afterDelay:0.0];
		}
		else {
			[m_msnTransportStatusView setStringValue:
				[NSString stringWithFormat:
					NSLocalizedString(@"You're currently registered to the MSN transport with the email \"%@\" and you're logged in to the service.",
									  @"MSN transport state description"),
					registeredUsername]];
			
			[m_msnRegistrationButton setTitle:NSLocalizedString(@"Unregister...", @"MSN transport preferences button")];
			[m_msnRegistrationButton setEnabled:YES];
			
			[m_msnLoginButton setTitle:NSLocalizedString(@"Log In", @"MSN transport preferences button")];
			[self p_setButtonDisabledAndCancelTimer:m_msnLoginButton];
		}
	}
}


#pragma mark Actions - MSN Account Prefs - Public


- (IBAction)registerMSNTransport:(id)sender
{
	LPAccount	*account = [[self accountsController] defaultAccount];
	NSString	*transportAgent = [[account sapoAgents] hostnameForService:@"msn"];
	
	BOOL		isRegistered = [account isRegisteredWithTransportAgent:transportAgent];
	
	if ([account isOnline]) {
		if (!isRegistered) {
			// Register
			NSString *lastRegisteredEmail = [account lastRegisteredMSNEmail];
			NSString *lastRegisteredPassword = [account lastRegisteredMSNPassword];
			
			[m_msnEmailField setStringValue:(lastRegisteredEmail ? lastRegisteredEmail : @"")];
			[m_msnPasswordField setStringValue:(lastRegisteredPassword ? lastRegisteredPassword : @"")];
			
			[NSApp beginSheet:m_msnRegistrationSheet
			   modalForWindow:[self window]
				modalDelegate:self
			   didEndSelector:@selector(p_msnRegistrationSheetDidEnd:returnCode:contextInfo:)
				  contextInfo:NULL];
		}
		else {
			// Unregister
			NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Are you sure you want to unregister from the MSN transport?", @"Alert displayed when unregistering from the MSN transport")
											 defaultButton:NSLocalizedString(@"OK", @"")
										   alternateButton:NSLocalizedString(@"Cancel", @"")
											   otherButton:nil
								 informativeTextWithFormat:NSLocalizedString(@"All your MSN contacts will be removed from the SAPO Messenger buddy list when you unregister from the MSN transport. If you moved contacts to different groups, these changes will be lost. You can't undo this action.", @"Alert displayed when unregistering from the MSN transport")];
			
			[alert beginSheetModalForWindow:[self window]
							  modalDelegate:self
							 didEndSelector:@selector(p_msnUnregistrationAlertDidEnd:returnCode:contextInfo:)
								contextInfo:NULL];
		}
	}
}


- (void)p_msnRegistrationSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];
	
	if (returnCode == NSOKButton) {
		LPAccount	*account = [[self accountsController] defaultAccount];
		NSString	*transportAgent = [[account sapoAgents] hostnameForService:@"msn"];
		
		if ([account isOnline]) {
			[account registerWithTransportAgent:transportAgent
									   username:[m_msnEmailField stringValue]
									   password:[m_msnPasswordField stringValue]];
		}
	}
}


- (void)p_msnUnregistrationAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSAlertDefaultReturn) {
		LPAccount	*account = [[self accountsController] defaultAccount];
		NSString	*transportAgent = [[account sapoAgents] hostnameForService:@"msn"];
		
		if ([account isOnline]) {
			[account unregisterWithTransportAgent:transportAgent];
		}
	}
}


- (IBAction)loginToMSNTransport:(id)sender
{
	[self p_setButtonDisabledAndCancelTimer:m_msnLoginButton];
	[self p_setButtonEnabled:m_msnLoginButton afterDelay:10.0];
	
	// Send a dummy presence so that the MSN transport can connect
	LPAccount *account = [[self accountsController] defaultAccount];
	[account setTargetStatus:[account status]];
}


#pragma mark MSN Registration Sheet


- (IBAction)okRegisterMSN:(id)sender
{
	[NSApp endSheet:m_msnRegistrationSheet returnCode:NSOKButton];
}


- (IBAction)cancelRegisterMSN:(id)sender
{
	[NSApp endSheet:m_msnRegistrationSheet returnCode:NSCancelButton];
}


- (void)controlTextDidChange:(NSNotification *)aNotification
{
	[m_msnRegisterOKButton setEnabled:( ( [[m_msnEmailField stringValue] length] > 0 ) &&
										( [[m_msnPasswordField stringValue] length] > 0 ) )];
}


#pragma mark -
#pragma mark Account Notifications


- (void)accountDidChangeTransportInfo:(NSNotification *)notif
{
	NSString *transportAgent = [[notif userInfo] objectForKey:@"TransportAgent"];
	[self p_updateGUIForTransportAgent:transportAgent ofAccount:[notif object]];
}


@end
