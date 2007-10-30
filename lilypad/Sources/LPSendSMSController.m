//
//  LPSendSMSController.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPSendSMSController.h"
#import "LPColorBackgroundView.h"
#import "LPAccountsController.h"
#import "LPAccount.h"
#import "LPRoster.h"
#import "LPContact.h"
#import "LPContactEntry.h"


@interface LPSendSMSController (PrivatePhoneNrsMenu)
- (NSAttributedString *)p_attributedTitleOfJIDMenuItemForContactEntry:(LPContactEntry *)entry withFont:(NSFont *)font;
- (id <NSMenuItem>)p_popupMenuHeaderItemForAccount:(LPAccount *)account;
- (id <NSMenuItem>)p_popupMenuItemForEntry:(LPContactEntry *)entry;
- (void)p_moveJIDMenuItem:(id <NSMenuItem>)menuItem toIndex:(int)targetIndex inMenu:(NSMenu *)menu;
- (void)p_syncJIDsPopupMenu;
- (void)p_JIDsMenuWillPop:(NSNotification *)notif;
@end


@implementation LPSendSMSController (PrivatePhoneNrsMenu)

- (NSAttributedString *)p_attributedTitleOfJIDMenuItemForContactEntry:(LPContactEntry *)entry withFont:(NSFont *)font
{
	NSString *menuItemTitle = [entry humanReadableAddress];
	NSDictionary *attribs = [NSDictionary dictionaryWithObject:font forKey:NSFontAttributeName];
	
	return ( (menuItemTitle != nil && attribs != nil) ?
			 [[[NSAttributedString alloc] initWithString:menuItemTitle attributes:attribs] autorelease] :
			 nil );
}


- (id <NSMenuItem>)p_popupMenuHeaderItemForAccount:(LPAccount *)account
{
	id item = nil;
	int idx = [m_addressesPopUp indexOfItemWithRepresentedObject:account];
	
	if (idx >= 0) {
		item = [m_addressesPopUp itemAtIndex:idx];
	}
	else {
		item = [[NSMenuItem alloc] initWithTitle:@"" action:NULL keyEquivalent:@""];
		
		[item setTitle:[NSString stringWithFormat:NSLocalizedString(@"Account \"%@\"", @"Chat and SMS window popup menu"), [account description]]];
		[item setIndentationLevel:0];
		[item setEnabled:NO];
		[item setRepresentedObject:account];
		
		[item autorelease];
	}
	
	return item;
}


- (id <NSMenuItem>)p_popupMenuItemForEntry:(LPContactEntry *)entry
{
	id item = nil;
	int idx = [m_addressesPopUp indexOfItemWithRepresentedObject:entry];
	
	if (idx >= 0) {
		item = [m_addressesPopUp itemAtIndex:idx];
	}
	else {
		item = [[NSMenuItem alloc] initWithTitle:@"" action:@selector(selectSMSAddress:) keyEquivalent:@""];
		
		NSAttributedString *attributedTitle = 
			[self p_attributedTitleOfJIDMenuItemForContactEntry:entry withFont:[m_addressesPopUp font]];
		
		[item setAttributedTitle:attributedTitle];
		[item setIndentationLevel:1];
		[item setRepresentedObject:entry];
		[item setTarget:self];
		
		[item autorelease];
	}
	
	return item;
}


- (void)p_moveJIDMenuItem:(id <NSMenuItem>)menuItem toIndex:(int)targetIndex inMenu:(NSMenu *)menu
{
	int currentIndex = [menu indexOfItem:menuItem];
	if (currentIndex != targetIndex) {
		// Prevent it from being dealloced while we possibly take it out of the menu
		[menuItem retain];
		if (currentIndex >= 0)
			[menu removeItemAtIndex:currentIndex];
		[menu insertItem:menuItem atIndex:targetIndex];
		[menuItem release];
	}
}


