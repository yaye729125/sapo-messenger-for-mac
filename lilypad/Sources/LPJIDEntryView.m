//
//  LPJIDEntryView.m
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informa›es sobre o licenciamento, leia o ficheiro README.
//

#import "LPJIDEntryView.h"
#import "LPAccountsController.h"
#import "LPAccount.h"
#import "LPSapoAgents.h"
#import "LPSapoAgents+MenuAdditions.h"


@interface LPJIDEntryView ()  // Private Methods
- (void)p_setAccount:(LPAccount *)account;
- (void)p_synchronizeServicesMenu;
- (void)p_synchronizeJIDTabViewWithSelectedService;
@end


@implementation LPJIDEntryView

- (id)initWithFrame:(NSRect)frameRect;
{
	if (self = [super initWithFrame:frameRect]) {
		if ([NSBundle loadNibNamed:@"JIDEntryView" owner:self]) {
			// Insert the loaded view into our bounds
			[m_assembledControlsView setFrame:[self bounds]];
			[self addSubview:m_assembledControlsView];
			[m_assembledControlsView release];
		}
		else {
			[self release];
			self = nil;
		}
	}
	return self;
}

- (void)dealloc
{
	[m_accountsCtrl removeObserver:self forKeyPath:@"selectedObjects"];
	
	[m_accountsCtrl release];
	[m_account release];
	[m_selectedServiceHostname release];
	[super dealloc];
}

- (void)awakeFromNib
{
	[self p_setAccount:[[self accountsController] defaultAccount]];
	
	[m_accountsCtrl setSelectedObjects:[NSArray arrayWithObject:[self account]]];
	[m_accountsCtrl addObserver:self forKeyPath:@"selectedObjects" options:0 context:NULL];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:@"selectedObjects"]) {
		[self p_setAccount:[[object selectedObjects] objectAtIndex:0]];
	}
	else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

- (id)delegate
{
	return m_delegate;
}

- (void)setDelegate:(id)delegate
{
	m_delegate = delegate;
}

- (LPAccountsController *)accountsController
{
	return [LPAccountsController sharedAccountsController];
}

- (LPAccount *)account
{
	return [[m_account retain] autorelease];
}

- (void)p_setAccount:(LPAccount *)account
{
	if (m_account != account) {
		[self willChangeValueForKey:@"account"];
		[m_account release];
		m_account = [account retain];
		[self didChangeValueForKey:@"account"];
		
		// A change of account implies a change in the sapo agents data. Update the popup menu and
		// the tab view accordingly.
		[self p_synchronizeServicesMenu];
	}
}

- (NSString *)selectedServiceHostname
{
	return [[m_selectedServiceHostname copy] autorelease];
}

- (void)setSelectedServiceHostname:(NSString *)hostname
{
	if (hostname != m_selectedServiceHostname) {
		[m_selectedServiceHostname release];
		m_selectedServiceHostname = [hostname copy];
		
		[m_servicePopUp selectItemAtIndex:[m_servicePopUp indexOfItemWithRepresentedObject:m_selectedServiceHostname]];
		[self p_synchronizeJIDTabViewWithSelectedService];
	}
}

- (void)p_synchronizeServicesMenu
{
	id previouslySelectedRepresentedObject = [[m_servicePopUp selectedItem] representedObject];
	
	LPSapoAgents	*sapoAgents = [[self account] sapoAgents];
	NSMenu			*menu = [sapoAgents JIDServicesMenuForAddingJIDsWithTarget:self
																		action:@selector(serviceSelectionDidChange:)];
	
	if (menu != nil) {
		[m_servicePopUp setMenu:menu];
	} else {
		[m_servicePopUp removeAllItems];
	}
	
	// Restore the selection
	int selectedIndex = [m_servicePopUp indexOfItemWithRepresentedObject:previouslySelectedRepresentedObject];
	if ([m_servicePopUp numberOfItems] > 0)
		[m_servicePopUp selectItemAtIndex:(selectedIndex >= 0 ? selectedIndex : 0)];
	[self setSelectedServiceHostname:[[m_servicePopUp selectedItem] representedObject]];
	
	// The sapo agents configuration may have changed, so we may need to update the tab view accordingly
	[self p_synchronizeJIDTabViewWithSelectedService];
}

