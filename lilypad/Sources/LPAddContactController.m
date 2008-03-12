//
//  LPAddContactController.m
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPAddContactController.h"
#import "LPJIDEntryView.h"
#import "LPAccount.h"
#import "LPRoster.h"
#import "LPGroup.h"
#import "LPContact.h"
#import "LPContactEntry.h"
#import "LPSapoAgents.h"
#import "LPUIController.h"
#import "LPSapoAgents+MenuAdditions.h"
#import "LPAccountsController.h"


// For the error/warning alerts context
static void *LPAddContactDuplicateJIDAlertContext			= (void *)1;
static void *LPAddContactDuplicateNameAlertContext			= (void *)2;
static void *LPAddContactDuplicateNameAndJIDAlertContext	= (void *)3;


@implementation LPAddContactController

- initWithRoster:(LPRoster *)roster delegate:(id)delegate
{
	NSParameterAssert(roster);
	
	if (self = [super init]) {
		m_roster = [roster retain];
		m_delegate = delegate;
	}
	return self;
}

- (void)dealloc
{
	[m_addContactAddressEntryView removeObserver:self forKeyPath:@"account.online"];
	[m_addJIDAddressEntryView removeObserver:self forKeyPath:@"account.online"];
	
	// Top-level NIB objects
	[m_addContactWindow release];
	[m_addJIDWindow release];
	[m_contactController release];
	
	[m_roster release];
	[m_contact release];
	
	[super dealloc];
}

- (void)p_reevaluateEnabledStateOfButtons
{
	[m_addContactButton setEnabled:( [[[m_addContactAddressEntryView JIDEntryTextField] stringValue] length] > 0	&&
									 [[m_nameComboBox stringValue] length] > 0										&&
									 [[m_addContactAddressEntryView account] isOnline]		)];
	[m_addJIDButton setEnabled:( [[[m_addJIDAddressEntryView JIDEntryTextField] stringValue] length] > 0			&&
								 [[m_addJIDAddressEntryView account] isOnline]			)];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:@"account.online"]) {
		[self p_reevaluateEnabledStateOfButtons];
	}
	else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

- (NSString *)hostOfJIDToBeAdded
{
	LPJIDEntryView *jidEntryView = nil;
	
	if (m_currentlyOpenWindow == m_addContactWindow)
		jidEntryView = m_addContactAddressEntryView;
	else if (m_currentlyOpenWindow == m_addJIDWindow)
		jidEntryView = m_addJIDAddressEntryView;
	
	return [jidEntryView selectedServiceHostname];
}

- (void)setHostOfJIDToBeAdded:(NSString *)hostname
{
	[self addContactWindow]; // force loading the NIB
	
	[m_addContactAddressEntryView setSelectedServiceHostname:hostname];
	[m_addJIDAddressEntryView setSelectedServiceHostname:hostname];
}

- (LPContact *)contact
{
	return [[m_contact retain] autorelease];
}

- (void)setContact:(LPContact *)contact
{
	if (m_contact != contact) {
		[m_contact release];
		m_contact = [contact retain];
		
		[m_contactController setContent:[self contact]];
	}
}

- (void)p_loadNib
{
	// Only load if we don't have any top-level objects in place
	if (m_addContactWindow == nil && m_addJIDWindow == nil) {
		[NSBundle loadNibNamed:@"AddContact" owner:self];
	}
}

- (void)awakeFromNib
{
	[m_contactController setContent:[self contact]];
	
	[m_addContactAddressEntryView addObserver:self forKeyPath:@"account.online" options:0 context:NULL];
	[m_addJIDAddressEntryView addObserver:self forKeyPath:@"account.online" options:0 context:NULL];
}

- (NSWindow *)addContactWindow
{
	if (m_addContactWindow == nil)
		[self p_loadNib];
	
	return m_addContactWindow;
}

