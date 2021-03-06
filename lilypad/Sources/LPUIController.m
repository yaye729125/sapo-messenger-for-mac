//
//  LPUIController.m
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Authors: Joao Pavao <jpavao@co.sapo.pt>
//           Jason Kim <jason@512k.org>
//
//	For more information on licensing, read the README file.
//	Para mais informa��es sobre o licenciamento, leia o ficheiro README.
//
//
// The main application controller (on the Objective-C side of the pond).
//
// Although the conceptual "application controller" resides in the core (Qt/C++) half of the
// program, this is Lilypad's equivalent to a typical app controller class.
//

#import "LPUIController.h"
#import "LPRosterController.h"
#import "LPModelessAlert.h"
#import "LPAvatarEditorController.h"
#import "LPChatController.h"
#import "LPPrefsController.h"
#import "LPEditContactController.h"
#import "LPSendSMSController.h"
#import "LPTermsOfUseController.h"
#import "LPFirstRunSetup.h"
#import "LPStatusMenuController.h"
#import "LPFileTransfersController.h"
#import "LPXmlConsoleController.h"
#import "LPSapoAgentsDebugWinCtrl.h"
#import "LPEventNotificationsHandler.h"
#import "CTBadge.h"
#import "LPRecentMessagesStore.h"
#import "NSxString+EmoticonAdditions.h"

#import "LPInternalDataUpgradeManager.h"
#import "LPMessageCenter.h"
#import "LPMessageCenterWinController.h"

#import "LPChatRoomsListController.h"
#import "LPJoinChatRoomWinController.h"
#import "LPGroupChatController.h"

#import "LPAccountsController.h"
#import "LPAccount.h"
#import "LPRoster.h"
#import "LPPresenceSubscription.h"
#import "LPGroup.h"
#import "LPContact.h"
#import "LPContactEntry.h"
#import "LPChatsManager.h"
#import "LPChat.h"
#import "LPGroupChat.h"
#import "LPFileTransfersManager.h"
#import "LPFileTransfer.h"
#import "LPSapoAgents.h"
#import "LPServerItemsInfo.h"
#import "LPXMPPURI.h"

#import "LPCrashReporter.h"
#import "LPReleaseNotesController.h"
#import "LPLogger.h"

#import <Sparkle/SUUpdater.h>


@implementation LPUIController


#pragma mark -
#pragma mark Initialization


+ (void)initialize
{
	if (self == [LPUIController class]) {
		// Register our NSValueTransformers
		[NSValueTransformer setValueTransformer:[[[LPStatusStringFromStatusTransformer alloc] init] autorelease]
										forName:LPStatusStringFromStatusTransformerName];
		[NSValueTransformer setValueTransformer:[[[LPStatusIconFromStatusTransformer alloc] init] autorelease]
										forName:LPStatusIconFromStatusTransformerName];
		[NSValueTransformer setValueTransformer:[[[LPPhoneNrStringFromPhoneJIDTransformer alloc] init] autorelease]
										forName:LPPhoneNrStringFromPhoneJIDTransformerName];
		[NSValueTransformer setValueTransformer:[[[LPAttributedStringWithEmoticonsTransformer alloc] init] autorelease]
										forName:LPAttributedStringWithEmoticonsTransformerName];
		
		// Load our defaults.
		NSString *defaultsPath;
		NSDictionary *defaultsDict;
		
		defaultsPath = [[NSBundle mainBundle] pathForResource:@"Defaults" ofType:@"plist"];
		defaultsDict = [NSDictionary dictionaryWithContentsOfFile:defaultsPath];
		
		[[NSUserDefaults standardUserDefaults] registerDefaults:defaultsDict];
	}
}


- init
{
	if (self = [super init]) {
		// The crash reporter must be initted early on and before anything else so that we can catch any exception
		// that may be thrown during the invocation of this initialization method.
		m_crashReporter = [[LPCrashReporter alloc] initWithDelegate:self];
		
		m_accountsController = [[LPAccountsController sharedAccountsController] retain];
		[m_accountsController addObserver:self
							   forKeyPath:@"accounts"
								  options:( NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld )
								  context:NULL];
		
		m_globalStatusMenuController = [[LPStatusMenuController alloc] initWithControlledAccountStatusObject:m_accountsController];
		
		m_statusMenuControllers = [[NSMutableDictionary alloc] init];
		[m_accountsController setDelegate:self];
		
		m_messageCenter = [[LPMessageCenter alloc] init];
		
		m_authorizationAlertsByJID = [[NSMutableDictionary alloc] init];
		
		m_smsSendingControllers = [[NSMutableArray alloc] init];
		m_chatControllersByContact = [[NSMutableDictionary alloc] init];
		m_editContactControllersByContact = [[NSMutableDictionary alloc] init];
		m_groupChatControllersByAccountAndRoomJID = [[NSMutableDictionary alloc] init];
		
		m_xmlConsoleControllersByAccountUUID = [[NSMutableDictionary alloc] init];
		m_sapoAgentsDebugWinCtrlsByAccountUUID = [[NSMutableDictionary alloc] init];
		
		
		// We need to force the creation of all console controllers for all the existing accounts right away.
		// This will allow them to start to keep track of any recently exchanged XML stanzas from the start.
		// This is a somewhat light operation anyway, as only the controller is actually instatiated. The
		// nib file and the window will only be loaded when the user actually tries to open the console window.
		NSEnumerator	*accountEnum = [[m_accountsController accounts] objectEnumerator];
		LPAccount		*account = nil;
		while (account = [accountEnum nextObject]) {
			[self xmlConsoleForAccount:account];
		}
	}
	return self;
}


- (void)awakeFromNib
{
	[[self globalStatusMenuController] insertControlledStatusItemsIntoMenu:m_statusMenu atIndex:0];
	
	// Forced disable of Spakle automated updates
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"SUCheckAtStartup"];
	
	[m_addContactSupermenu setDelegate:[self rosterController]];
}


- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[[LPRoster roster] setDelegate:nil];
	[[LPChatsManager chatsManager] setDelegate:nil];
	[[LPFileTransfersManager fileTransfersManager] setDelegate:nil];
	
	[[LPFileTransfersManager fileTransfersManager] removeObserver:self
													   forKeyPath:@"numberOfIncomingFileTransfersWaitingToBeAccepted"];
	
	[m_appIconBadge release];
	
	[m_prefsController release];
	[m_rosterController release];
	[m_avatarEditorController release];
	[m_fileTransfersController release];
	
	[m_chatRoomsListController release];
	[m_joinChatRoomController release];
	
	[m_accountsController removeObserver:self forKeyPath:@"accounts"];
	[m_accountsController setDelegate:nil];
	[m_accountsController release];
	[m_globalStatusMenuController release];
	[m_statusMenuControllers release];
	
	[m_messageCenter removeObserver:self forKeyPath:@"countOfPresenceSubscriptionsRequiringAttention"];
	[m_messageCenter removeObserver:self forKeyPath:@"unreadOfflineMessagesCount"];
	[m_messageCenter release];
	[m_messageCenterWinController release];
	
	[m_authorizationAlertsByJID release];
	
	[m_smsSendingControllers release];
	[m_chatControllersByContact release];
	[m_editContactControllersByContact release];
	[m_groupChatControllersByAccountAndRoomJID release];
	[m_xmlConsoleControllersByAccountUUID release];
	[m_sapoAgentsDebugWinCtrlsByAccountUUID release];
	
	[m_provideFeedbackURL release];
	
	[m_crashReporter setDelegate:nil];
	[m_crashReporter release];
	[m_releaseNotes release];
	
	[super dealloc];
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:@"online"]) {
		// Successful first-time auto-login
		LPAccount *account = object;
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		
		if ([account isOnline]) {
			[object removeObserver:self forKeyPath:@"online"];
			
			[self updateDefaultsFromBuild:[defaults stringForKey:@"LastVersionRun"]
						   toCurrentBuild:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]];
			[self enableCheckForUpdates];
			[self performSelector:@selector(checkForNewCrashLogs) withObject:nil afterDelay:10.0];
		}
	}
	else if ([keyPath isEqualToString:@"debugger"]) {
		[[self rosterController] setHasDebuggerBadge:[object isDebugger]];
		
		// Activate the debug menu if this account's JID is marked as a debugger (sapo:debug)
		if ([object isDebugger])
			[self enableDebugMenu];
	}
	else if ([keyPath isEqualToString:@"requiresUserIntervention"]) {
		LPPresenceSubscription	*presSub = object;
		
		if (![presSub requiresUserIntervention]) {
			NSString				*JID = [[presSub contactEntry] address];
			LPModelessAlert	*authAlert = [m_authorizationAlertsByJID objectForKey:JID];
			
			[authAlert close];
		}
	}
	else if ([keyPath isEqualToString:@"unreadOfflineMessagesCount"]) {
		[self updateApplicationDockIconBadges];
		
		LPRosterController *rc = [self rosterController];
		[rc setBadgedUnreadOfflineMessagesCount:[m_messageCenter unreadOfflineMessagesCount]];
		[rc setEventsBadgeMenu:[self pendingEventsMenu]];
	}
	else if ([keyPath isEqualToString:@"countOfPresenceSubscriptionsRequiringAttention"]) {
		[self updateApplicationDockIconBadges];
		
		LPRosterController *rc = [self rosterController];
		[rc setBadgedCountOfPresenceSubscriptionsRequiringAttention:[m_messageCenter countOfPresenceSubscriptionsRequiringAttention]];
		[rc setEventsBadgeMenu:[self pendingEventsMenu]];
	}
	else if ([keyPath isEqualToString:@"numberOfIncomingFileTransfersWaitingToBeAccepted"]) {
		[self updateApplicationDockIconBadges];
		
		LPRosterController *rc = [self rosterController];
		[rc setBadgedPendingFileTransfersCount:[[LPFileTransfersManager fileTransfersManager] numberOfIncomingFileTransfersWaitingToBeAccepted]];
		[rc setEventsBadgeMenu:[self pendingEventsMenu]];
	}
	else if ([keyPath isEqualToString:@"numberOfUnreadMessages"]) {
		// Nr of unread messages changed in some chat window
		int prevCount    = [[change objectForKey:NSKeyValueChangeOldKey] unsignedIntValue];
		int currentCount = [[change objectForKey:NSKeyValueChangeNewKey] unsignedIntValue];
		
		int countDelta = currentCount - prevCount;
		int newTotal = (int)m_totalNrOfUnreadMessages + countDelta;
		
		// Underflows shouldn't happen, but if they do, clamp the total number to 0
		m_totalNrOfUnreadMessages = (newTotal > 0 ? newTotal : 0);
		
		[self updateApplicationDockIconBadges];
	}
	else if ([keyPath isEqualToString:@"contact"]) {
		LPContact *prevContact = [change objectForKey:NSKeyValueChangeOldKey];
		LPContact *newContact  = [change objectForKey:NSKeyValueChangeNewKey];
		
		if (prevContact) {
			[m_chatControllersByContact removeObjectForKey:prevContact];
		}
		if (newContact && ([m_chatControllersByContact objectForKey:newContact] == nil)) {
			[m_chatControllersByContact setObject:object forKey:newContact];
		}
	}
	else if ([keyPath isEqualToString:@"accounts"]) {
		NSKeyValueChange changeKind = [[change objectForKey:NSKeyValueChangeKindKey] intValue];
		
		if (changeKind == NSKeyValueChangeInsertion) {
			// We need to force the creation of all console controllers for all the existing accounts right away.
			// This will allow them to start to keep track of any recently exchanged XML stanzas from the start.
			// This is a somewhat light operation anyway, as only the controller is actually instatiated. The
			// nib file and the window will only be loaded when the user actually tries to open the console window.
			NSArray			*addedAccounts = [change objectForKey:NSKeyValueChangeNewKey];
			NSEnumerator	*accountEnum = [addedAccounts objectEnumerator];
			LPAccount		*account = nil;
			
			while (account = [accountEnum nextObject]) {
				[self xmlConsoleForAccount:account];
			}
		}
		else if (changeKind == NSKeyValueChangeRemoval) {
			NSArray *removedAccountsUUIDs = [[change objectForKey:NSKeyValueChangeOldKey] valueForKey:@"UUID"];
			[m_xmlConsoleControllersByAccountUUID removeObjectsForKeys:removedAccountsUUIDs];
			[m_sapoAgentsDebugWinCtrlsByAccountUUID removeObjectsForKeys:removedAccountsUUIDs];
		}
	}
	else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

