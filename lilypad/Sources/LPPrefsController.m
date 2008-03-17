//
//  LPPrefsController.m
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Authors: Joao Pavao <jpavao@co.sapo.pt>
//           Jason Kim <jason@512k.org>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPPrefsController.h"
#import "LPKeychainManager.h"
#import "LPAccountsController.h"
#import "LPAccount.h"
#import "LPAccountPrefsListCell.h"
#import "LPSapoAgents.h"
#import "NSString+ConcatAdditions.h"
#import "LPCommon.h"



static NSString *AccountUUIDsDraggedType = @"AccountUUIDsDraggedType";


@interface LPPrefsController (Private)

- (void)p_updateDownloadsFolderMenu;

- (NSSet *)p_allOurURLHandlersBundleIDs;
- (NSDictionary *)p_infoDictForURLHandlerWithBundleID:(NSString *)bundleID;
- (NSArray *)p_contentsOfOurURLHandlersMenu;
- (void)p_updateURLHandlersMenu;
- (void)p_updateURLHandlersMenuSelection;
- (void)p_selectedDefaultURLHandler:(id)sender;
- (void)p_selectOtherURLHandler:(id)sender;

- (LPAccount *)p_selectedAccount;
- (void)p_startObservingAccounts:(NSArray *)accounts;
- (void)p_stopObservingAccounts:(NSArray *)accounts;

- (void)p_updateGUIForMSNTransportAgentOfAccount:(LPAccount *)account;
- (void)p_updateGUIForTransportAgent:(NSString *)transportAgent ofAccount:(LPAccount *)account;
- (void)p_setButtonEnabled:(NSButton *)btn afterDelay:(float)delay;
- (void)p_setButtonDisabledAndCancelTimer:(NSButton *)btn;
@end


@implementation LPPrefsController

+ (void)initialize
{
	if (self == [LPPrefsController class]) {
		NSString	*downloadsFolderPath = nil;
		NSArray		*foundFolders = ((floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_4) ?
									 nil :
									 NSSearchPathForDirectoriesInDomains(NSDownloadsDirectory, NSUserDomainMask, YES));
		
		if ([foundFolders count] == 0) {
			foundFolders = NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES);
			if ([foundFolders count] == 0) {
				// Build the path manually (last resort)
				downloadsFolderPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Desktop"];
			}
		}
		
		if (downloadsFolderPath == nil && [foundFolders count] > 0)
			downloadsFolderPath = [foundFolders objectAtIndex:0];
		
		[[NSUserDefaults standardUserDefaults] registerDefaults:
		 [NSDictionary dictionaryWithObject:downloadsFolderPath forKey:@"DownloadsFolder"]];
	}
}

- (void)dealloc
{
	[self p_stopObservingAccounts:[[self accountsController] accounts]];
	[[self accountsController] removeObserver:self forKeyPath:@"accounts"];
	[m_accountsController removeObserver:self forKeyPath:@"selectedObjects"];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[m_generalView release];
	[m_accountsView release];
	[m_advancedView release];
	[m_msnRegistrationSheet release];
	[m_defaultAccountController release];
	[m_accountsController release];
	
	[super dealloc];
}

- (void)initializePrefPanes
{
	[self addPrefWithView:m_generalView
					label:NSLocalizedString(@"General", @"preference pane label")
					image:[NSImage imageNamed:@"GeneralPrefs"]
			   identifier:@"GeneralPrefs"];
	
	[self addPrefWithView:m_accountsView
					label:NSLocalizedString(@"Accounts", @"preference pane label")
					image:[NSImage imageNamed:@"AccountsPrefs"]
			   identifier:@"AccountsPrefs"];
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"IncludeAdvancedPrefs"]) {
		[self addAdvancedPrefsPane];
	}
}

- (void)addAdvancedPrefsPane
{
	[self showPrefs:nil];
	[self addPrefWithView:m_advancedView
					label:NSLocalizedString(@"Advanced", @"preference pane label")
					image:[NSImage imageNamed:@"AdvancedPrefs"]
			   identifier:@"AdvancedPrefs"];
}

- (LPAccountsController *)accountsController
{
	return [LPAccountsController sharedAccountsController];
}