- (NSWindow *)addJIDWindow
{
	if (m_addJIDWindow == nil)
		[self p_loadNib];
	
	return m_addJIDWindow;
}

- (void)p_setupJIDTextFieldOfView:(LPJIDEntryView *)view
			  withPreviousKeyView:(NSView *)prevKeyView
					  nextKeyView:(NSView *)nextKeyView
		makeInitialFirstResponder:(BOOL)doMakeInitialFirstResponder
{
	NSTextField *jidTextField = [view JIDEntryTextField];
	
	[prevKeyView setNextKeyView:jidTextField];
	[jidTextField setNextKeyView:nextKeyView];
	
	if (doMakeInitialFirstResponder) {
		[[view window] setInitialFirstResponder:jidTextField];
		[[view window] makeFirstResponder:jidTextField];
	}
}

- (void)runForAddingContactAsSheetForWindow:(NSWindow *)parentWindow
{
	[self addContactWindow]; // force loading the NIB
	m_parentWindow = parentWindow;
	m_currentlyOpenWindow = m_addContactWindow;
	
	[m_nameComboBox setStringValue:@""];
	[m_nameComboBox removeAllItems];
	[m_nameComboBox addItemsWithObjectValues:
		[[m_roster valueForKeyPath:@"allContacts.name"] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)]];
	[m_nameComboBox setCompletes:YES];
	[m_nameComboBox setNumberOfVisibleItems:10];
	
	[m_groupComboBox setStringValue:@""];
	[m_groupComboBox removeAllItems];
	[m_groupComboBox addItemsWithObjectValues:[m_roster valueForKeyPath:@"sortedUserGroups.name"]];
	[m_groupComboBox setCompletes:YES];
	[m_groupComboBox setNumberOfVisibleItems:10];
	
	[self p_setupJIDTextFieldOfView:m_addContactAddressEntryView
				withPreviousKeyView:m_groupComboBox
						nextKeyView:m_addContactReasonTextView
		  makeInitialFirstResponder:NO];
	[[m_addContactAddressEntryView JIDEntryTextField] setStringValue:@""];
	
	[m_addContactReasonTextView setString:@""];
	
	[self p_reevaluateEnabledStateOfButtons];
	[m_currentlyOpenWindow makeFirstResponder:m_nameComboBox];
	
	[NSApp beginSheet:[self addContactWindow]
	   modalForWindow:parentWindow
		modalDelegate:self
	   didEndSelector:@selector(addContactSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:NULL];
}