- (LPStatusMenuController *)globalStatusMenuController
{
	return [[m_globalStatusMenuController retain] autorelease];
}

- (LPStatusMenuController *)sharedStatusMenuControllerForAccount:(LPAccount *)account
{
	NSString *accountUUID = [account UUID];
	LPStatusMenuController *menuController = [m_statusMenuControllers objectForKey:accountUUID];
	
	if (menuController == nil) {
		menuController = [[LPStatusMenuController alloc] initWithControlledAccountStatusObject:account];
		[m_statusMenuControllers setObject:menuController forKey:accountUUID];
		[menuController release];
	}
	
	return [[menuController retain] autorelease];
}

- (LPAccountsController *)accountsController
{
	return [[m_accountsController retain] autorelease];
}


- (LPRosterController *)rosterController
{
	if (m_rosterController == nil) {
		m_rosterController = [[LPRosterController alloc] initWithRoster:[LPRoster roster] delegate:self];
		[m_rosterController addGroupMenu:m_groupsMenu];
	}
	return m_rosterController;
}


- (LPAvatarEditorController *)avatarEditorController
{
	if (m_avatarEditorController == nil) {
		m_avatarEditorController = [[LPAvatarEditorController alloc] init];
	}
	return m_avatarEditorController;
}


- (LPFileTransfersController *)fileTransfersController
{
	if (m_fileTransfersController == nil) {
		m_fileTransfersController = [[LPFileTransfersController alloc] init];
	}
	return m_fileTransfersController;
}


- (LPMessageCenterWinController *)messageCenterWindowController
{
	if (m_messageCenterWinController == nil) {
		m_messageCenterWinController = [[LPMessageCenterWinController alloc] initWithMessageCenter:m_messageCenter];
		[m_messageCenterWinController setDelegate:self];
	}
	return m_messageCenterWinController;
}


- (LPJoinChatRoomWinController *)joinChatRoomWindowController
{
	if (m_joinChatRoomController == nil) {
		m_joinChatRoomController = [[LPJoinChatRoomWinController alloc] initWithDelegate:self];
	}
	return m_joinChatRoomController;
}


- (LPChatRoomsListController *)chatRoomsListWindowController
{
	if (m_chatRoomsListController == nil) {
		m_chatRoomsListController = [[LPChatRoomsListController alloc] initWithDelegate:self];
		[m_chatRoomsListController setAccount:[[self accountsController] defaultAccount]];
	}
	return m_chatRoomsListController;
}


- (LPXmlConsoleController *)xmlConsoleForAccount:(LPAccount *)account
{
	NSString *accountUUID = [account UUID];
	LPXmlConsoleController *ctrl = [m_xmlConsoleControllersByAccountUUID objectForKey:accountUUID];
	
	if (ctrl == nil) {
		ctrl = [[LPXmlConsoleController alloc] initWithAccount:account];
		[m_xmlConsoleControllersByAccountUUID setObject:ctrl forKey:accountUUID];
		[ctrl release];
	}
	
	return ctrl;
}


- (LPSapoAgentsDebugWinCtrl *)sapoAgentsDebugWindowCtrlForAccount:(LPAccount *)account
{
	NSString *accountUUID = [account UUID];
	LPSapoAgentsDebugWinCtrl *ctrl = [m_sapoAgentsDebugWinCtrlsByAccountUUID objectForKey:accountUUID];
	
	if (ctrl == nil) {
		ctrl = [[LPSapoAgentsDebugWinCtrl alloc] initWithAccount:account];
		[m_sapoAgentsDebugWinCtrlsByAccountUUID setObject:ctrl forKey:accountUUID];
		[ctrl release];
	}
	
	return ctrl;
}


- (void)p_showWindowForChatWithContact:(LPContact *)contact initialContactEntry:(LPContactEntry *)initialEntry
{
	NSAssert((initialEntry == nil || contact == [initialEntry contact]),
			 @"Initial contact entry is not associated with contact!");
	
	LPChatController *chatCtrl = (contact ? [m_chatControllersByContact objectForKey:contact] : nil);
	
	if (chatCtrl == nil && ([contact canDoChat] || contact == nil)) {
		
		chatCtrl = ( initialEntry ?
					 [[LPChatController alloc] initOutgoingWithContactEntry:initialEntry delegate:self] :
					 ( contact ?
					   [[LPChatController alloc] initOutgoingWithContact:contact delegate:self] :
					   [[LPChatController alloc] initWithDelegate:self] ));
		
		if (chatCtrl) {
			[chatCtrl addObserver:self
					   forKeyPath:@"numberOfUnreadMessages"
						  options:( NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew )
						  context:NULL];
			[chatCtrl addObserver:self
					   forKeyPath:@"contact"
						  options:( NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew )
						  context:NULL];
			
			if (contact)
				[m_chatControllersByContact setObject:chatCtrl forKey:contact];
			
			/*
			 * We keep the chat controller instance retained while it's open, even though we may not be keeping
			 * any reference to it. Note in the lines above that we only register the chat controller by contact
			 * when a contact was given at this point. By leaving it retained throughout the life of the window
			 * itself, we are allowing chat windows to exist even without being associated with any chat or contact.
			 * This is usefull for the "New Chat with Person..." command. The release that isn't done in here will
			 * be finally sent to a given chat controller instance in our -[LPUIController chatControllerWindowWillClose:]
			 * method, so everything gets balanced cleanly in the end.
			 */
		}
	}
	else if (chatCtrl != nil && initialEntry != nil) {
		// Just switch the JID on the existing chat window
		[[chatCtrl chat] setActiveContactEntry:initialEntry];
	}
	
	[chatCtrl showWindow:nil];
}

- (void)showWindowForChatWithContact:(LPContact *)contact
{
	// Try to find a chat room entry
	NSEnumerator *entriesEnum = [[contact contactEntries] objectEnumerator];
	LPContactEntry *contactEntry = nil;
	BOOL atLeastOneEntryIsAChatRoom = NO;
	
	while (contactEntry = [entriesEnum nextObject]) {
		if ([contactEntry isChatRoomContactEntry]) {
			atLeastOneEntryIsAChatRoom = YES;
			break;
		}
	}
	
	if (atLeastOneEntryIsAChatRoom) {
		LPGroupChat *groupChat = [[LPChatsManager chatsManager] startGroupChatWithJID:[contactEntry address]
																			 nickname:[[contactEntry account] name]
																			 password:nil requestHistory:YES
																			onAccount:[contactEntry account]];
		if (groupChat) {
			[self showWindowForGroupChat:groupChat];
		}
	}
	else {
		[self p_showWindowForChatWithContact:contact initialContactEntry:nil];
	}
}

- (void)showWindowForChatWithContactEntry:(LPContactEntry *)contactEntry
{
	[self p_showWindowForChatWithContact:[contactEntry contact] initialContactEntry:contactEntry];
}


- (void)showWindowForEditingContact:(LPContact *)contact
{
	LPEditContactController *editContactController = [m_editContactControllersByContact objectForKey:contact];
	
	if (editContactController == nil) {
		editContactController = [[LPEditContactController alloc] initWithContact:contact delegate:self];
		[m_editContactControllersByContact setObject:editContactController forKey:contact];
		[editContactController release];
	}
	
	[editContactController showWindow:nil];
}


- (void)showWindowForSendingSMSWithContacts:(NSArray *)contacts
{
	LPSendSMSController *smsCtrl = [[LPSendSMSController alloc] initWithContacts:contacts delegate:self];
	
	if (smsCtrl) {
		[m_smsSendingControllers addObject:smsCtrl];
		[smsCtrl release];
	}
	
	[smsCtrl showWindow:nil];
}