- (void)p_syncJIDsPopupMenu
{
	id <NSMenuItem> selectedItem = [m_addressesPopUp selectedItem];
	
	NSPredicate		*onlinePred = [NSPredicate predicateWithFormat:@"online == YES"];
	NSPredicate		*offlinePred = [NSPredicate predicateWithFormat:@"online == NO"];
	int				currentIndex = 0;
	
	NSMenu			*menu = [m_addressesPopUp menu];
	NSFont			*menuItemFont = [m_addressesPopUp font];
	
	NSArray			*accounts = [[LPAccountsController sharedAccountsController] accounts];
	unsigned int	nrOfAccounts = [accounts count];
	NSEnumerator	*accountEnumerator = [accounts objectEnumerator];
	LPAccount		*account;
	
	NSArray			*smsContactEntries = [m_contact smsContactEntries];
	
	while (account = [accountEnumerator nextObject]) {
		if ([account isEnabled]) {
			
			// Collect all the JIDs in this account into two lists: online JIDs and offline JIDs
			NSPredicate		*accountPred = [NSPredicate predicateWithFormat:@"account == %@", account];
			NSPredicate		*onlineInThisAccountPred = [NSCompoundPredicate andPredicateWithSubpredicates:
				[NSArray arrayWithObjects:accountPred, onlinePred, nil]];
			NSPredicate		*offlineInThisAccountPred = [NSCompoundPredicate andPredicateWithSubpredicates:
				[NSArray arrayWithObjects:accountPred, offlinePred, nil]];
			
			NSArray		*onlineEntries = [smsContactEntries filteredArrayUsingPredicate: onlineInThisAccountPred];
			NSArray		*offlineEntries = [smsContactEntries filteredArrayUsingPredicate: offlineInThisAccountPred];
			
			if (([onlineEntries count] + [offlineEntries count]) > 0) {
				// ---- Separator Item ----
				if (currentIndex > 0) {
					[[m_addressesPopUp menu] insertItem:[NSMenuItem separatorItem] atIndex:currentIndex];
					++currentIndex;
				}
				
				// Setup an account header in the menu, but only if there's more than one configured account
				if (nrOfAccounts > 1) {
					id <NSMenuItem> menuItem = [self p_popupMenuHeaderItemForAccount:account];
					[self p_moveJIDMenuItem:menuItem toIndex:currentIndex inMenu:menu];
					++currentIndex;
				}				
				
				NSEnumerator	*entryEnum = nil;
				LPContactEntry	*entry = nil;
				
				// Online Contact Entries
				entryEnum = [onlineEntries objectEnumerator];
				while (entry = [entryEnum nextObject]) {
					id <NSMenuItem> menuItem = [self p_popupMenuItemForEntry:entry];
					
					[self p_moveJIDMenuItem:menuItem toIndex:currentIndex inMenu:menu];
					[menuItem setAttributedTitle:[self p_attributedTitleOfJIDMenuItemForContactEntry:entry withFont:menuItemFont]];
					[menuItem setEnabled:YES];
					++currentIndex;
				}
				
				// Offline Contact Entries
				entryEnum = [offlineEntries objectEnumerator];
				while (entry = [entryEnum nextObject]) {
					id <NSMenuItem> menuItem = [self p_popupMenuItemForEntry:entry];
					
					[self p_moveJIDMenuItem:menuItem toIndex:currentIndex inMenu:menu];
					[menuItem setAttributedTitle:[self p_attributedTitleOfJIDMenuItemForContactEntry:entry withFont:menuItemFont]];
					[menuItem setEnabled:NO];
					++currentIndex;
				}
			}
		}
	}
	
	// Remove the remaining items that were left in the menu
	while ([m_addressesPopUp numberOfItems] > currentIndex) {
		[m_addressesPopUp removeItemAtIndex:currentIndex];
	}
	
	// Re-select the saved selection if it's still in the menu
	if (selectedItem != nil && [m_addressesPopUp indexOfItem:selectedItem] >= 0) {
		[m_addressesPopUp selectItem:selectedItem];
	}
	else if ([smsContactEntries count] > 0) {
		[m_addressesPopUp selectItemAtIndex:
			[m_addressesPopUp indexOfItemWithRepresentedObject:
				[smsContactEntries objectAtIndex:0]]];
		[m_selectedEntryController setContent:[smsContactEntries objectAtIndex:0]];
	}
	
	[m_addressesPopUp synchronizeTitleAndSelectedItem];
}

- (void)p_JIDsMenuWillPop:(NSNotification *)notif
{
	[self p_syncJIDsPopupMenu];
}

@end


@implementation LPSendSMSController