- (void)runForAddingJIDToContact:(LPContact *)contact asSheetForWindow:(NSWindow *)parentWindow
{
	NSParameterAssert(contact);
	
	[self addJIDWindow]; // force loading the NIB
	m_parentWindow = parentWindow;
	m_currentlyOpenWindow = m_addJIDWindow;
	
	[self setContact:contact];
	
	[self p_setupJIDTextFieldOfView:m_addJIDAddressEntryView
				withPreviousKeyView:m_addJIDReasonTextView
						nextKeyView:m_addJIDReasonTextView
		  makeInitialFirstResponder:YES];
	[[m_addContactAddressEntryView JIDEntryTextField] setStringValue:@""];
	
	[m_addJIDReasonTextView setString:@""];
	
	[self p_reevaluateEnabledStateOfButtons];
	
	[NSApp beginSheet:[self addJIDWindow]
	   modalForWindow:parentWindow
		modalDelegate:self
	   didEndSelector:@selector(addJIDSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:NULL];
}

- (void)addContactSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:nil];
	
	if (returnCode == NSOKButton) {
		// Alert sheet stuff
		NSString *msg = nil;
		NSString *infoMsg = @"";
		NSString *defaultBtn = nil;
		NSString *alternateBtn = NSLocalizedString(@"Go Back", @"button");
		NSString *otherBtn = NSLocalizedString(@"Cancel", @"button");
		void *ctx = NULL;
		BOOL needsToRunAlertSheet = YES;
		
		LPAccount *selectedAccount = [m_addContactAddressEntryView account];
		
		NSString *newJID = [m_addContactAddressEntryView enteredJID];
		NSString *contactName = [m_nameComboBox stringValue];
		NSString *groupName = [m_groupComboBox stringValue];
		
		LPContactEntry *existingContactEntry = [m_roster contactEntryForAddress:newJID
																		account:selectedAccount
													 searchOnlyUserAddedEntries:YES];
		LPContact *existingContact = [m_roster contactForName:contactName];
		
		LPSapoAgents *sapoAgents = [selectedAccount sapoAgents];
		NSDictionary *sapoAgentsDict = [sapoAgents dictionaryRepresentation];
		
		if (existingContact != nil && existingContactEntry != nil) {
			if (existingContact != [existingContactEntry contact]) {
				msg = NSLocalizedString(@"Two existing contacts match the data you entered. Do you want to edit them instead?",
										@"text for the \"add contact\" alerts");
				infoMsg = [NSString stringWithFormat:NSLocalizedString(@"A contact named \"%@\" already exists. Also, the existing contact named "
																	   @"\"%@\" already contains the address \"%@\".",
																	   @"text for the \"add contact\" alerts"),
					[existingContact name],
					[[existingContactEntry contact] name],
					[existingContactEntry humanReadableAddress]];
			}
			else {
				msg = NSLocalizedString(@"There's already a contact that exactly matches the data you have entered. Do you want to edit it instead?",
										@"text for the \"add contact\" alerts");
				infoMsg = [NSString stringWithFormat:NSLocalizedString(@"A contact named \"%@\" containing the address \"%@\" already exists.",
																	   @"text for the \"add contact\" alerts"),
					[existingContact name],
					[existingContactEntry humanReadableAddress]];
			}
			
			defaultBtn = NSLocalizedString(@"Edit", @"button");
			ctx = LPAddContactDuplicateNameAndJIDAlertContext;
		}
		else if (existingContact != nil) {
			msg = [NSString stringWithFormat:NSLocalizedString(@"Do you want to add the address \"%@\" to the contact named \"%@\"?",
															   @"text for the \"add contact\" alerts"),
				[newJID userPresentableJIDAsPerAgentsDictionary:sapoAgentsDict
												serverItemsInfo:[selectedAccount serverItemsInfo]],
				[existingContact name]];
			infoMsg = [NSString stringWithFormat:NSLocalizedString(@"A contact named \"%@\" already exists.",
																   @"text for the \"add contact\" alerts"),
				[existingContact name]];
			
			defaultBtn = NSLocalizedString(@"Add To Existing Contact", @"\"add contact\" alert button");
			ctx = LPAddContactDuplicateNameAlertContext;
		}
		else if (existingContactEntry != nil) {
			msg = [NSString stringWithFormat:NSLocalizedString(@"Create a new contact with the address \"%@\"?",
															   @"text for the \"add contact\" alerts"),
				   [existingContactEntry humanReadableAddress]];
			infoMsg = [NSString stringWithFormat:NSLocalizedString(@"The existing contact named \"%@\" already contains the address \"%@\". If you "
																   @"choose to proceed, a new contact named \"%@\" will be created and the address "
																   @"will be moved into it.",
																   @"text for the \"add contact\" alerts"),
				[[existingContactEntry contact] name],
				[existingContactEntry humanReadableAddress],
				contactName];
			
			defaultBtn = NSLocalizedString(@"Create New Contact", @"\"add contact\" alert button");
			alternateBtn = nil;
			ctx = LPAddContactDuplicateJIDAlertContext;
		}
		else {
			needsToRunAlertSheet = NO;
			
			LPGroup *selectedGroup;
			LPContact *newContact;
			
			selectedGroup = [m_roster groupForName:groupName];
			if (selectedGroup == nil)
				selectedGroup = [m_roster addNewGroupWithName:groupName];
			
			newContact = [selectedGroup addNewContactWithName:contactName];
			
			// Check whether we already have an entry that wasn't registered in the roster by the user
			existingContactEntry = [m_roster contactEntryForAddress:newJID account:selectedAccount];
			
			if (existingContactEntry != nil) {
				[existingContactEntry moveToContact:newContact];
			}
			else {
				[newContact addNewContactEntryWithAddress:newJID
												  account:selectedAccount
												   reason:[m_addContactReasonTextView string]];
			}
		}
		
		// Run the alert sheet if needed
		if (needsToRunAlertSheet) {
			NSAlert *alert = [NSAlert alertWithMessageText:msg
											 defaultButton:defaultBtn
										   alternateButton:alternateBtn
											   otherButton:otherBtn
								 informativeTextWithFormat:@"%@", infoMsg];  // avoid interpreting % chars that may exist in the info message
			[alert beginSheetModalForWindow:m_parentWindow
							  modalDelegate:self
							 didEndSelector:@selector(addContactAlertDidEnd:returnCode:contextInfo:)
								contextInfo:ctx];
		}
	}
}