- (void)showWindowForGroupChat:(LPGroupChat *)groupChat
{
	NSString *accountUUID = [[groupChat account] UUID];
	NSString *roomJID = [groupChat roomJID];
	
	NSMutableDictionary *groupChatCtrlsDict = [m_groupChatControllersByAccountAndRoomJID objectForKey:accountUUID];
	if (groupChatCtrlsDict == nil) {
		groupChatCtrlsDict = [[NSMutableDictionary alloc] init];
		[m_groupChatControllersByAccountAndRoomJID setObject:groupChatCtrlsDict forKey:accountUUID];
		[groupChatCtrlsDict release];
	}
	
	LPGroupChatController *groupChatCtrl = [groupChatCtrlsDict objectForKey:roomJID];
	
	if (groupChatCtrl == nil) {
		groupChatCtrl = [[LPGroupChatController alloc] initWithGroupChat:groupChat delegate:self];
		
		if (groupChatCtrl) {
			//			[groupChatCtrl addObserver:self
			//							forKeyPath:@"numberOfUnreadMessages"
			//							   options:( NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew )
			//							   context:NULL];
			
			[groupChatCtrlsDict setObject:groupChatCtrl forKey:roomJID];
			[groupChatCtrl release];
		}
	}
	
	[groupChatCtrl showWindow:nil];
}


- (void)enableDebugMenu
{
	// Install the Debug menu in the main menu bar if it isn't there already
	if ([m_debugMenu supermenu] == nil) {
		[m_debugMenu setTitle:@"Debug"];
		NSMenuItem *debugMenuItem = [[NSApp mainMenu] addItemWithTitle:@"Debug" action:NULL keyEquivalent:@""];
		[debugMenuItem setSubmenu:m_debugMenu];
	}
}


- (BOOL)enableDebugMenuAndXMLConsoleIfModifiersCombinationIsPressedForAccount:(LPAccount *)account
{
	// Check if the CTRL-OPTION-SHIFT keys are down at this moment
	UInt32 requiredFlags = (optionKey | controlKey | shiftKey);
	UInt32 currentFlags = GetCurrentKeyModifiers();
	
	if ((currentFlags & requiredFlags) == requiredFlags) {
		
		[self enableDebugMenu];
		
		// Open the console
		if (account != nil) {
			LPXmlConsoleController *xmlConsole = [self xmlConsoleForAccount:account];
			[xmlConsole showWindow:nil];
			[xmlConsole setLoggingEnabled:YES];
		}
			
		return YES;
	}
	else {
		return NO;
	}
}


- (void)updateDefaultsFromBuild:(NSString *)fromBuild toCurrentBuild:(NSString *)toBuild
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	BOOL thisIsANewerVersion = ([fromBuild intValue] < [toBuild intValue]);
	if (thisIsANewerVersion)
		[defaults setObject:toBuild forKey:@"LastVersionRun"];
	
	// Upgrade existing defaults to the format used in the current build
	if ([fromBuild intValue] < 556) {
		
		// Update the SUFeedURL default
		NSArray *validAutoupdateURLs = [m_prefsController valueForKeyPath:@"appcastFeeds.AutoupdateURL"];
		
		if (![validAutoupdateURLs containsObject:[defaults objectForKey:@"SUFeedURL"]]) {
			[defaults setObject:[validAutoupdateURLs objectAtIndex:0] forKey:@"SUFeedURL"];
		}
	}
}


- (void)enableCheckForUpdates
{
	[[NSUserDefaults standardUserDefaults] registerDefaults:
		[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:@"SUCheckAtStartup"]];
	
	[m_appUpdater checkForUpdatesInBackground];
}


- (void)checkForNewCrashLogs
{
	if ([m_crashReporter hasNewCrashLogsSinceLastCheck]) {
		LPModelessAlert *alert = [LPModelessAlert modelessAlert];
		
		NSString *infoFmtStr = NSLocalizedString(@"(Please do!)\n\n%1$@ has crashed or was terminated abnormally in the "
												 @"recent past. Your Mac collects some information about these problems "
												 @"when they happen, and the resulting reports are invaluable to the "
												 @"application's development team. They help us chase and fix the bugs "
												 @"that are causing these issues.\n\nYour Mac has stored %2$d reports "
												 @"about crashes of %1$@ that haven't been sent to the development team "
												 @"yet. Sending these reports happens in the background and doesn't "
												 @"require your attention. No private information whatsoever is included."
												 @"\n\nThank you for your cooperation!", @"crash reporter");
		
		[alert setMessageText:NSLocalizedString(@"Report recent crashes?", @"crash reporter")];
		[alert setInformativeText:[NSString stringWithFormat:infoFmtStr,
								   [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleNameKey],
								   [[m_crashReporter newCrashLogsSinceLastCheckPList] count]]];
		[alert setFirstButtonTitle:NSLocalizedString(@"Send Reports", @"crash reporter")];
		[alert setSecondButtonTitle:NSLocalizedString(@"Don't Send", @"crash reporter")];
		
		[alert showWindowWithDelegate:self
					   didEndSelector:@selector(p_checkForNewCrashLogsAlertDidEnd:returnCode:contextInfo:)
						  contextInfo:NULL
							  makeKey:YES];
	}
}

- (void)p_checkForNewCrashLogsAlertDidEnd:(LPModelessAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSAlertFirstButtonReturn) {
		NSString *submissionURLString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"LPCrashReportSubmissionURL"];
		
		[m_crashReporter startPostingNewCrashLogsToHTTPURL:[NSURL URLWithString:submissionURLString]];
		
		// No need to free anything manually in this case, since the crash reporter frees everything that's no longer
		// needed when it finishes sending the reports.
	}
	else {
		[m_crashReporter freeAllNewCrashLogsInternalInfo];
	}
}


- (LPGroupChat *)createNewInstantChatRoomAndShowWindow
{
	LPGroupChat	*groupChat = nil;
	
	// Find an account having at least one MUC service provider and which is currently online
	NSEnumerator *accountsEnumerator = [[[self accountsController] accounts] objectEnumerator];
	LPAccount *account;
	
	while (groupChat == nil && (account = [accountsEnumerator nextObject])) {
		if ([account isOnline]) {
			NSArray *mucServiceHosts = [[account serverItemsInfo] MUCServiceProviderItems];
			
			if ([mucServiceHosts count] > 0) {
				CFUUIDRef     theUUID = CFUUIDCreate(kCFAllocatorDefault);
				CFStringRef   theUUIDString = CFUUIDCreateString(kCFAllocatorDefault, theUUID);
				
				NSString *roomJID = [NSString stringWithFormat:@"%@@%@", (NSString *)theUUIDString, [mucServiceHosts objectAtIndex:0]];
				
				groupChat = [[LPChatsManager chatsManager] startGroupChatWithJID:roomJID nickname:[account name]
																		password:@"" requestHistory:NO
																	   onAccount:account];
				if (groupChat)
					[self showWindowForGroupChat:groupChat];
				
				if (theUUIDString)
					CFRelease(theUUIDString);
				if (theUUID)
					CFRelease(theUUID);
			}
		}
	}
	
	return groupChat;
}


#pragma mark -


- (IBAction)p_activateAndShowRoster:(id)sender
{
	[NSApp activateIgnoringOtherApps:YES];
	[self showRoster:sender];
}

- (IBAction)p_activateAndRevealOfflineMessages:(id)sender
{
	[NSApp activateIgnoringOtherApps:YES];
	
	LPMessageCenterWinController *mc = [self messageCenterWindowController];
	
	[mc showWindow:nil];
	[mc revealOfflineMessages];
}

- (IBAction)p_activateAndRevealPresenceSubscriptions:(id)sender
{
	[NSApp activateIgnoringOtherApps:YES];
	
	LPMessageCenterWinController *mc = [self messageCenterWindowController];
	
	[mc showWindow:nil];
	[mc revealPresenceSubscriptions];
}

- (IBAction)p_activateAndShowFileTransfers:(id)sender
{
	[NSApp activateIgnoringOtherApps:YES];
	[self showFileTransfers:sender];
}


- (NSMenu *)pendingEventsMenu
{
	NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Pending Events"];
	
	int unreadOfflineMessagesCount = [m_messageCenter unreadOfflineMessagesCount];
	int countOfPresenceSubscriptionsRequiringAttention = [m_messageCenter countOfPresenceSubscriptionsRequiringAttention];
	int pendingFileTransfersCount = [[LPFileTransfersManager fileTransfersManager] numberOfIncomingFileTransfersWaitingToBeAccepted];
	
	if (unreadOfflineMessagesCount > 0) {
		[menu addItemWithTitle:[NSString stringWithFormat:NSLocalizedString(@"Show Offline Messages (%d unread)", @"pending events menu"),
								unreadOfflineMessagesCount]
						action:@selector(p_activateAndRevealOfflineMessages:)
				 keyEquivalent:@""];
	}
	
	if (countOfPresenceSubscriptionsRequiringAttention > 0) {
		[menu addItemWithTitle:[NSString stringWithFormat:NSLocalizedString(@"Show Presence Subscriptions (%d requiring your attention)", @"pending events menu"),
								countOfPresenceSubscriptionsRequiringAttention]
						action:@selector(p_activateAndRevealPresenceSubscriptions:)
				 keyEquivalent:@""];
	}
	
	if (pendingFileTransfersCount > 0) {
		[menu addItemWithTitle:[NSString stringWithFormat:NSLocalizedString(@"Show File Transfers (%d waiting to be accepted)",
																			@"pending events menu"),
								pendingFileTransfersCount]
						action:@selector(p_activateAndShowFileTransfers:)
				 keyEquivalent:@""];
	}
	
	
	return [menu autorelease];
}


