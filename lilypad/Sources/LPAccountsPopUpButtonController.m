//
//  LPAccountsPopUpButtonController.m
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPAccountsPopUpButtonController.h"
#import "LPAccount.h"
#import "LPAccountsController.h"


@interface LPAccountsPopUpButtonController ()  // Private Methods
- (void)p_synchronizeAccountsMenu;
- (void)p_synchronizeMenuSelectionWithSelectedAccount;
- (void)p_synchronizeAccountsMenuNotification:(NSNotification *)notif;
@end


static NSString *LPSynchronizeAccountsMenuNotification = @"LPSyncAccountsMenu";


@implementation LPAccountsPopUpButtonController

- init
{
	if (self = [super init]) {
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(p_synchronizeAccountsMenuNotification:)
													 name:LPSynchronizeAccountsMenuNotification
												   object:self];
		[[LPAccountsController sharedAccountsController] addObserver:self forKeyPath:@"accounts" options:0 context:NULL];
	}
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[[LPAccountsController sharedAccountsController] removeObserver:self forKeyPath:@"accounts"];
	
	/* These setters have to be invoked exactly in this order so that the mechanism that synchronizes the menu contents and selection with the
	 * currently selected account isn't triggered when we set the selected account to nil.
	 */
	[self setPopUpButton:nil];
	[self setSelectedAccount:nil];
	
	[super dealloc];
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:@"enabled"] || [keyPath isEqualToString:@"online"] || [keyPath isEqualToString:@"accounts"]) {
		NSNotificationQueue *queue = [NSNotificationQueue defaultQueue];
		NSNotification *notif = [NSNotification notificationWithName:LPSynchronizeAccountsMenuNotification object:self];
		
		[queue enqueueNotification:notif
					  postingStyle:NSPostWhenIdle
					  coalesceMask:(NSNotificationCoalescingOnName|NSNotificationCoalescingOnSender)
						  forModes:nil];
	}
	else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}


- (NSPopUpButton *)popUpButton
{
	return m_popUpButton;
}

- (void)setPopUpButton:(NSPopUpButton *)button
{
	if (button != m_popUpButton) {
		[[m_popUpButton menu] setDelegate:nil];
		[m_popUpButton setTarget:nil];
		
		[m_popUpButton release];
		m_popUpButton = [button retain];
		
		[m_popUpButton setTarget:self];
		[m_popUpButton setAction:@selector(accountSelectionDidChange:)];
		[[m_popUpButton menu] setDelegate:self];
		
		[m_popUpButton setAutoenablesItems:NO];
		[self p_synchronizeAccountsMenu];
		[self setSelectedAccount:[[LPAccountsController sharedAccountsController] defaultAccount]];
	}
}


- (LPAccount *)selectedAccount
{
	return [[m_selectedAccount retain] autorelease];
}

- (void)setSelectedAccount:(LPAccount *)account
{
	if (account != m_selectedAccount) {
		[m_selectedAccount removeObserver:self forKeyPath:@"enabled"];
		[m_selectedAccount removeObserver:self forKeyPath:@"online"];

		[m_selectedAccount release];
		m_selectedAccount = [account retain];
		
		[m_selectedAccount addObserver:self forKeyPath:@"online" options:0 context:NULL];
		[m_selectedAccount addObserver:self forKeyPath:@"enabled" options:0 context:NULL];
		
		[self p_synchronizeMenuSelectionWithSelectedAccount];
	}
}
	

#pragma mark -
#pragma mark Private


- (void)p_synchronizeAccountsMenu
{
	if (m_popUpButton != nil) {
		[m_popUpButton removeAllItems];
		
		NSEnumerator *accountsEnumerator = [[[LPAccountsController sharedAccountsController] accounts] objectEnumerator];
		LPAccount *account = nil;
		
		while (account = [accountsEnumerator nextObject]) {
			if ([account isEnabled]) {
				NSString *accountDescription = [account description];
				if (accountDescription) {
					[m_popUpButton addItemWithTitle:[account description]];
					
					NSMenuItem *menuItem = [m_popUpButton lastItem];
					[menuItem setRepresentedObject:account];
					
					if (![account isOnline]) {
						[menuItem setEnabled:NO];
						[menuItem setToolTip:NSLocalizedString(@"This account is enabled but is currently offline.",
															   @"JID selection view")];
					}
				}
			}
		}
		
		[self p_synchronizeMenuSelectionWithSelectedAccount];
	}
}


- (void)p_synchronizeMenuSelectionWithSelectedAccount
{
	if (m_popUpButton != nil) {
		LPAccount *accountToSelect = [self selectedAccount];
		NSInteger selectionAccountIndex = [m_popUpButton indexOfItemWithRepresentedObject:accountToSelect];
		
		if (![accountToSelect isEnabled] || ![accountToSelect isOnline] || selectionAccountIndex < 0) {
			accountToSelect = [[LPAccountsController sharedAccountsController] defaultAccount];
			selectionAccountIndex = [m_popUpButton indexOfItemWithRepresentedObject:accountToSelect];
			
			if ((![accountToSelect isEnabled] || ![accountToSelect isOnline] || selectionAccountIndex < 0) && ([m_popUpButton numberOfItems] > 0)) {
				accountToSelect = [[m_popUpButton itemAtIndex:0] representedObject];
				selectionAccountIndex = 0;
			}
			
			[self setSelectedAccount:accountToSelect];
		}
		
		[m_popUpButton selectItemAtIndex:selectionAccountIndex];
	}
}


- (void)p_synchronizeAccountsMenuNotification:(NSNotification *)notif
{
	[self p_synchronizeAccountsMenu];
}


#pragma mark -
#pragma mark NSMenu Delegate


- (void)menuNeedsUpdate:(NSMenu *)menu
{
	[self p_synchronizeAccountsMenu];
}


#pragma mark -
#pragma mark Actions


- (IBAction)accountSelectionDidChange:(id)sender
{
	[self setSelectedAccount:[[sender selectedItem] representedObject]];
}


@end