- initWithContact:(LPContact *)contact delegate:(id)delegate
{
	if (self = [self initWithWindowNibName:@"SendSMS"]) {
		m_delegate = delegate;
		m_contact = [contact retain];
		
		[m_contact addObserver:self forKeyPath:@"smsContactEntries" options:0 context:NULL];
		[[LPAccountsController sharedAccountsController] addObserver:self forKeyPath:@"online" options:0 context:NULL];
	}
	return self;
}

- (void)dealloc
{
	[[LPAccountsController sharedAccountsController] removeObserver:self forKeyPath:@"online"];
	[m_contact removeObserver:self forKeyPath:@"smsContactEntries"];
	
	[m_selectedEntryController removeObserver:self forKeyPath:@"selection.online"];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[m_contact release];
	[super dealloc];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:@"smsContactEntries"]) {
		// Check if the contact doesn't have any more SMS capable JIDs
		if ([[m_contact smsContactEntries] count] == 0) {
			[self performSelector:@selector(close) withObject:nil afterDelay:0.0];
		}
		
		[self p_syncJIDsPopupMenu];
	}
	else if ([keyPath isEqualToString:@"online"]) {
		// Combined online status of all the accounts
		[m_colorBackgroundView setBackgroundColor:
			[NSColor colorWithPatternImage:( [[LPAccountsController sharedAccountsController] isOnline] ?
											 [NSImage imageNamed:@"chatIDBackground"] :
											 [NSImage imageNamed:@"chatIDBackground_Offline"] )]];
	}
	else if ([keyPath isEqualToString:@"selection.online"]) {
		// Online status of the selected contact entry
		[self p_syncJIDsPopupMenu];
	}
	else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

- (void)windowDidLoad
{
	[m_contactController setContent:[self contact]];
	
	[m_colorBackgroundView setBackgroundColor:
		[NSColor colorWithPatternImage:( [[LPAccountsController sharedAccountsController] isOnline] ?
										 [NSImage imageNamed:@"chatIDBackground"] :
										 [NSImage imageNamed:@"chatIDBackground_Offline"] )]];
	[m_colorBackgroundView setBorderColor:[NSColor colorWithCalibratedWhite:0.60 alpha:1.0]];
	
	
	[m_characterCountField setStringValue:[NSString stringWithFormat: NSLocalizedString(@"%d characters", @"SMS window character count"), 0]];
	
	[self p_syncJIDsPopupMenu];
	[m_addressesPopUp setAutoenablesItems:NO];
	
	// Select one of the phone entries
	NSArray *smsEntries = [m_contact smsContactEntries];
	if ([smsEntries count] > 0) {
		LPContactEntry *entry = [smsEntries objectAtIndex:0];
		[m_selectedEntryController setContent:entry];
		[m_addressesPopUp selectItemAtIndex:[m_addressesPopUp indexOfItemWithRepresentedObject:entry]];
	}
	
	[m_selectedEntryController addObserver:self forKeyPath:@"selection.online" options:0 context:NULL];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(p_JIDsMenuWillPop:)
												 name:NSPopUpButtonWillPopUpNotification
											   object:m_addressesPopUp];
}

- (LPContact *)contact
{
	return [[m_contact retain] autorelease];
}


- (IBAction)selectSMSAddress:(id)sender
{
	LPContactEntry *selectedEntry = [sender representedObject];
	[m_selectedEntryController setContent:selectedEntry];
}


- (IBAction)sendSMS:(id)sender
{
	NSArray *selectedObjs = [m_selectedEntryController selectedObjects];
	
	if ([selectedObjs count] > 0) {
#warning Using LFAppController directly!
		[LFAppController sendSMSToEntry:[[selectedObjs objectAtIndex:0] ID] :[m_messageTextView string]];
		[[self window] close];
	}
}


#pragma mark -
#pragma mark NSText Delegate


- (void)textDidChange:(NSNotification *)aNotification
{
	NSText *text = [aNotification object];
	
	[m_characterCountField setStringValue:[NSString stringWithFormat:
		NSLocalizedString(@"%d characters", @"SMS window character count"),
		[[text string] length]]];
}


#pragma mark -
#pragma mark NSWindow Delegate Methods


- (void)windowWillClose:(NSNotification *)aNotification
{
	if ([m_delegate respondsToSelector:@selector(smsControllerWindowWillClose:)]) {
		[m_delegate smsControllerWindowWillClose:self];
	}
}


@end