- (void)updateApplicationDockIconBadges
{
	int unreadOfflineMessagesCount = [m_messageCenter unreadOfflineMessagesCount];
	int countOfPresenceSubscriptionsRequiringAttention = [m_messageCenter countOfPresenceSubscriptionsRequiringAttention];
	int pendingFileTransfersCount = [[LPFileTransfersManager fileTransfersManager] numberOfIncomingFileTransfersWaitingToBeAccepted];
	
	if (m_totalNrOfUnreadMessages == 0 &&
		unreadOfflineMessagesCount == 0 &&
		countOfPresenceSubscriptionsRequiringAttention == 0 &&
		pendingFileTransfersCount == 0)
	{
		[NSApp setApplicationIconImage:[NSImage imageNamed:@"NSApplicationIcon"]];
	}
	else {
		if (m_appIconBadge == nil) {
			m_appIconBadge = [[CTBadge alloc] init];
		}
		
		NSImage *finalImage = [[[NSImage imageNamed:@"NSApplicationIcon"] copy] autorelease];
		NSSize finalSize = [finalImage size];
		
		[finalImage lockFocus];
		{
			if (m_totalNrOfUnreadMessages > 0) {
				[m_appIconBadge setBadgeColor:[NSColor redColor]];
				NSImage *unreadMsgsBadge = [m_appIconBadge badgeOverlayImageForValue:m_totalNrOfUnreadMessages insetX:0.0 y:0.0];
				
				[unreadMsgsBadge compositeToPoint:NSZeroPoint operation:NSCompositeSourceOver];
			}
			
			if (unreadOfflineMessagesCount > 0) {
				[m_appIconBadge setBadgeColor:[NSColor colorWithCalibratedHue:0.0833 saturation:0.65 brightness:0.80 alpha:1.0]];
				NSImage *unreadOfflineMsgsBadge = [m_appIconBadge badgeOverlayImageForValue:unreadOfflineMessagesCount
																					 insetX:0.0
																						  y:(finalSize.height - CTLargeBadgeSize)];
				
				[unreadOfflineMsgsBadge compositeToPoint:NSZeroPoint operation:NSCompositeSourceOver];
			}
			
			if (countOfPresenceSubscriptionsRequiringAttention > 0) {
				[m_appIconBadge setBadgeColor:[NSColor colorWithCalibratedHue:0.1889 saturation:0.65 brightness:0.80 alpha:1.0]];
				NSImage *presenceSubscriptionsBadge = [m_appIconBadge badgeOverlayImageForValue:countOfPresenceSubscriptionsRequiringAttention
																						 insetX:(finalSize.width - CTLargeBadgeSize)
																							  y:(finalSize.height - CTLargeBadgeSize)];
				
				[presenceSubscriptionsBadge compositeToPoint:NSZeroPoint operation:NSCompositeSourceOver];
			}
			
			if (pendingFileTransfersCount > 0) {
				[m_appIconBadge setBadgeColor:[NSColor colorWithCalibratedRed:0.2 green:0.2 blue:1.0 alpha:1.0]];
				NSImage *pendingDownloads = [m_appIconBadge badgeOverlayImageForValue:pendingFileTransfersCount
																			   insetX:(finalSize.width - CTLargeBadgeSize)
																					y:0.0];
				
				[pendingDownloads compositeToPoint:NSZeroPoint operation:NSCompositeSourceOver];
			}
		}
		[finalImage unlockFocus];
		
		[NSApp setApplicationIconImage:finalImage];
	}
}


#pragma mark -


- (void)p_closeAllSheets
{
	NSEnumerator *windowEnum = [[NSApp windows] objectEnumerator];
	NSWindow *window = nil;
	while (window = [windowEnum nextObject]) {
		NSWindow *sheet = [window attachedSheet];
		if (sheet != nil) {
			[NSApp endSheet:sheet];
		}
	}
}

- (void)p_terminateApplicationNow
{
	[self p_closeAllSheets];
	// Clear the delegate so that we don't have to be asking for permission to quit the app.
	// To terminate now means exactly that: NOW! :)
	[NSApp setDelegate:nil];
	[NSApp terminate:nil];
}

- (void)p_relaunchApplicationNow
{
	// The following app restart code was copied from the Sparkle framework:
	// Thanks to Allan Odgaard for this restart code, which is much more clever than mine was.
	setenv("LAUNCH_PATH", [[[NSBundle mainBundle] bundlePath] UTF8String], 1);
	system("/bin/bash -c '{ for (( i = 0; i < 3000 && $(echo $(/bin/ps -xp $PPID|/usr/bin/wc -l))-1; i++ )); do\n"
		   "    /bin/sleep .2;\n"
		   "  done\n"
		   "  if [[ $(/bin/ps -xp $PPID|/usr/bin/wc -l) -ne 2 ]]; then\n"
		   "    /usr/bin/open \"${LAUNCH_PATH}\"\n"
		   "  fi\n"
		   "} &>/dev/null &'");
	
	[self p_terminateApplicationNow];
}


#pragma mark -
#pragma mark Actions


- (IBAction)toggleDisplayEmoticonImages:(id)sender
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	[defaults setBool:(![defaults boolForKey:@"DisplayEmoticonImages"])
			   forKey:@"DisplayEmoticonImages"];
}

- (IBAction)setStatusMessage:(id)sender
{
	[[self rosterController] setStatusMessage];
}

- (IBAction)showRoster:(id)sender
{
	[[self rosterController] showWindow:sender];
}


- (IBAction)showAvatarEditor:(id)sender
{
	[[self avatarEditorController] showWindow:sender];
}


- (IBAction)showFileTransfers:(id)sender
{
	[[self fileTransfersController] showWindow:nil];
}


- (IBAction)showMessageCenter:(id)sender
{
	[[self messageCenterWindowController] showWindow:nil];
}


- (IBAction)provideFeedback:(id)sender
{
	if (m_provideFeedbackURL) {
		[[NSWorkspace sharedWorkspace] openURL:m_provideFeedbackURL];
	}
}


- (IBAction)newChatWithPerson:(id)sender
{
	[self showWindowForChatWithContact:nil];
}


- (IBAction)newInstantChatRoom:(id)sender
{
	[self createNewInstantChatRoomAndShowWindow];
}


- (IBAction)showJoinChatRoom:(id)sender
{
	[[self joinChatRoomWindowController] showWindow:nil];
}


- (IBAction)openSAPOMessengerWebsite:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://messenger.sapo.pt/"]];
}

- (IBAction)openSAPOMessengerDevelopmentWebsite:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://trac.softwarelivre.sapo.pt/sapo_msg_mac/"]];
}

- (IBAction)showLicenseText:(id)sender
{
	[[NSWorkspace sharedWorkspace] openFile:[[NSBundle mainBundle] pathForResource:@"Licenses" ofType:@"html"]];
}

- (IBAction)showReleaseNotes:(id)sender
{
	if (m_releaseNotes == nil) {
		m_releaseNotes = [[LPReleaseNotesController alloc] init];
		if (m_releaseNotes != nil) {
			[[NSNotificationCenter defaultCenter] addObserver:self
													 selector:@selector(p_releaseNotesWindowWillClose:)
														 name:NSWindowWillCloseNotification
													   object:[m_releaseNotes window]];
		}
	}
	[m_releaseNotes showWindow:nil];
}

- (void)p_releaseNotesWindowWillClose:(NSNotification *)notification
{
	NSWindow *win = [notification object];
	
	if (win == [m_releaseNotes window]) {
		[[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowWillCloseNotification object:win];
		[m_releaseNotes autorelease];
		m_releaseNotes = nil;
	}
}

- (IBAction)showChatRoomsList:(id)sender
{
	[[self chatRoomsListWindowController] showWindow:nil];
}


- (IBAction)showXmlConsole:(id)sender
{
	LPAccount *account = [sender representedObject];
	[[self xmlConsoleForAccount:account] showWindow:sender];
}

- (IBAction)showSapoAgentsDebugWindow:(id)sender
{
	LPAccount *account = [sender representedObject];
	[[self sapoAgentsDebugWindowCtrlForAccount:account] showWindow:sender];
}


- (IBAction)addAdvancedPrefsPane:(id)sender
{
	[m_prefsController addAdvancedPrefsPane];
}


- (IBAction)toggleExtendedGetInfoWindow:(id)sender
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setBool:![defaults boolForKey:@"ShowExtendedInfo"] forKey:@"ShowExtendedInfo"];
}


- (IBAction)toggleShowNonRosterContacts:(id)sender
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setBool:![defaults boolForKey:@"ShowNonRosterContacts"] forKey:@"ShowNonRosterContacts"];
	
	[[self rosterController] setNeedsToUpdateRoster:YES];
}


- (IBAction)toggleShowHiddenGroups:(id)sender
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setBool:![defaults boolForKey:@"IncludeDebugGroups"] forKey:@"IncludeDebugGroups"];
	
	[[self rosterController] setNeedsToUpdateRoster:YES];
}


- (IBAction)reportBug:(id)sender
{
	NSBundle	*bundle = [NSBundle mainBundle];
	NSString	*urlFormatString = [bundle objectForInfoDictionaryKey:@"LPBugSubmissionURL"];
	id			versionNr = [bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
	NSString	*urlString = [NSString stringWithFormat:urlFormatString, versionNr];
	
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:urlString]];
}


/* The goal of this is to force menu validation to be performed for these selectors in order to update the
corresponding menu item titles and state to default values. We implement the methods but always disable
their menu items. */
- (IBAction)toggleShowOfflineBuddies:(id)sender { }
- (IBAction)toggleShowGroups:(id)sender { }
- (IBAction)sortByAvailability:(id)sender { }
- (IBAction)sortByName:(id)sender { }
- (IBAction)removeContacts:(id)sender { }


- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	SEL action = [menuItem action];
	BOOL enabled = NO;
	
	if (action == @selector(toggleShowOfflineBuddies:) || action == @selector(sortByName:)) {
		[menuItem setState:NSOffState];
	}
	else if (action == @selector(toggleShowGroups:) || action == @selector(sortByAvailability:)) {
		[menuItem setState:NSOnState];
	}
	else if (action == @selector(removeContacts:)) {
		[menuItem setTitle:NSLocalizedString(@"Remove Contact...", @"menu item title")];
	}
	else if (action == @selector(toggleDisplayEmoticonImages:)) {
		[menuItem setState:[[NSUserDefaults standardUserDefaults] boolForKey:@"DisplayEmoticonImages"]];
		enabled = YES;
	}
	else if (action == @selector(setStatusMessage:)) {
		enabled = [[self accountsController] isOnline];
	}
	else if (action == @selector(provideFeedback:)) {
		enabled = (m_provideFeedbackURL != nil);
	}
	else if (action == @selector(toggleExtendedGetInfoWindow:)) {
		[menuItem setState:[[NSUserDefaults standardUserDefaults] boolForKey:@"ShowExtendedInfo"]];
		enabled = YES;
	}
	else if (action == @selector(toggleShowNonRosterContacts:)) {
		[menuItem setState:[[NSUserDefaults standardUserDefaults] boolForKey:@"ShowNonRosterContacts"]];
		enabled = YES;
	}
	else if (action == @selector(toggleShowHiddenGroups:)) {
		[menuItem setState:[[NSUserDefaults standardUserDefaults] boolForKey:@"IncludeDebugGroups"]];
		enabled = YES;
	}
	else {
		enabled = YES;
	}
	
	return enabled;
}