- (void)loadNib
{
	[NSBundle loadNibNamed:@"Preferences" owner:self];
	
	
	// General Pane
	[self p_updateDownloadsFolderMenu];
	[self p_updateURLHandlersMenu];
	
	
	// Accounts Pane
	[[self accountsController] addObserver:self
								forKeyPath:@"accounts"
								   options:( NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew )
								   context:NULL];
	[self p_startObservingAccounts:[[self accountsController] accounts]];
	
	[m_accountsController addObserver:self forKeyPath:@"selectedObjects" options:0 context:NULL];
	
	[m_accountsTable registerForDraggedTypes:[NSArray arrayWithObject:AccountUUIDsDraggedType]];
	
	
	// Transport Pane
	LPAccount	*account = [self p_selectedAccount];
	NSString	*transportAgent = [[account sapoAgents] hostnameForService:@"msn"];
	
	[self p_updateGUIForTransportAgent:transportAgent ofAccount:account];
	
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self
		   selector:@selector(accountDidChangeTransportInfo:)
			   name:LPAccountDidChangeTransportInfoNotification
			 object:account];
	[nc addObserver:self
		   selector:@selector(applicationWillBecomeActive:)
			   name:NSApplicationWillBecomeActiveNotification
			 object:NSApp];
	
	[m_accountsTable sizeLastColumnToFit];
}


#pragma mark -
#pragma mark NSWindow Delegate Methods


- (void)windowDidBecomeKey:(NSNotification *)aNotification
{
	if (m_needsToUpdateURLHandlerMenu) {
		[self p_updateURLHandlersMenu];
		m_needsToUpdateURLHandlerMenu = NO;
	}
}

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
	[m_accountsController commitEditing];
}


#pragma mark -
#pragma mark Actions - General Prefs


#pragma mark Downloads Folder

- (void)p_updateDownloadsFolderMenu
{
	id			folderItem = [m_downloadsFolderPopUpButton itemAtIndex:0];
	NSString	*folderPath = LPDownloadsFolderPath();
	NSString	*folderDisplayName = [[NSFileManager defaultManager] displayNameAtPath:folderPath];
	NSImage		*folderImage = [[NSWorkspace sharedWorkspace] iconForFile:folderPath];
	
	[folderImage setSize:NSMakeSize(16.0, 16.0)];
	
	[folderItem setTitle:folderDisplayName];
	[folderItem setImage:folderImage];
}