- (void)p_synchronizeJIDTabViewWithSelectedService
{
	LPSapoAgents *sapoAgents = [[self account] sapoAgents];
	NSDictionary *sapoAgentsDict = [sapoAgents dictionaryRepresentation];
	NSDictionary *sapoAgentsProps = (([m_selectedServiceHostname length] > 0) ?
									 [sapoAgentsDict objectForKey:m_selectedServiceHostname] :
									 nil);
	
	if (sapoAgentsProps == nil) {
		if (![[[m_JIDTabView selectedTabViewItem] identifier] isEqualToString:@"normal"]) {
			[m_JIDTabView selectTabViewItemWithIdentifier:@"normal"];
			[m_normalJIDTextField setStringValue:@""];
		}
		
		m_jidEntryTextField = m_normalJIDTextField;
	}
	else if ([sapoAgentsProps objectForKey:@"transport"] != nil) {
		if ([[self account] isRegisteredWithTransportAgent:m_selectedServiceHostname]) {
			if (![[[m_JIDTabView selectedTabViewItem] identifier] isEqualToString:@"transport"]) {
				[m_JIDTabView selectTabViewItemWithIdentifier:@"transport"];
				[m_transportJIDTextField setStringValue:@""];
			}
			
			NSString *transportNameString = [NSString stringWithFormat:@"(%@)", [sapoAgentsProps objectForKey:@"name"]];
			
			if (![[m_transportNameTextField stringValue] isEqualToString:transportNameString]) {
				[m_transportNameTextField setStringValue:transportNameString];
				[m_transportJIDTextField setStringValue:@""];
			}
			
			m_jidEntryTextField = m_transportJIDTextField;
		}
		else {
			// Not registered
			[m_JIDTabView selectTabViewItemWithIdentifier:@"transport_not_registered"];
			m_jidEntryTextField = nil;
		}
	}
	else if ([[sapoAgentsProps objectForKey:@"service"] isEqualToString:@"phone"]) {
		if (![[[m_JIDTabView selectedTabViewItem] identifier] isEqualToString:@"phone"]) {
			[m_JIDTabView selectTabViewItemWithIdentifier:@"phone"];
			[m_phoneNrTextField setStringValue:@""];
		}
		
		m_jidEntryTextField = m_phoneNrTextField;
	}
	else {
		if (![[[m_JIDTabView selectedTabViewItem] identifier] isEqualToString:@"sapo"]) {
			[m_JIDTabView selectTabViewItemWithIdentifier:@"sapo"];
			[m_sapoJIDTextField setStringValue:@""];
		}
		
		if (![[m_sapoHostnameTextField stringValue] isEqualToString:m_selectedServiceHostname]) {
			[m_sapoHostnameTextField setStringValue:m_selectedServiceHostname];
			[m_sapoJIDTextField setStringValue:@""];
		}
		
		m_jidEntryTextField = m_sapoJIDTextField;
	}
	
	
	if ([m_delegate respondsToSelector:@selector(JIDEntryViewEntryTextFieldDidChange:)]) {
		[m_delegate JIDEntryViewEntryTextFieldDidChange:self];
	}
	if ([m_delegate respondsToSelector:@selector(JIDEntryViewEnteredJIDDidChange:)]) {
		[m_delegate JIDEntryViewEnteredJIDDidChange:self];
	}
}

- (NSTextField *)JIDEntryTextField
{
	return m_jidEntryTextField;
}

- (NSString *)enteredJID
{
	LPSapoAgents *sapoAgents = [[self account] sapoAgents];
	NSDictionary *sapoAgentsDict = [sapoAgents dictionaryRepresentation];
	NSDictionary *sapoAgentsProps = (([m_selectedServiceHostname length] > 0) ?
									 [sapoAgentsDict objectForKey:m_selectedServiceHostname] :
									 nil);
	
	if (sapoAgentsProps == nil) {
		return [m_normalJIDTextField stringValue];
	}
	else if ([sapoAgentsProps objectForKey:@"transport"] != nil) {
		
		if ([[self account] isRegisteredWithTransportAgent:m_selectedServiceHostname]) {
			NSString *jid = [m_transportJIDTextField stringValue];
			NSArray *jidComponents = [jid componentsSeparatedByString:@"@"];
			
			return ( ([jidComponents count] >= 2) ?
					 [NSString stringWithFormat:@"%@%%%@@%@",
						 [jidComponents objectAtIndex:0], [jidComponents objectAtIndex:1], m_selectedServiceHostname] :
					 [NSString stringWithFormat:@"%@@%@",
						 jid, m_selectedServiceHostname] );
		}
		else {
			return @"";
		}
	}
	else if ([[sapoAgentsProps objectForKey:@"service"] isEqualToString:@"phone"]) {
		return [[m_phoneNrTextField stringValue] internalPhoneJIDRepresentation];
	}
	else {
		return [NSString stringWithFormat:@"%@@%@",
			[m_sapoJIDTextField stringValue],
			[m_sapoHostnameTextField stringValue]];
	}
	
	return nil;
}


#pragma mark -
#pragma mark NSControl Delegate


- (void)controlTextDidChange:(NSNotification *)aNotification
{
	NSTextField *prevEntryField = [self JIDEntryTextField];
	NSString *enteredText = [prevEntryField stringValue];
	
	if ([enteredText rangeOfString:@"@"].location != NSNotFound) {
		NSString *jidUsername = [enteredText JIDUsernameComponent];
		NSString *jidHostname = [enteredText JIDHostnameComponent];
		NSString *updatedEnteredText = enteredText;
		
		NSInteger indexOfEnteredHost = [m_servicePopUp indexOfItemWithRepresentedObject:jidHostname];
		
		if (indexOfEnteredHost >= 0 && [jidHostname length] > 0) {
			[self setSelectedServiceHostname:jidHostname];
			updatedEnteredText = jidUsername;
		} else {
			// "Other Jabber Service"
			[self setSelectedServiceHostname:@""];
		}
		
		// -setSelectedServiceHostname: may have changed the active text entry field
		NSTextField *curEntryField = [self JIDEntryTextField];
		
		if (updatedEnteredText != enteredText || prevEntryField != curEntryField) {
			[curEntryField setStringValue:updatedEnteredText];
		}
		if (prevEntryField != curEntryField) {
			// Move the text caret to the end of the entered text
			[[curEntryField currentEditor] setSelectedRange:NSMakeRange([updatedEnteredText length], 0)];
		}
	}
	
	if ([m_delegate respondsToSelector:@selector(JIDEntryViewEnteredJIDDidChange:)]) {
		[m_delegate JIDEntryViewEnteredJIDDidChange:self];
	}
}


#pragma mark -
#pragma mark Actions


- (IBAction)serviceSelectionDidChange:(id)sender
{
	[self setSelectedServiceHostname:[sender representedObject]];
}


@end