#pragma mark -
#pragma mark NSApplication Delegate Methods


- (void)handleOpenURLRequest:(NSString *)theURLString
{
	LPXMPPURI	*requestURI = [LPXMPPURI URIWithString:theURLString];
	NSString	*targetJID = [requestURI targetJID];
	BOOL		displayURLParsingError = NO;
	
	if (requestURI == nil || [targetJID length] == 0) {
		displayURLParsingError = YES;
	}
	else {
		NSString *action = [requestURI queryAction];
		
		// Sending a message is the default action
		if ([action isEqualToString:@"message"] || [action length] == 0) {
			LPRoster		*roster = [LPRoster roster];
			LPContactEntry	*entry = [roster contactEntryInAnyAccountForAddress:targetJID createNewHiddenWithNameIfNotFound:targetJID];
			
			[self showWindowForChatWithContactEntry:entry];
			
			NSString *messageBody = [[requestURI parametersDictionary] objectForKey:@"body"];
			if ([messageBody length] > 0) {
				LPChatController *chatController = [m_chatControllersByContact objectForKey:[entry contact]];
				[chatController setMessageTextEntryString:messageBody];
			}
		}
		else if ([action isEqualToString:@"subscribe"] || [action isEqualToString:@"roster"]) {
			NSString *suggestedName = [[requestURI parametersDictionary] objectForKey:@"name"];
			NSString *suggestedGroup = [[requestURI parametersDictionary] objectForKey:@"group"];
			
			[self showRoster:nil];
			[[self rosterController] displaySheetForAddingContactWithJID:targetJID
													suggestedContactName:suggestedName
													  suggestedGroupName:suggestedGroup];
		}
		else if ([action isEqualToString:@"join"]) {
			LPJoinChatRoomWinController *joinChatRoomCtrl = [self joinChatRoomWindowController];
			NSString *password = [[requestURI parametersDictionary] objectForKey:@"password"];
			
			[joinChatRoomCtrl setHost:[targetJID JIDHostnameComponent]];
			[joinChatRoomCtrl setRoom:[targetJID JIDUsernameComponent]];
			[joinChatRoomCtrl setPassword:( [password length] > 0 ? password : @"" )];
			
			[joinChatRoomCtrl showWindow:nil];
		}
		else {
			displayURLParsingError = YES;
		}
	}
	
	if (displayURLParsingError) {
		NSRunCriticalAlertPanel(NSLocalizedString(@"Unable to process URL!", @"url parsing error"),
								NSLocalizedString(@"The URL \"%@\" appears to be malformed and can't be processed by %@.", @"url parsing error"),
								NSLocalizedString(@"OK", @"url parsing error"), nil, nil,
								theURLString, [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleNameKey]);
	}
}


- (void)handleGetURLAppleEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent
{
	NSAppleEventDescriptor* urlDescriptor = [event descriptorForKeyword:keyDirectObject];
	[self handleOpenURLRequest:[urlDescriptor stringValue]];
}


#pragma mark -


- (NSMenu *)applicationDockMenu:(NSApplication *)sender
{
	NSMenu *menu = [self pendingEventsMenu];
	
	[menu insertItemWithTitle:NSLocalizedString(@"Show Roster", @"pending events menu")
					   action:@selector(p_activateAndShowRoster:)
				keyEquivalent:@""
					  atIndex:0];
	
	if ([menu numberOfItems] > 1)
		[menu insertItem:[NSMenuItem separatorItem] atIndex:1];
	
	return menu;
}


#pragma mark -


- (void)applicationWillFinishLaunching:(NSNotification *)notification
{
	// We require Tiger or newer.
	if (floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_3) {
		NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleExecutable"];
		NSString *title = NSLocalizedString(@"Unsupported Operating System", @"startup error");
		NSString *msg = NSLocalizedString(@"Sorry, %@ requires Mac OS X 10.4 or newer.", @"startup error");
		
		NSRunCriticalAlertPanel(title, msg, NSLocalizedString(@"OK", @""), nil, nil, appName);
		[self p_terminateApplicationNow];
	}
	else {
		// Get URL Apple Event ('GURL') is part of the internet AE suite not the standard AE suite and
		// it isn't currently supported directly via a application delegate method so we have to register
		// an AE event handler for it.
		[[NSAppleEventManager sharedAppleEventManager] setEventHandler:self
														   andSelector:@selector(handleGetURLAppleEvent:withReplyEvent:)
														 forEventClass:'GURL'
															andEventID:'GURL'];
	}
}


- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	// Warn the user if a debugging log is being written to a file
	if ([defaults boolForKey:@"DebugLoggingToFileEnabled"]) {
		if (NSOKButton == NSRunAlertPanel(@"Allow writing of verbose debug output to a file?",
										  @"Writing of a verbose debug log is currently enabled. All the communications taking place with the server will be logged to a text file at \"%s\". Please confirm whether you want to proceed with this feature enabled.",
										  @"Allow Logging", @"Disable Logging and Restart App", nil,
										  LP_DEBUG_LOGGER_LOG_FILE) == NSOKButton)
		{
			NSLog(@"Logging to file was ALLOWED by the user.");
		}
		else {
			NSLog(@"Logging to file DISABLED by the user! Restarting...");
			[defaults removeObjectForKey:@"DebugLoggingToFileEnabled"];
			[self p_relaunchApplicationNow];
		}
	}
	
	
	[[LPRoster roster] setDelegate:self];
	[[LPChatsManager chatsManager] setDelegate:self];
	[[LPFileTransfersManager fileTransfersManager] setDelegate:self];
	
	[[LPFileTransfersManager fileTransfersManager] addObserver:self
													forKeyPath:@"numberOfIncomingFileTransfersWaitingToBeAccepted"
													   options:0 context:NULL];
	
	// Observe account status changes
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(accountWillChangeStatus:)
												 name:LPAccountWillChangeStatusNotification
											   object:nil];
	
	
	[m_accountsController loadAccountsFromDefaults];
	
	
	// Check if the modifiers for enabling the XML Console and other debugging facilities are currently pressed. If the modifiers aren't
	// down, then check the defaults key that enables the debug menu to see if we should display it anyway.
	BOOL didEnableDebugMenu = [self enableDebugMenuAndXMLConsoleIfModifiersCombinationIsPressedForAccount:nil];
	if (!didEnableDebugMenu && [defaults boolForKey:@"IncludeDebugMenu"])
		[self enableDebugMenu];
	
	
	[LPEventNotificationsHandler registerWithGrowl];
	[[LPEventNotificationsHandler defaultHandler] setDelegate:self];
	
	
	// Upgrade all the internally maintained data to the most recent version
	[[LPInternalDataUpgradeManager upgradeManager] upgradeInternalDataIfNeeded];
	
	
	// Build number dependent stuff
	NSString	*lastHighestVersionRun = [defaults stringForKey:@"LastVersionRun"];
	NSString	*currentVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
	
	// We will only re-enable the display of the Terms of Service window when we have some server-side method of determining when
	// they should be displayed to the user. See <http://trac.softwarelivre.sapo.pt/sapo_msg_mac/ticket/90> for more details.
	/*
	BOOL thisIsANewerVersion = ([lastHighestVersionRun intValue] < [currentVersion intValue]);
	
	if (thisIsANewerVersion) {
		BOOL acceptedTermsOfUse = [[LPTermsOfUseController termsOfUse] runModal];
		if (!acceptedTermsOfUse)
			[NSApp terminate:nil];
	}
	*/
	
	if (lastHighestVersionRun == nil) {
		// This is the very first run of the application
		[[LPFirstRunSetup firstRunSetup] runModal];
		[[[self accountsController] defaultAccount] addObserver:self forKeyPath:@"online" options:0 context:NULL];
	}
	else {
		[self updateDefaultsFromBuild:lastHighestVersionRun toCurrentBuild:currentVersion];
		
		/* Wait a bit before messing around with the auto-update checks.
		 *
		 * Getting the auto-update checks going while the app is still starting up has been causing some issues
		 * related to the initialization of the CFURL cache.
		 * See <http://trac.softwarelivre.sapo.pt/sapo_msg_mac/ticket/153> for more info.
		 */
		[self performSelector:@selector(enableCheckForUpdates) withObject:nil afterDelay:5.0];
		[self performSelector:@selector(checkForNewCrashLogs) withObject:nil afterDelay:10.0];
		
		/* We consider build nrs greater than or equal to 817 to be associated with marketing version numbers in the 1.x range.
		 * So, if this is the first time we're crossing the 817 build nr boundary, we show the release notes window right when
		 * the app is launched. */
		if ([lastHighestVersionRun intValue] < 817) {
			[self performSelector:@selector(showReleaseNotes:) withObject:nil afterDelay:0.0];
		}
	}
	
	
	[self showRoster:nil];
	
	// Display the badges for any unread offline messages we may have saved on another session
	[self updateApplicationDockIconBadges];
	
	LPRosterController *rc = [self rosterController];
	[rc setHasDebuggerBadge:[[self accountsController] isDebugger]];
	[rc setBadgedUnreadOfflineMessagesCount:[m_messageCenter unreadOfflineMessagesCount]];
	[rc setBadgedCountOfPresenceSubscriptionsRequiringAttention:[m_messageCenter countOfPresenceSubscriptionsRequiringAttention]];
	[rc setEventsBadgeMenu:[self pendingEventsMenu]];
	
	[[LPEventNotificationsHandler defaultHandler] notifyReceptionOfOfflineMessagesCount:[m_messageCenter unreadOfflineMessagesCount]];
	
	[m_messageCenter addObserver:self forKeyPath:@"countOfPresenceSubscriptionsRequiringAttention" options:0 context:NULL];
	[m_messageCenter addObserver:self forKeyPath:@"unreadOfflineMessagesCount" options:0 context:NULL];
	
	[[self accountsController] addObserver:self forKeyPath:@"debugger" options:0 context:NULL];
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"AccountAutoLogin"])
		[[self accountsController] connectAllEnabledAccounts:nil];
}


- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag
{
	if (flag == NO) {
		[self showRoster:nil];
	}
	return flag;
}


- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
	[[self accountsController] disconnectAllAccounts:nil];
	[LFAppController systemQuit];
	return NSTerminateLater;
}


- (void)confirmPendingTermination:(id)arg
{
	BOOL shouldTerminate = [(NSNumber *)arg boolValue];
	[NSApp replyToApplicationShouldTerminate: shouldTerminate];
}


#pragma mark -
#pragma mark LPAccount Notifications


- (void)accountWillChangeStatus:(NSNotification *)notif
{
	LPAccount *account = [notif object];
	LPStatus newStatus = [[[notif userInfo] objectForKey:@"NewStatus"] intValue];
	
	if ([account isOffline] && newStatus == LPStatusConnecting) {
		[self enableDebugMenuAndXMLConsoleIfModifiersCombinationIsPressedForAccount:account];
	}
}


#pragma mark -
#pragma mark LPAccountsController Delegate Methods


- (void)accountsController:(LPAccountsController *)accountsController account:(LPAccount *)account didReceiveErrorNamed:(NSString *)errorName errorKind:(int)errorKind errorCode:(int)errorCode
{
	NSAlert *alert;
	
	NSString *alertTitle = NSLocalizedStringFromTable([errorName stringByAppendingString:@"_Title"], @"ConnectionError", @"");
	NSString *alertMsg = NSLocalizedStringFromTable([errorName stringByAppendingString:@"_Msg"], @"ConnectionError", @"");
	NSString *annotatedAlertMsgFormatStr = NSLocalizedString(@"Account \"%@\"\n\n%@\n\n(error code: %d:%d)", @"connection error message");
	
	alert = [NSAlert alertWithMessageText:alertTitle
							defaultButton:NSLocalizedString(@"OK", @"")
						  alternateButton:nil
							  otherButton:nil
				informativeTextWithFormat:annotatedAlertMsgFormatStr, [account description], alertMsg, errorKind, errorCode];
	
	[alert runModal];
	
	// Was this the first-time login?
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	if ([defaults stringForKey:@"LastVersionRun"] == nil) {
		// this is the first run of the application
		[[[self rosterController] window] orderOut:nil];
		[[LPFirstRunSetup firstRunSetup] runModal];
		
		[self showRoster:nil];
		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"AccountAutoLogin"])
			[[self accountsController] connectAllEnabledAccounts:nil];
	}
}


- (void)accountsController:(LPAccountsController *)accountsController account:(LPAccount *)account didReceiveSavedStatus:(LPStatus)status message:(NSString *)statusMessage
{
	if (![accountsController isOffline]) {
		if ([[self globalStatusMenuController] usesCurrentITunesTrackAsStatus]) {
			[accountsController setTargetStatus:status saveToServer:NO];
		} else {
			[accountsController setTargetStatus:status message:statusMessage saveToServer:NO];
		}
	}
}


- (void)accountsController:(LPAccountsController *)accountsController account:(LPAccount *)account didReceiveLiveUpdateURL:(NSString *)URLString
{
	/*** We no longer care about the URLs provided by the server. Auto-updates are completely managed locally. ***/
	
	//	[[NSUserDefaults standardUserDefaults] setObject:URLString forKey:@"SUFeedURL"];
	//	[m_appUpdater checkForUpdatesInBackground];
}


- (void)accountsController:(LPAccountsController *)accountsController account:(LPAccount *)account didReceiveServerVarsDictionary:(NSDictionary *)varsValues
{
	// "Provide Feedback" URL
	NSString *provideFeedbackValue = [varsValues objectForKey:@"url.mac.feedback"];
	
	if ([provideFeedbackValue length] > 0) {
		NSBundle	*bundle = [NSBundle mainBundle];
		id			buildNr = [bundle objectForInfoDictionaryKey:@"CFBundleVersion"];
		
		NSMutableString *urlString = [NSMutableString stringWithString:provideFeedbackValue];
		
		[urlString replaceOccurrencesOfString:@"SVN_BUILD_NUMBER"
								   withString:[buildNr description]
									  options:NSLiteralSearch
										range:NSMakeRange(0, [urlString length])];
		
		[m_provideFeedbackURL release];
		m_provideFeedbackURL = [[NSURL URLWithString:urlString] retain];
	}
	
	// Sapo Notifications Manager URL
	NSString *sapoNotificationsManagerValue = [varsValues objectForKey:@"url.community.notification_manager"];
	
	if ([sapoNotificationsManagerValue length] > 0) {
		NSURL *managerURL = [NSURL URLWithString:sapoNotificationsManagerValue];
		[[self messageCenterWindowController] setSapoNotificationsManagerURL:managerURL];
	}
}


- (void)accountsController:(LPAccountsController *)accountsController account:(LPAccount *)account didReceiveOfflineMessageFromJID:(NSString *)fromJID nick:(NSString *)nick timestamp:(NSString *)timestamp subject:(NSString *)subject plainTextVariant:(NSString *)plainTextVariant XHTMLVariant:(NSString *)xhtmlVariant URLs:(NSArray *)urls
{
	[m_messageCenter addReceivedOfflineMessageFromJID:fromJID account:account nick:nick timestamp:timestamp subject:subject plainTextVariant:plainTextVariant XHTMLVariant:xhtmlVariant URLs:urls];
}


- (void)accountsController:(LPAccountsController *)accountsController account:(LPAccount *)account didReceiveHeadlineNotificationMessageFromChannel:(NSString *)channelName subject:(NSString *)subject body:(NSString *)body itemURL:(NSString *)itemURL flashURL:(NSString *)flashURL iconURL:(NSString *)iconURL
{
	[m_messageCenter addReceivedSapoNotificationFromChannel:channelName subject:subject body:body
													itemURL:itemURL flashURL:flashURL iconURL:iconURL];
}


- (void)accountsController:(LPAccountsController *)accountsController account:(LPAccount *)account didReceiveChatRoomsList:(NSArray *)chatRoomsList forHost:(NSString *)host
{
	[m_chatRoomsListController setChatRoomsList:chatRoomsList forHost:host];
}


- (void)accountsController:(LPAccountsController *)accountsController account:(LPAccount *)account didReceiveInfo:(NSDictionary *)chatRoomInfo forChatRoomWithJID:(NSString *)roomJID
{
	[m_chatRoomsListController setInfo:chatRoomInfo forRoomWithJID:roomJID];
}


- (void)accountsController:(LPAccountsController *)accountsController account:(LPAccount *)account didReceiveInvitationToRoomWithJID:(NSString *)roomJID from:(NSString *)senderJID reason:(NSString *)reason password:(NSString *)password
{
	//NSLog(@"Received INVITATION to %@ from %@ (reason: %@)", roomJID, senderJID, reason);
	
	NSDictionary *sapoAgentsDict = [[account sapoAgents] dictionaryRepresentation];
	
	NSString *senderBareJID = [senderJID bareJIDComponent];
	NSString *userPresentableSenderJID = [senderJID userPresentableJIDAsPerAgentsDictionary:sapoAgentsDict
																			serverItemsInfo:[account serverItemsInfo]];
	
	LPContactEntry *senderContactEntryInRoster = [[LPRoster roster] contactEntryForAddress:senderBareJID
																				   account:account
																searchOnlyUserAddedEntries:YES];
	if (senderContactEntryInRoster == nil)
		senderContactEntryInRoster = [[LPRoster roster] contactEntryInAnyAccountForAddress:senderBareJID
																searchOnlyUserAddedEntries:YES];
	
	NSString *senderContactName = [[senderContactEntryInRoster contact] name];
	
	NSString *senderDesignation = (([senderContactName length] > 0 && ![senderContactName isEqualToString:senderBareJID]) ?
								   [NSString stringWithFormat:@"\"%@\" (%@)", senderContactName, userPresentableSenderJID] :
								   [NSString stringWithFormat:@"\"%@\"", userPresentableSenderJID]);
	
	LPModelessAlert *inviteAlert = [LPModelessAlert modelessAlert];
	
	[inviteAlert setMessageText:
		[NSString stringWithFormat:NSLocalizedString(@"Accept invitation to join the chat room \"%@\"?", @"chat room invitations"),
			[roomJID JIDUsernameComponent]]];
	
	if ([reason length] > 0) {
		[inviteAlert setInformativeText:
			[NSString stringWithFormat:NSLocalizedString(@"You have been invited by %@ to join the chat room \"%@\", hosted on the server \"%@\"."
														 @" The following reason was given: \"%@\".",
														 @"chat room invitations"),
				senderDesignation, [roomJID JIDUsernameComponent], [roomJID JIDHostnameComponent], reason]];
	}
	else {
		[inviteAlert setInformativeText:
			[NSString stringWithFormat:NSLocalizedString(@"You have been invited by %@ to join the chat room \"%@\", hosted on the server \"%@\".",
														 @"chat room invitations"),
				senderDesignation, [roomJID JIDUsernameComponent], [roomJID JIDHostnameComponent]]];
	}
	
	[inviteAlert setFirstButtonTitle:NSLocalizedString(@"Join Chat", @"chat room invitations")];
	[inviteAlert setSecondButtonTitle:NSLocalizedString(@"Ignore", @"chat room invitations")];
	//[inviteAlert setThirdButtonTitle:NSLocalizedString(@"Decline Invitation", @"chat room invitations")];
	
	NSDictionary *invitationDict = [[NSDictionary alloc] initWithObjectsAndKeys:
		account, @"Account",
		roomJID, @"RoomJID",
		senderJID, @"SenderJID",
		reason, @"Reason",
		password, @"Password",
		nil];
	
	[inviteAlert showWindowWithDelegate:self
						 didEndSelector:@selector(invitationAlertDidEnd:returnCode:contextInfo:)
							contextInfo:invitationDict
								makeKey:YES];
}