- (IBAction)chooseDownloadsFolder:(id)sender
{
	NSString *downloadsFolder = LPDownloadsFolderPath();
	
	NSOpenPanel	*op = [NSOpenPanel openPanel];
	
	[op setCanChooseFiles:NO];
	[op setCanChooseDirectories:YES];
	[op setCanCreateDirectories:YES];

	[op setResolvesAliases:YES];
	[op setAllowsMultipleSelection:NO];
	[op setPrompt:NSLocalizedString(@"Select", @"")];
	
	[op beginSheetForDirectory:(downloadsFolder ? downloadsFolder : NSHomeDirectory())
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


#pragma mark XMPP/Jabber URL Handler Popup Menu


- (NSString *)defaultURLHandlerBundleID
{
	// Get the current default handler for our URLs
	CFStringRef defaultXMPPHandler = LSCopyDefaultHandlerForURLScheme(CFSTR("xmpp"));
	
	if (defaultXMPPHandler == NULL)
		defaultXMPPHandler = LSCopyDefaultHandlerForURLScheme(CFSTR("jabber"));
	
	return [(NSString *)defaultXMPPHandler autorelease];
}

- (void)setDefaultURLHandlerBundleID:(NSString *)bundleID
{
	LSSetDefaultHandlerForURLScheme(CFSTR("xmpp"), (CFStringRef)bundleID);
	LSSetDefaultHandlerForURLScheme(CFSTR("jabber"), (CFStringRef)bundleID);
	
	// There's a lot of stuff that may need to be done: we may have to remove the previous handler because it
	// may not be returned as an app capable of handling our URLs. Or we may need to add a new handler that was
	// selected using the NSOpenPanel for the "select other" popup menu option.
	// So, just update the whole menu.
	[self p_updateURLHandlersMenu];
}


- (NSSet *)p_allOurURLHandlersBundleIDs
{
	// Get all the available handlers for our URLs from Launch Services
	CFArrayRef allXMPPHandlers = LSCopyAllHandlersForURLScheme(CFSTR("xmpp"));
	CFArrayRef allJabberHandlers = LSCopyAllHandlersForURLScheme(CFSTR("jabber"));
	
	// Mix them all together
	NSMutableSet *allURLHandlers = [NSMutableSet set];
	[allURLHandlers addObjectsFromArray:(NSArray *)allXMPPHandlers];
	[allURLHandlers addObjectsFromArray:(NSArray *)allJabberHandlers];
	
	CFRelease(allXMPPHandlers);
	CFRelease(allJabberHandlers);
	
	return allURLHandlers;
}


- (NSDictionary *)p_infoDictForURLHandlerWithBundleID:(NSString *)bundleID
{
	NSWorkspace		*ws = [NSWorkspace sharedWorkspace];
	NSString		*appAbsolutePath = [ws absolutePathForAppBundleWithIdentifier:bundleID];
	NSDictionary	*itemDescription = nil;
	
	if (appAbsolutePath) {
		NSBundle	*appBundle = [NSBundle bundleWithPath:appAbsolutePath];
		
		NSString	*appName = [appBundle objectForInfoDictionaryKey:(NSString *)kCFBundleNameKey];
		NSString	*appVersion = [appBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
		NSImage		*appIcon = [ws iconForFile:appAbsolutePath];
		
		if ([appName length] > 0) {
			itemDescription = [NSDictionary dictionaryWithObjectsAndKeys:
				bundleID, @"BundleID",
				appName, @"AppName",
				appVersion, @"Version",
				appIcon, @"Icon", nil];
		}
	}
	
	return itemDescription;
}


- (NSArray *)p_contentsOfOurURLHandlersMenu
{
	NSMutableSet *bundleIDsForMenu = [NSMutableSet setWithSet:[self p_allOurURLHandlersBundleIDs]];
	
	// Add the default handler to the set of available handlers, in case it isn't in there already.
	// The user may have chosen an application that isn't registered in the Launch Services database as being
	// capable of handling this URL scheme.
	NSString *defaultHandlerBundleID = [self defaultURLHandlerBundleID];
	if ([defaultHandlerBundleID length] > 0)
		[bundleIDsForMenu addObject:defaultHandlerBundleID];
	
	
	// Build the actual list sorted by the application names
	NSMutableArray *URLHandlersMenuContents = [NSMutableArray array];
	
	NSEnumerator *handlerBundleIDEnum = [bundleIDsForMenu objectEnumerator];
	NSString *bundleID;
	while (bundleID = [handlerBundleIDEnum nextObject]) {
		NSDictionary *infoDict = [self p_infoDictForURLHandlerWithBundleID:bundleID];
		if (infoDict)
			[URLHandlersMenuContents addObject:infoDict];
	}
	
	
	NSSortDescriptor *descriptor = [[NSSortDescriptor alloc] initWithKey:@"AppName" ascending:YES
																selector:@selector(caseInsensitiveCompare:)];
	[URLHandlersMenuContents sortUsingDescriptors:[NSArray arrayWithObject:descriptor]];
	[descriptor release];
	
	return URLHandlersMenuContents;
}


- (void)p_updateURLHandlersMenu
{
	// Cleanup
	[m_defaultURLHandlerPopUpButton removeAllItems];
	[m_defaultURLHandlerPopUpButton setAutoenablesItems:NO];
	
	// Add all the applications known to be able to handle our URLs
	NSEnumerator *handlersEnum = [[self p_contentsOfOurURLHandlersMenu] objectEnumerator];
	NSDictionary *handlerDescription;
	while (handlerDescription = [handlersEnum nextObject]) {
		NSString *menuItemTitle = [NSString stringWithFormat:@"%@ (%@)",
			[handlerDescription objectForKey:@"AppName"],
			[handlerDescription objectForKey:@"Version"]];
		
		[m_defaultURLHandlerPopUpButton addItemWithTitle:menuItemTitle];
		
		NSMenuItem *menuItem = [m_defaultURLHandlerPopUpButton lastItem];
		
		[[handlerDescription objectForKey:@"Icon"] setSize:NSMakeSize(16.0, 16.0)];
		[menuItem setImage:[handlerDescription objectForKey:@"Icon"]];
		[menuItem setRepresentedObject:[handlerDescription objectForKey:@"BundleID"]];
		[menuItem setTarget:self];
		[menuItem setAction:@selector(p_selectedDefaultURLHandler:)];
	}
	
	// Add the "Select Other" item
	[[m_defaultURLHandlerPopUpButton menu] addItem:[NSMenuItem separatorItem]];
	
	[m_defaultURLHandlerPopUpButton addItemWithTitle:NSLocalizedString(@"Select Other App...", @"")];
	NSMenuItem *item = [m_defaultURLHandlerPopUpButton lastItem];
	[item setTarget:self];
	[item setAction:@selector(p_selectOtherURLHandler:)];
	
	// Select the item for the current default handler
	[self p_updateURLHandlersMenuSelection];
}


- (void)p_updateURLHandlersMenuSelection
{
	NSString *defaultHandlerBundleID = [self defaultURLHandlerBundleID];
	int indexToSelect = ( [defaultHandlerBundleID length] > 0 ?
						  [m_defaultURLHandlerPopUpButton indexOfItemWithRepresentedObject:defaultHandlerBundleID] :
						  (-1) );
	
	// If there's no default item or if it isn't in the menu, then add a "none selected" item at the top
	if (indexToSelect < 0) {
		[m_defaultURLHandlerPopUpButton insertItemWithTitle:NSLocalizedString(@"<none selected>", @"") atIndex:0];
		NSMenuItem *item = [m_defaultURLHandlerPopUpButton itemAtIndex:0];
		[item setEnabled:NO];
		
		[[m_defaultURLHandlerPopUpButton menu] insertItem:[NSMenuItem separatorItem] atIndex:1];
		
		indexToSelect = 0;
	}
	[m_defaultURLHandlerPopUpButton selectItemAtIndex: indexToSelect];
}


- (void)p_selectedDefaultURLHandler:(id)sender
{
	// "sender" should be the selected menu item in the popup menu
	[self setDefaultURLHandlerBundleID:[sender representedObject]];
}


- (void)p_selectOtherURLHandler:(id)sender
{
	NSOpenPanel	*op = [NSOpenPanel openPanel];
	
	[op setCanChooseDirectories:NO];
	[op setCanCreateDirectories:NO];
	[op setResolvesAliases:YES];
	[op setAllowsMultipleSelection:NO];
	
	[op setPrompt:NSLocalizedString(@"Select", @"")];
	
	NSArray *applicationsDirPaths = NSSearchPathForDirectoriesInDomains(NSApplicationDirectory, NSSystemDomainMask, NO);
	NSString *applicationsDirPath = ( [applicationsDirPaths count] > 0 ?
									  [applicationsDirPaths objectAtIndex:0] :
									  @"/Applications" );
	
	[op beginSheetForDirectory:applicationsDirPath
						  file:nil
						 types:[NSArray arrayWithObject:@"app"]
				modalForWindow:[self window]
				 modalDelegate:self
				didEndSelector:@selector(p_selectOtherURLHandlerPanelDidEnd:returnCode:contextInfo:)
				   contextInfo:NULL];
}

- (void)p_selectOtherURLHandlerPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSOKButton) {
		NSBundle *appBundle = [NSBundle bundleWithPath:[panel filename]];
		NSString *bundleID = [appBundle bundleIdentifier];
		
		if ([bundleID length] > 0) {
			[self setDefaultURLHandlerBundleID:bundleID];
		}
	}
	
	// Finish by selecting the currently default handler so that the "select other" menu item never gets selected
	[self p_updateURLHandlersMenuSelection];
}


#pragma mark Notifications


- (void)applicationWillBecomeActive:(NSNotification *)notif
{
	// Just in case the list of URL handlers or the default URL handler changed while we were in the background
	m_needsToUpdateURLHandlerMenu = YES;
}


#pragma mark -
#pragma mark Actions - Accounts Prefs


- (LPAccount *)p_selectedAccount
{
	id selectedObjects = [m_accountsController selectedObjects];
	return ([selectedObjects count] > 0 ? [selectedObjects objectAtIndex:0] : nil);
}

- (void)p_startObservingAccounts:(NSArray *)accounts
{
	NSEnumerator *accountEnum = [accounts objectEnumerator];
	LPAccount *account;
	while (account = [accountEnum nextObject]) {
		[account addObserver:self forKeyPath:@"enabled" options:0 context:NULL];
		[account addObserver:self forKeyPath:@"status" options:0 context:NULL];
		[account addObserver:self forKeyPath:@"description" options:0 context:NULL];
		[account addObserver:self forKeyPath:@"automaticReconnectionStatus" options:0 context:NULL];
	}
}

- (void)p_stopObservingAccounts:(NSArray *)accounts
{
	NSEnumerator *accountEnum = [accounts objectEnumerator];
	LPAccount *account;
	while (account = [accountEnum nextObject]) {
		[account removeObserver:self forKeyPath:@"enabled"];
		[account removeObserver:self forKeyPath:@"status"];
		[account removeObserver:self forKeyPath:@"description"];
		[account removeObserver:self forKeyPath:@"automaticReconnectionStatus"];
	}
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:@"accounts"]) {
		NSKeyValueChange changeKind = [[change valueForKey:NSKeyValueChangeKindKey] intValue];
		
		if (changeKind == NSKeyValueChangeInsertion) {
			[self p_startObservingAccounts:[change objectForKey:NSKeyValueChangeNewKey]];
		}
		else if (changeKind == NSKeyValueChangeRemoval) {
			[self p_stopObservingAccounts:[change objectForKey:NSKeyValueChangeOldKey]];
		}
		[m_accountsTable setNeedsDisplay:YES];
	}
	else if ([keyPath isEqualToString:@"selectedObjects"]) {
		[self p_updateGUIForMSNTransportAgentOfAccount:[self p_selectedAccount]];
	}
	else if ([keyPath isEqualToString:@"enabled"] ||
			 [keyPath isEqualToString:@"status"] ||
			 [keyPath isEqualToString:@"description"] ||
			 [keyPath isEqualToString:@"automaticReconnectionStatus"]) {
		[m_accountsTable setNeedsDisplay:YES];
	}
}