- (void)addContactAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[[alert window] orderOut:nil];
	
	if (returnCode == NSAlertAlternateReturn) { // Go Back
		[NSApp beginSheet:m_addContactWindow
		   modalForWindow:m_parentWindow
			modalDelegate:self
		   didEndSelector:@selector(addContactSheetDidEnd:returnCode:contextInfo:)
			  contextInfo:NULL];
	}
	else if (returnCode == NSAlertDefaultReturn) {
		LPAccount *selectedAccount = [m_addContactAddressEntryView account];
		
		NSString *newJID = [m_addContactAddressEntryView enteredJID];
		NSString *contactName = [m_nameComboBox stringValue];
		NSString *groupName = [m_groupComboBox stringValue];
		
		if (contextInfo == LPAddContactDuplicateNameAndJIDAlertContext) {
			// Edit
			LPContactEntry *existingEntry = [m_roster contactEntryForAddress:newJID account:selectedAccount];
			LPContact *existingEntrysContact = [existingEntry contact];
			LPContact *existingContact = [m_roster contactForName:contactName];
			
			[[NSApp delegate] showWindowForEditingContact:existingContact];
			if (existingEntrysContact != existingContact)
				[[NSApp delegate] showWindowForEditingContact:existingEntrysContact];
		}
		else if (contextInfo == LPAddContactDuplicateNameAlertContext) {
			// Add new entry to the existing contact having a name equal to the one that was entered
			LPContact *existingContact = [m_roster contactForName:contactName];
			
			// Check whether we already have an entry that wasn't registered in the roster by the user
			LPContactEntry *existingContactEntry = [m_roster contactEntryForAddress:newJID account:selectedAccount];
			
			if (existingContactEntry != nil) {
				[existingContactEntry moveToContact:existingContact];
			}
			else {
				[existingContact addNewContactEntryWithAddress:newJID account:selectedAccount reason:[m_addContactReasonTextView string]];
			}
		}
		else if (contextInfo == LPAddContactDuplicateJIDAlertContext) {
			LPContactEntry *existingEntry = [m_roster contactEntryForAddress:newJID account:selectedAccount];
			
			LPGroup *selectedGroup;
			LPContact *newContact;
			
			selectedGroup = [m_roster groupForName:groupName];
			if (selectedGroup == nil)
				selectedGroup = [m_roster addNewGroupWithName:groupName];
			
			newContact = [selectedGroup addNewContactWithName:contactName];
			[existingEntry moveToContact:newContact];
		}
	}
}