- (void)invitationAlertDidEnd:(LPModelessAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	NSDictionary	*invitationDict = [(NSDictionary *)contextInfo autorelease];
	LPAccount		*account = [invitationDict objectForKey:@"Account"];
	NSString		*roomJID = [invitationDict objectForKey:@"RoomJID"];
	NSString		*password = [invitationDict objectForKey:@"Password"];
//	NSString		*senderJID = [invitationDict objectForKey:@"SenderJID"];
//	NSString		*reason = [invitationDict objectForKey:@"Reason"];
	
	if (returnCode == NSAlertFirstButtonReturn) {
		// Join
		LPGroupChat *groupChat = [[LPChatsManager chatsManager] startGroupChatWithJID:roomJID nickname:[account name]
																			 password:password requestHistory:YES
																			onAccount:account];
		
		if (groupChat)
			[self showWindowForGroupChat:groupChat];
	}
	else if (returnCode == NSAlertSecondButtonReturn) {
		// Ignore
	}
}


#pragma mark -
#pragma mark LPChatsManager Delegate Methods


- (void)chatsManager:(LPChatsManager *)manager didReceiveIncomingChat:(LPChat *)newChat
{
	NSAssert(([m_chatControllersByContact objectForKey:[newChat contact]] == nil),
			 @"There is already a chat controller for this contact");
	
	LPChatController *chatCtrl = [[LPChatController alloc] initWithIncomingChat:newChat delegate:self];
	
	[chatCtrl addObserver:self
			   forKeyPath:@"numberOfUnreadMessages"
				  options:( NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew )
				  context:NULL];
	[chatCtrl addObserver:self
			   forKeyPath:@"contact"
				  options:( NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew )
				  context:NULL];
				
	[m_chatControllersByContact setObject:chatCtrl forKey:[newChat contact]];
	
	/*
	 * See comments in the -[LPUIController p_showWindowForChatWithContact:initialContactEntry:] method about
	 * why we are not sending the LPChatController instance a release message to balance with the alloc message.
	 */
	
	[chatCtrl showWindow:nil];
}


// We have no use for the outgoing delegate method
//- (void)chatsManager:(LPChatsManager *)manager didStartOutgoingChat:(LPChat *)newChat
//{
//	
//}


#pragma mark -
#pragma mark LPFileTransfersManager Delegate Methods


- (void)p_processNewFileTransfer:(LPFileTransfer *)newFileTransfer
{
	// Chat window
	LPContact			*contact = [[newFileTransfer peerContactEntry] contact];
	LPChatController	*chatController = [m_chatControllersByContact objectForKey:contact];
	
	if (chatController == nil) {
		[self showWindowForChatWithContactEntry:[newFileTransfer peerContactEntry]];
		chatController = [m_chatControllersByContact objectForKey:contact];
	}
	[chatController updateInfoForFileTransfer:newFileTransfer];
	
	// File Transfers window
	LPFileTransfersController *ftController = [self fileTransfersController];
	NSWindow *ftWin = [ftController window];
	NSWindow *keyWin = [NSApp keyWindow];
	
	if (![ftWin isVisible]) {
		if (keyWin) {
			[ftWin orderWindow:NSWindowBelow relativeTo:[keyWin windowNumber]];
		} else {
			[ftWin orderFront:nil];
		}
	}
	
	[[self fileTransfersController] addFileTransfer:newFileTransfer];
}


- (void)fileTransfersManager:(LPFileTransfersManager *)manager didReceiveIncomingFileTransfer:(LPFileTransfer *)newFileTransfer
{
	[self p_processNewFileTransfer:newFileTransfer];
}


- (void)fileTransfersManager:(LPFileTransfersManager *)manager willStartOutgoingFileTransfer:(LPFileTransfer *)newFileTransfer
{
	[self p_processNewFileTransfer:newFileTransfer];
}

	
	
#pragma mark -
#pragma mark LPRoster Delegate Methods


- (void)roster:(LPRoster *)roster didReceivePresenceSubscriptionRequest:(LPPresenceSubscription *)presSub
{
	// Add to message center
	[m_messageCenter addReceivedPresenceSubscription:presSub];
	
	// Show it on its own window/alert
	LPPresenceSubscriptionState	state = [presSub state];
	LPContactEntry				*entry = [presSub contactEntry];
	NSString					*nickname = [presSub nickname];
	NSString					*reason = [presSub reason];
	NSString					*humanReadableJID = [entry humanReadableAddress];
	NSString					*contactReference = ( ([nickname length] > 0 && ![nickname isEqualToString:humanReadableJID]) ?
													  [NSString stringWithFormat:@"\"%@\" (%@)", nickname, humanReadableJID] :
													  [NSString stringWithFormat:@"\"%@\"", humanReadableJID] );
	
	if (state == LPAuthorizationRequested)
	{
		LPModelessAlert *authAlert = [m_authorizationAlertsByJID objectForKey:[entry address]];
		
		if (authAlert) {
			[[authAlert window] makeKeyAndOrderFront:nil];
		}
		else {
			authAlert = [LPModelessAlert modelessAlert];
			
			[authAlert setMessageText:[NSString stringWithFormat:
				NSLocalizedString(@"Authorize %@ to see your online status on account \"%@\"?", @"presence subscription alert"),
				contactReference, [entry account]]];
			
			[authAlert setInformativeText:[NSString stringWithFormat:
				NSLocalizedString(@"The contact %@ has added your address to their contact list and wants to ask "
								  @"for your authorization to see when you are online on account \"%@\".\n\n"
								  @"%@"
								  @"Do you want to allow this person to see your "
								  @"online status?", @"presence subscription alert"),
				contactReference,
				[entry account],
				( [reason length] > 0 ?
				  [NSString stringWithFormat:
					  NSLocalizedString(@"The contact provided the following reason: \"%@\"\n\n", @"presence subscription alert"),
					  reason] :
				  @"" )]];
			
			[authAlert setFirstButtonTitle:NSLocalizedString(@"Authorize", @"presence subscription alert")];
			[authAlert setSecondButtonTitle:NSLocalizedString(@"Don't Authorize", @"presence subscription alert")];
			
			[m_authorizationAlertsByJID setObject:authAlert forKey:[entry address]];
			[presSub addObserver:self forKeyPath:@"requiresUserIntervention" options:0 context:NULL];
			
			[authAlert showWindowWithDelegate:self
							   didEndSelector:@selector(authorizationRequestAlertDidEnd:returnCode:contextInfo:)
								  contextInfo:(void *)[presSub retain]
									  makeKey:NO];
		}
	}
	else if (state == LPAuthorizationLost)
	{
		LPModelessAlert *authAlert = [m_authorizationAlertsByJID objectForKey:[entry address]];
		
		if (authAlert) {
			[[authAlert window] makeKeyAndOrderFront:nil];
		}
		else {
			authAlert = [LPModelessAlert modelessAlert];
			
			[authAlert setMessageText:[NSString stringWithFormat:
				NSLocalizedString(@"Authorization to see the online status of %@ on account \"%@\" was denied!", @"presence subscription alert"),
				contactReference, [entry account]]];
			
			if ([humanReadableJID isEqualToString:[[entry contact] name]]) {
				[authAlert setInformativeText:[NSString stringWithFormat:
					NSLocalizedString(@"Your authorization to see the online status of the address \"%@\" on account \"%@\" has been denied. "
									  @"You may either remove this address from your contact list or try to renew the authorization.", @"presence subscription alert"),
					humanReadableJID, [entry account]]];
			}
			else {
				[authAlert setInformativeText:[NSString stringWithFormat:
					NSLocalizedString(@"The contact \"%@\" has denied your authorization to see the online status of the address \"%@\" on account \"%@\". "
									  @"You may either remove this address from your contact list or try to renew the authorization.", @"presence subscription alert"),
					[[entry contact] name],
					[entry humanReadableAddress],
					[entry account]]];
			}
			[authAlert setFirstButtonTitle:NSLocalizedString(@"Remove Address", @"presence subscription alert")];
			[authAlert setSecondButtonTitle:NSLocalizedString(@"Renew", @"presence subscription alert")];
			
			[m_authorizationAlertsByJID setObject:authAlert forKey:[entry address]];
			[presSub addObserver:self forKeyPath:@"requiresUserIntervention" options:0 context:NULL];
			
			[authAlert showWindowWithDelegate:self
							   didEndSelector:@selector(authorizationLostAlertDidEnd:returnCode:contextInfo:)
								  contextInfo:(void *)[presSub retain]
									  makeKey:NO];
		}
	}
}

- (void)authorizationRequestAlertDidEnd:(LPModelessAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	LPPresenceSubscription *presSub = [(LPPresenceSubscription *)contextInfo autorelease];
	
	[presSub removeObserver:self forKeyPath:@"requiresUserIntervention"];
	[m_authorizationAlertsByJID removeObjectForKey:[[presSub contactEntry] address]];
	
	if (returnCode == NSAlertFirstButtonReturn) {
		[presSub approveRequest];
	}
	else if (returnCode == NSAlertSecondButtonReturn) {
		[presSub rejectRequest];
	}
}

- (void)authorizationLostAlertDidEnd:(LPModelessAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	LPPresenceSubscription *presSub = [(LPPresenceSubscription *)contextInfo autorelease];
	
	[presSub removeObserver:self forKeyPath:@"requiresUserIntervention"];
	[m_authorizationAlertsByJID removeObjectForKey:[[presSub contactEntry] address]];
	
	if (returnCode == NSAlertFirstButtonReturn) {
		[presSub removeContactEntry];
	}
	else if (returnCode == NSAlertSecondButtonReturn) {
		[presSub sendRequest];
	}
}


#pragma mark -
#pragma mark LPRosterController Delegate Methods


- (void)rosterController:(LPRosterController *)rosterCtrl openChatWithContact:(LPContact *)contact
{
	[self showWindowForChatWithContact:contact];
}


- (void)rosterController:(LPRosterController *)rosterCtrl openGroupChatWithContacts:(NSArray *)contacts
{
	LPGroupChat *groupChat = [self createNewInstantChatRoomAndShowWindow];
	
	NSEnumerator *contactsEnum = [contacts objectEnumerator];
	LPContact *contact;
	
	while (contact = [contactsEnum nextObject]) {
		LPContactEntry *entry = [[contact contactEntries] firstOnlineItemInArrayPassingCapabilitiesPredicate:@selector(canDoMUC)];
		if (entry)
			[groupChat inviteJID:[entry address] withReason:@""];
	}
}