- (IBAction)addAccount:(id)sender
{
	[[self accountsController] addNewAccount];
}


- (IBAction)removeAccount:(id)sender
{
	NSArray *selectedAccounts = [m_accountsController selectedObjects];
	NSString *alertTitle = nil;
	NSString *alertInfo = nil;
	
	if ([selectedAccounts count] == 0) {
		NSBeep();
	}
	else {
		if ([selectedAccounts count] > 1) {
			alertTitle = NSLocalizedString(@"Delete the selected accounts?", @"");
			
			alertInfo = [NSString stringWithFormat:
						 NSLocalizedString(@"This will delete the accounts %@. You can't undo this action.", @""),
						 [NSString concatenatedStringWithValuesForKey:@"description" ofObjects:selectedAccounts
													  useDoubleQuotes:YES maxNrListedItems:5]];
		}
		else {
			alertTitle = [NSString stringWithFormat:NSLocalizedString(@"Delete the account \"%@\"?", @""),
						  [[selectedAccounts objectAtIndex:0] description]];
			alertInfo = NSLocalizedString(@"You can't undo this action.", @"");
		}
		
		NSAlert *alert = [[NSAlert alloc] init];
		
		[alert setMessageText:alertTitle];
		[alert setInformativeText:alertInfo];
		[alert addButtonWithTitle:NSLocalizedString(@"Delete", @"")];
		[alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"")];
		
		[alert beginSheetModalForWindow:[self window]
						  modalDelegate:self
						 didEndSelector:@selector(p_removeAccountAlertDidEnd:returnCode:contextInfo:)
							contextInfo:(void *)[selectedAccounts retain]];
	}
}