- (void)addJIDSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:nil];
	
	NSString *newJID = [m_addJIDAddressEntryView enteredJID];
	
	if ((returnCode == NSOKButton) && ([newJID length] > 0)) {
		LPAccount *selectedAccount = [m_addJIDAddressEntryView account];
		
		LPContactEntry *existingContactEntry = [[[self contact] roster] contactEntryForAddress:newJID
																					   account:selectedAccount
																	searchOnlyUserAddedEntries:YES];
		
		if (existingContactEntry == nil) {
			// Check whether we already have an entry that wasn't registered in the roster by the user
			existingContactEntry = [m_roster contactEntryForAddress:newJID account:selectedAccount];
			
			if (existingContactEntry != nil) {
				[existingContactEntry moveToContact:[self contact]];
			}
			else {
				[[self contact] addNewContactEntryWithAddress:newJID
													  account:selectedAccount
													   reason:[m_addJIDReasonTextView string]];
			}
		}
		else {
			NSString *msg = [NSString stringWithFormat:
				NSLocalizedString(@"Move the address \"%@\" from contact \"%@\" to contact \"%@\"?",
								  @"roster edit warning"),
				[existingContactEntry humanReadableAddress], 
				[[existingContactEntry contact] name],
				[[self contact] name]];
			NSString *infoFormatStr = NSLocalizedString(@"The existing contact named \"%@\" already contains the address \"%@\". If "
														@"you proceed, the address will be removed from that contact and will be "
														@"added to the contact \"%@\".", @"roster edit warning");
			
			NSAlert *alert = [NSAlert alertWithMessageText:msg
											 defaultButton:NSLocalizedString(@"Move", @"roster edit warning button")
										   alternateButton:nil
											   otherButton:NSLocalizedString(@"Cancel", @"")
								 informativeTextWithFormat:infoFormatStr,
				[[existingContactEntry contact] name],
				[existingContactEntry humanReadableAddress],
				[[self contact] name]];
			
			[alert beginSheetModalForWindow:m_parentWindow
							  modalDelegate:self
							 didEndSelector:@selector(addJIDAlertDidEnd:returnCode:contextInfo:)
								contextInfo:NULL];
		}
	}
}

- (void)addJIDAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[[alert window] orderOut:nil];
	
	NSString *newJID = [m_addJIDAddressEntryView enteredJID];
	LPContactEntry *existingContactEntry = [m_roster contactEntryForAddress:newJID account:[m_addJIDAddressEntryView account]];
	
	if (returnCode == NSAlertAlternateReturn) {
		// Edit contact containing existing entry
		[[NSApp delegate] showWindowForEditingContact:[existingContactEntry contact]];
	}
	else if (returnCode == NSAlertDefaultReturn) {
		// Move the entry from the existing contact into this one
		[existingContactEntry moveToContact:[self contact]];
	}
}


#pragma mark -
#pragma mark NSComboBox Delegate


- (void)controlTextDidChange:(NSNotification *)aNotification
{
	[self p_reevaluateEnabledStateOfButtons];
}

- (void)comboBoxSelectionDidChange:(NSNotification *)notification
{
	// Let the combo-box update the text field string value first
	[self performSelector:@selector(p_reevaluateEnabledStateOfButtons) withObject:nil afterDelay:0.0];
}


#pragma mark -
#pragma mark Actions


- (IBAction)ok:(id)sender
{
	[NSApp endSheet:m_currentlyOpenWindow returnCode:NSOKButton];
}

- (IBAction)cancel:(id)sender
{
	[NSApp endSheet:m_currentlyOpenWindow returnCode:NSCancelButton];
}


#pragma mark -

- (void)JIDEntryViewEnteredJIDDidChange:(LPJIDEntryView *)view
{
	[self p_reevaluateEnabledStateOfButtons];
}

- (void)JIDEntryViewEntryTextFieldDidChange:(LPJIDEntryView *)view
{
	if (view == m_addContactAddressEntryView) {
		[self p_setupJIDTextFieldOfView:view
					withPreviousKeyView:m_groupComboBox
							nextKeyView:m_addContactReasonTextView
			  makeInitialFirstResponder:NO];
	}
}

@end