- (void)rosterController:(LPRosterController *)rosterCtrl sendSMSToContacts:(NSArray *)contacts
{
	[self showWindowForSendingSMSWithContacts:contacts];
}


- (void)rosterController:(LPRosterController *)rosterCtrl editContacts:(NSArray *)contacts
{
	NSEnumerator *contactEnumerator = [contacts objectEnumerator];
	LPContact *contact;
	
	while (contact = [contactEnumerator nextObject]) {
		[self showWindowForEditingContact:contact];
	}
}


- (void)rosterController:(LPRosterController *)rosterCtrl importAvatarFromPasteboard:(NSPasteboard *)pboard
{
	[[self avatarEditorController] importAvatarFromPasteboard:pboard];
	[self showAvatarEditor:self];
}


- (LPStatusMenuController *)rosterControllerGlobalStatusMenuController:(LPRosterController *)rosterCtrl
{
	return [self globalStatusMenuController];
}


- (LPStatusMenuController *)rosterController:(LPRosterController *)rosterCtrl statusMenuControllerForAccount:(LPAccount *)account
{
	return ( (account == nil) ?
			 [self globalStatusMenuController] :
			 [self sharedStatusMenuControllerForAccount:account] );
}


#pragma mark -
#pragma mark LPEditContactController Delegate Methods


- (void)editContactControllerWindowWillClose:(LPEditContactController *)ctrl
{
	[m_editContactControllersByContact removeObjectForKey:[ctrl contact]];
}


- (void)editContactController:(LPEditContactController *)ctrl editContact:(LPContact *)contact
{
	[self showWindowForEditingContact:contact];
}


#pragma mark -
#pragma mark LPChatController Delegate Methods


- (void)chatController:(LPChatController *)chatCtrl orderChatWithContactEntryToFront:(LPContactEntry *)contactEntry
{
	[self showWindowForChatWithContactEntry:contactEntry];
}


- (void)chatController:(LPChatController *)chatCtrl editContact:(LPContact *)contact
{
	[self showWindowForEditingContact:contact];
}


- (void)chatController:(LPChatController *)chatCtrl sendSMSToContact:(LPContact *)contact
{
	[self showWindowForSendingSMSWithContacts:[NSArray arrayWithObject:contact]];
}


- (void)chatControllerWindowWillClose:(LPChatController *)chatCtrl
{
	[chatCtrl removeObserver:self forKeyPath:@"contact"];
	[chatCtrl removeObserver:self forKeyPath:@"numberOfUnreadMessages"];
	
	LPContact *contact = [chatCtrl contact];
	
	if (contact)
		[m_chatControllersByContact removeObjectForKey:contact];
	
	/*
	 * See comments in the -[LPUIController p_showWindowForChatWithContact:initialContactEntry:] method about
	 * why we are sending the LPChatController instance a release/autorelease message in here.
	 */
	[chatCtrl autorelease];
}


#pragma mark -
#pragma mark LPGroupChatController Delegate Methods


- (void)groupChatControllerWindowWillClose:(LPGroupChatController *)groupChatCtrl
{
//	[chatCtrl removeObserver:self forKeyPath:@"numberOfUnreadMessages"];
	
	LPGroupChat	*groupChat = [groupChatCtrl groupChat];
	NSString	*accountUUID = [[groupChat account] UUID];
	NSString	*roomJID = [groupChat roomJID];
	
	NSMutableDictionary *groupChatCtrlsDict = [m_groupChatControllersByAccountAndRoomJID objectForKey:accountUUID];
	[groupChatCtrlsDict removeObjectForKey:roomJID];
	if ([groupChatCtrlsDict count] == 0) {
		[m_groupChatControllersByAccountAndRoomJID removeObjectForKey:accountUUID];
	}
}


- (void)groupChatController:(LPGroupChatController *)groupChatCtrl openChatWithContactEntry:(LPContactEntry *)contactEntry
{
	[self showWindowForChatWithContactEntry:contactEntry];
}


#pragma mark -
#pragma mark LPJoinChatRoomWinController Delegate Methods


- (void)joinController:(LPJoinChatRoomWinController *)joinCtrl showWindowForChatRoom:(LPGroupChat *)groupChat
{
	[self showWindowForGroupChat:groupChat];
}


#pragma mark -
#pragma mark LPChatRoomsListController Delegate Methods


- (void)chatRoomsListCtrl:(LPChatRoomsListController *)ctrl joinChatRoomWithJID:(NSString *)roomJID
{
	LPAccount *account = [[LPAccountsController sharedAccountsController] defaultAccount];
	LPGroupChat *groupChat = [[LPChatsManager chatsManager] startGroupChatWithJID:roomJID nickname:[account name]
																		 password:@"" requestHistory:YES
																		onAccount:account];
	
	if (groupChat)
		[self showWindowForGroupChat:groupChat];
}


#pragma mark -
#pragma mark LPSendSMSController Delegate Methods


- (void)smsControllerWindowWillClose:(LPSendSMSController *)smsCtrl
{
	[m_smsSendingControllers removeObject:smsCtrl];
}


#pragma mark -
#pragma mark LPEventNotificationsHandler Delegate Methods


- (void)notificationsHandler:(LPEventNotificationsHandler *)handler userDidClickNotificationForContactWithID:(unsigned int)contactID
{
	[NSApp activateIgnoringOtherApps:YES];
	
	LPRoster *roster = [[self rosterController] roster];
	LPContact *contact = [roster contactForID:contactID];
	
	if (contact != nil) {
		LPChatController *existingChatController = [m_chatControllersByContact objectForKey:contact];
		
		if ([contact canDoChat] || existingChatController != nil) {
			[self showWindowForChatWithContact:contact];
		} else if ([contact canDoSMS]) {
			[self showWindowForSendingSMSWithContacts:[NSArray arrayWithObject:contact]];
		}
	}
}


- (void)notificationsHandler:(LPEventNotificationsHandler *)handler userDidClickNotificationForHeadlineMessageWithURI:(NSString *)messageURI
{
	[NSApp activateIgnoringOtherApps:YES];
	
	if (messageURI != nil) {
		LPMessageCenterWinController *mc = [self messageCenterWindowController];
		
		[mc showWindow:nil];
		[mc revealSapoNotificationWithURI:messageURI];
	}
}


- (void)notificationsHandlerUserDidClickNotificationForOfflineMessages:(LPEventNotificationsHandler *)handler
{
	[self p_activateAndRevealOfflineMessages:nil];
}


- (void)notificationsHandlerUserDidClickNotificationForPresenceSubscriptions:(LPEventNotificationsHandler *)handler
{
	[self p_activateAndRevealPresenceSubscriptions:nil];
}


- (void)notificationsHandlerUserDidClickNotificationForFileTransfer:(LPEventNotificationsHandler *)handler
{
	[self p_activateAndShowFileTransfers:nil];
}


#pragma mark -
#pragma mark LPMessageCenterWinController Delegate Methods


- (void)messageCenterWinCtrl:(LPMessageCenterWinController *)mesgCenterCtrl openNewChatWithJID:(NSString *)jid
{
	LPContactEntry	*contactEntry = [[LPRoster roster] contactEntryInAnyAccountForAddress:jid createNewHiddenWithNameIfNotFound:jid];
	[self showWindowForChatWithContactEntry:contactEntry];
}


#pragma mark -
#pragma mark NSMenu Delegate (for dynamically building the "XML Console" menu, with one per account)


- (void)menuNeedsUpdate:(NSMenu *)menu
{
	SEL action = NULL;
	
	if (menu == m_xmlConsolesPerAccountMenu)
		action = @selector(showXmlConsole:);
	else if (menu == m_discoDebugWindowsPerAccountMenu)
		action = @selector(showSapoAgentsDebugWindow:);
	
	// Remove all items first
	int i;
	for (i = [menu numberOfItems]; i > 0; --i)
		[menu removeItemAtIndex:0];
	
	NSArray *allAccounts = [[self accountsController] accounts];
	
	NSEnumerator *accountEnumerator = [allAccounts objectEnumerator];
	LPAccount *account;
	while (account = [accountEnumerator nextObject]) {
		NSMenuItem *menuItem = [menu addItemWithTitle:[NSString stringWithFormat:@"\"%@\" (%@)", [account description], [account JID]]
											   action:action
										keyEquivalent:@""];
		[menuItem setRepresentedObject:account];
	}
}


#pragma mark -
#pragma mark LPCrashReporter Delegate Methods


- (void)crashReporterDidCatchFirstUnhandledException:(LPCrashReporter *)crashReporter
{
	NSBeep();
	
	NSInteger chosenButton;
	chosenButton = NSRunCriticalAlertPanel(NSLocalizedString(@"Oops! We've hit a small bump in the road!",
															 @"unhandled exceptions alert"),
										   NSLocalizedString(@"%1$@ has encountered a serious error and needs to be relaunched "
															 @"(for the more tech savvy, there was an unhandled exception).\n\n"
															 @"Our development team would love to have access to some detailed "
															 @"info about this problem, so that it can be fixed appropriately. "
															 @"That info would consist of the following items:\n\n\t%2$C the "
															 @"current date;\n\t%2$C the application version and build number;"
															 @"\n\t%2$C the architecture of your Mac (PowerPC or Intel);\n\t%2$C "
															 @"the location of the error in the application code.\n\nNo personal "
															 @"info whatsoever would be included.\n\nDo you allow %1$@ to send "
															 @"some info about this error to its developers?\n",
															 @"unhandled exceptions alert"),
										   NSLocalizedString(@"Send Info & Relaunch", @"unhandled exceptions alert"),
										   NSLocalizedString(@"Just Relaunch", @"unhandled exceptions alert"),
										   nil,
										   [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleNameKey],
										   0x2022 /* bullet char */);
	
	// Send the debugging info?
	if (chosenButton == NSAlertDefaultReturn) {
		NSString *submissionURLString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"LPExceptionReportSubmissionURL"];
		
		[crashReporter postAccumulatedExceptionLogsPListToHTTPURL:[NSURL URLWithString:submissionURLString]];
	}
	
	[self p_relaunchApplicationNow];
}


@end