- (void)p_removeAccountAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	NSArray *selectedAccounts = [(NSArray *)contextInfo autorelease];
	
	if (returnCode == NSAlertFirstButtonReturn) {
		NSEnumerator *accountsEnum = [selectedAccounts objectEnumerator];
		LPAccount *account;
		LPAccountsController *ctrl = [self accountsController];
		
		while (account = [accountsEnum nextObject])
			[ctrl removeAccount:account];
	}
	
	[alert autorelease];
}


#pragma mark Accounts NSTableView Data Source & Delegate


- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return 0;
}


- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	return nil;
}


- (BOOL)tableView:(NSTableView *)aTableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard
{
	if ([rowIndexes count] > 1) {
		return NO;
	}
	else {
		[pboard declareTypes:[NSArray arrayWithObject:AccountUUIDsDraggedType] owner:nil];
		
		NSArray *accounts = [[self accountsController] accounts];
		NSArray *draggedUUIDs = [[accounts objectsAtIndexes:rowIndexes] valueForKey:@"UUID"];
		
		[pboard setPropertyList:draggedUUIDs forType:AccountUUIDsDraggedType];
		
		return YES;
	}
}


- (NSDragOperation)tableView:(NSTableView *)aTableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)operation
{
	NSPasteboard *pboard = [info draggingPasteboard];
	
	if ([[pboard types] containsObject:AccountUUIDsDraggedType]) {
		
		if (operation == NSTableViewDropOn) {
			[aTableView setDropRow:row dropOperation:NSTableViewDropAbove];
		}
		
		return NSDragOperationGeneric;
	}
	else {
		return NSDragOperationNone;
	}
}


- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)operation
{
	BOOL dropWasAccepted = NO;
	
	NSPasteboard *pboard = [info draggingPasteboard];
	
	if ([[pboard types] containsObject:AccountUUIDsDraggedType]) {
		NSArray *draggedUUIDs = [pboard propertyListForType:AccountUUIDsDraggedType];
		
		NSAssert(([draggedUUIDs count] == 1), @"[draggedUUIDs count] != 1");
		
		NSString *draggedAccountUUID = [draggedUUIDs objectAtIndex:0];
		LPAccount *draggedAccount = [[self accountsController] accountForUUID:draggedAccountUUID];
		
		LPAccountsController *accountsController = [self accountsController];
		int draggedAccountCurrentIndex = [[accountsController accounts] indexOfObject:draggedAccount];
		
		int targetIndex = (row > draggedAccountCurrentIndex ? row - 1 : row);
		if (targetIndex != draggedAccountCurrentIndex) {
			// Move it!
			[accountsController moveAccount:draggedAccount toIndex:targetIndex];
			dropWasAccepted = YES;
		}
	}
	
	return dropWasAccepted;
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


- (void)p_updateGUIForMSNTransportAgentOfAccount:(LPAccount *)account
{
	[self p_updateGUIForTransportAgent:[[account sapoAgents] hostnameForService:@"msn"] ofAccount:account];
}


- (void)p_updateGUIForTransportAgent:(NSString *)transportAgent ofAccount:(LPAccount *)account
{
	if (account == [self p_selectedAccount]) {
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
}


#pragma mark Actions - MSN Account Prefs - Public


- (IBAction)registerMSNTransport:(id)sender
{
	LPAccount	*account = [self p_selectedAccount];
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
		LPAccount	*account = [self p_selectedAccount];
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
		LPAccount	*account = [self p_selectedAccount];
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
	LPAccount *account = [self p_selectedAccount];
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
#pragma mark Actions - Advanced Prefs


- (NSArray *)appcastFeeds
{
	return [NSArray arrayWithObjects:
		[NSDictionary dictionaryWithObjectsAndKeys:
			NSLocalizedString(@"Stable Releases", @"auto-update feed selection"),
			@"Label",
			@"http://messenger.sapo.pt/software_update/mac/feeds/sapomsgmac_stable.xml",
			@"AutoupdateURL",
			nil],
		[NSDictionary dictionaryWithObjectsAndKeys:
			NSLocalizedString(@"Beta Releases", @"auto-update feed selection"),
			@"Label",
			@"http://messenger.sapo.pt/software_update/mac/feeds/sapomsgmac_beta.xml",
			@"AutoupdateURL",
			nil],
		[NSDictionary dictionaryWithObjectsAndKeys:
			NSLocalizedString(@"Nightly Builds", @"auto-update feed selection"),
			@"Label",
			@"http://messenger.sapo.pt/software_update/mac/nightly_builds/appcast_feed.xml",
			@"AutoupdateURL",
			nil],
		nil];
}


#pragma mark -
#pragma mark Account Notifications


- (void)accountDidChangeTransportInfo:(NSNotification *)notif
{
	NSString *transportAgent = [[notif userInfo] objectForKey:@"TransportAgent"];
	[self p_updateGUIForTransportAgent:transportAgent ofAccount:[notif object]];
}


@end
