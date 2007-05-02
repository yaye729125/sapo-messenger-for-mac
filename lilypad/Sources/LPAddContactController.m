//
//  LPAddContactController.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informa›es sobre o licenciamento, leia o ficheiro README.
//

#import "LPAddContactController.h"
#import "LPAccount.h"
#import "LPRoster.h"
#import "LPGroup.h"
#import "LPContact.h"
#import "LPContactEntry.h"
#import "LPSapoAgents.h"
#import "LPUIController.h"


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
		
		[m_roster addObserver:self forKeyPath:@"account.online" options:0 context:NULL];
	}
	return self;
}

- (void)dealloc
{
	[m_roster removeObserver:self forKeyPath:@"account.online"];
	
	// Top-level NIB objects
	[m_addContactWindow release];
	[m_addJIDWindow release];
	[m_JIDTabView release];
	
	[m_roster release];
	[m_contact release];
	[m_sapoAgents release];
	
	[m_hostOfJIDToBeAdded release];
	
	[super dealloc];
}

- (void)p_reevaluateEnabledStateOfButtons
{
	[m_addContactButton setEnabled:( [[m_jidEntryTextField stringValue] length] > 0 &&
									 [[m_nameComboBox stringValue] length] > 0      &&
									 [[m_roster account] isOnline]					)];
	[m_addJIDButton setEnabled:( [[m_jidEntryTextField stringValue] length] > 0 &&
								 [[m_roster account] isOnline]					)];
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

- (LPSapoAgents *)sapoAgents
{
	return [[m_sapoAgents retain] autorelease];
}

- (void)setSapoAgents:(LPSapoAgents *)sapoAgents
{
	if (m_sapoAgents != sapoAgents) {
		[m_sapoAgents release];
		m_sapoAgents = [sapoAgents retain];
	}
}

- (NSString *)hostOfJIDToBeAdded
{
	return [[m_hostOfJIDToBeAdded copy] autorelease];
}

- (void)setHostOfJIDToBeAdded:(NSString *)hostname
{
	if (hostname != m_hostOfJIDToBeAdded) {
		[m_hostOfJIDToBeAdded release];
		m_hostOfJIDToBeAdded = [hostname copy];
	}
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
	}
}

- (void)p_loadNib
{
	// Only load if we don't have any top-level objects in place
	if (m_addContactWindow == nil && m_addJIDWindow == nil && m_JIDTabView == nil) {
		[NSBundle loadNibNamed:@"AddContact" owner:self];
		
		[m_contactController setContent:[self contact]];
		
		// Dump the NSView that is only used as a container for the tab view in the nib file
		NSView *tabViewSuperview = [m_JIDTabView superview];
		[m_JIDTabView retain];
		[m_JIDTabView removeFromSuperviewWithoutNeedingDisplay];
		[tabViewSuperview release];
	}
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

- (void)p_setupJIDTabViewInsidePlaceholderView:(NSView *)placeholderView
							   previousKeyView:(NSView *)prevKeyView
								   nextKeyView:(NSView *)nextKeyView
					 makeInitialFirstResponder:(BOOL)doMakeInitialFirstResponder
{
	// Add the JID view
	if ([m_JIDTabView superview] != placeholderView) {
		[m_JIDTabView setFrame:[placeholderView bounds]];
		[placeholderView addSubview:m_JIDTabView];
	}
	
	// Setup the JID view
	NSDictionary *sapoAgentsDict = [m_sapoAgents dictionaryRepresentation];
	NSDictionary *sapoAgentsProps = (([m_hostOfJIDToBeAdded length] > 0) ?
									 [sapoAgentsDict objectForKey:m_hostOfJIDToBeAdded] :
									 nil);
	if (sapoAgentsProps == nil) {
		[m_JIDTabView selectTabViewItemWithIdentifier:@"normal"];
		[m_normalJIDTextField setStringValue:@""];
		
		m_jidEntryTextField = m_normalJIDTextField;
	}
	else if ([sapoAgentsProps objectForKey:@"transport"] != nil) {
		
		if ([[m_roster account] isRegisteredWithTransportAgent:m_hostOfJIDToBeAdded]) {
			[m_JIDTabView selectTabViewItemWithIdentifier:@"transport"];
			[m_transportJIDTextField setStringValue:@""];
			[m_transportNameTextField setStringValue:[NSString stringWithFormat:@"(%@)", [sapoAgentsProps objectForKey:@"name"]]];
			
			m_jidEntryTextField = m_transportJIDTextField;
		}
		else {
			// Not registered
			[m_JIDTabView selectTabViewItemWithIdentifier:@"transport_not_registered"];
			m_jidEntryTextField = nil;
		}
	}
	else if ([[sapoAgentsProps objectForKey:@"service"] isEqualToString:@"phone"]) {
		[m_JIDTabView selectTabViewItemWithIdentifier:@"phone"];
		[m_phoneNrTextField setStringValue:@""];
		
		m_jidEntryTextField = m_phoneNrTextField;
	}
	else {
		[m_JIDTabView selectTabViewItemWithIdentifier:@"sapo"];
		[m_sapoJIDTextField setStringValue:@""];
		[m_sapoHostnameTextField setStringValue:m_hostOfJIDToBeAdded];
		
		m_jidEntryTextField = m_sapoJIDTextField;
	}
	
	[prevKeyView setNextKeyView:m_jidEntryTextField];
	[m_jidEntryTextField setNextKeyView:nextKeyView];
	
	if (doMakeInitialFirstResponder) {
		[[m_JIDTabView window] setInitialFirstResponder:m_jidEntryTextField];
		[m_currentlyOpenWindow makeFirstResponder:m_jidEntryTextField];
	}
}

- (void)runForAddingContactAsSheetForWindow:(NSWindow *)parentWindow
{
	NSAssert(m_sapoAgents, @"LPAddContactController needs sapo agents info to run!");
	
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
	
	[m_addContactKindPopUp setMenu:[m_delegate addContactController:self
										menuForAddingJIDsWithAction:@selector(addContactSelectedNewJIDKind:)]];
	[m_addContactKindPopUp selectItemAtIndex:[m_addContactKindPopUp indexOfItemWithRepresentedObject:[self hostOfJIDToBeAdded]]];
	
	[self p_setupJIDTabViewInsidePlaceholderView:m_addContactPlaceholderView
								 previousKeyView:m_groupComboBox
									 nextKeyView:m_nameComboBox
					   makeInitialFirstResponder:NO];
	
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
	NSAssert(m_sapoAgents, @"LPAddContactController needs sapo agents info to run!");
	
	NSParameterAssert(contact);
	[self setContact:contact];
	
	[self addJIDWindow]; // force loading the NIB
	m_parentWindow = parentWindow;
	m_currentlyOpenWindow = m_addJIDWindow;
	
	[m_addJIDKindPopUp setMenu:[m_delegate addContactController:self
									menuForAddingJIDsWithAction:@selector(addJIDSelectedNewJIDKind:)]];
	[m_addJIDKindPopUp selectItemAtIndex:[m_addJIDKindPopUp indexOfItemWithRepresentedObject:[self hostOfJIDToBeAdded]]];
	
	[self p_setupJIDTabViewInsidePlaceholderView:m_addJIDPlaceholderView
								 previousKeyView:nil
									 nextKeyView:nil
					   makeInitialFirstResponder:YES];
	
	[self p_reevaluateEnabledStateOfButtons];
	
	
	[NSApp beginSheet:[self addJIDWindow]
	   modalForWindow:parentWindow
		modalDelegate:self
	   didEndSelector:@selector(addJIDSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:NULL];
}

- (NSString *)p_resultingJID
{
	NSDictionary *sapoAgentsDict = [m_sapoAgents dictionaryRepresentation];
	NSDictionary *sapoAgentsProps = (([m_hostOfJIDToBeAdded length] > 0) ?
									 [sapoAgentsDict objectForKey:m_hostOfJIDToBeAdded] :
									 nil);
	
	if (sapoAgentsProps == nil) {
		return [m_normalJIDTextField stringValue];
	}
	else if ([sapoAgentsProps objectForKey:@"transport"] != nil) {
		
		if ([[m_roster account] isRegisteredWithTransportAgent:m_hostOfJIDToBeAdded]) {
			NSString *jid = [m_transportJIDTextField stringValue];
			NSArray *jidComponents = [jid componentsSeparatedByString:@"@"];
			
			return ( ([jidComponents count] >= 2) ?
					 [NSString stringWithFormat:@"%@%%%@@%@",
						 [jidComponents objectAtIndex:0], [jidComponents objectAtIndex:1], m_hostOfJIDToBeAdded] :
					 [NSString stringWithFormat:@"%@@%@",
						 jid, m_hostOfJIDToBeAdded] );
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
		
		
		NSString *newJID = [self p_resultingJID];
		NSString *contactName = [m_nameComboBox stringValue];
		NSString *groupName = [m_groupComboBox stringValue];
		
		LPContactEntry *existingContactEntry = [m_roster contactEntryForAddress:newJID searchOnlyUserAddedEntries:YES];
		LPContact *existingContact = [m_roster contactForName:contactName];
		
		NSDictionary *sapoAgentsDict = [m_sapoAgents dictionaryRepresentation];
		
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
				[newJID userPresentableJIDAsPerAgentsDictionary:sapoAgentsDict],
				[existingContact name]];
			infoMsg = [NSString stringWithFormat:NSLocalizedString(@"A contact named \"%@\" already exists.",
																   @"text for the \"add contact\" alerts"),
				[existingContact name]];
			
			defaultBtn = NSLocalizedString(@"Add To Existing Contact", @"\"add contact\" alert button");
			ctx = LPAddContactDuplicateNameAlertContext;
		}
		else if (existingContactEntry != nil) {
			msg = NSLocalizedString(@"Do you want to create a new contact and have the address moved into it?",
									@"text for the \"add contact\" alerts");
			infoMsg = [NSString stringWithFormat:NSLocalizedString(@"The existing contact named \"%@\" already contains the address \"%@\". If you "
																   @"choose to proceed, a new contact named \"%@\" will be created and the address "
																   @"will be moved into it.",
																   @"text for the \"add contact\" alerts"),
				[[existingContactEntry contact] name],
				[existingContactEntry humanReadableAddress],
				contactName];
			
			defaultBtn = NSLocalizedString(@"Move To New Contact", @"\"add contact\" alert button");
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
			[newContact addNewContactEntryWithAddress:newJID];
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
		NSString *newJID = [self p_resultingJID];
		NSString *contactName = [m_nameComboBox stringValue];
		NSString *groupName = [m_groupComboBox stringValue];
		
		if (contextInfo == LPAddContactDuplicateNameAndJIDAlertContext) {
			// Edit
			LPContactEntry *existingEntry = [m_roster contactEntryForAddress:newJID];
			LPContact *existingEntrysContact = [existingEntry contact];
			LPContact *existingContact = [m_roster contactForName:contactName];
			
			[[NSApp delegate] showWindowForEditingContact:existingContact];
			if (existingEntrysContact != existingContact)
				[[NSApp delegate] showWindowForEditingContact:existingEntrysContact];
		}
		else if (contextInfo == LPAddContactDuplicateNameAlertContext) {
			// Add new entry to the existing contact having a name equal to the one that was entered
			LPContact *existingContact = [m_roster contactForName:contactName];
			[existingContact addNewContactEntryWithAddress:newJID];
		}
		else if (contextInfo == LPAddContactDuplicateJIDAlertContext) {
			LPContactEntry *existingEntry = [m_roster contactEntryForAddress:newJID];
			
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
	
	NSString *newJID = [self p_resultingJID];
	
	if ((returnCode == NSOKButton) && ([newJID length] > 0)) {
		LPContactEntry *existingContactEntry = [[[self contact] roster] contactEntryForAddress:newJID
																	searchOnlyUserAddedEntries:YES];
		
		if (existingContactEntry == nil) {
			[[self contact] addNewContactEntryWithAddress:newJID];
		}
		else {
			NSString *msg = [NSString stringWithFormat:
				NSLocalizedString(@"Do you want to move the address \"%@\" from contact \"%@\" into contact \"%@\"?",
								  @"roster edit warning"),
				[existingContactEntry humanReadableAddress], 
				[[existingContactEntry contact] name],
				[[self contact] name]];
			NSString *infoFormatStr = NSLocalizedString(@"The existing contact named \"%@\" already contains the address \"%@\". If "
														@"you proceed, the address will be removed from that contact and will be "
														@"added to the contact \"%@\".", @"roster edit warning");
			NSString *alternateBtn = [NSString stringWithFormat:NSLocalizedString(@"Edit Contact \"%@\"",
																				  @"roster edit warning button"),
				[[existingContactEntry contact] name]];
			
			NSAlert *alert = [NSAlert alertWithMessageText:msg
											 defaultButton:NSLocalizedString(@"Move", @"roster edit warning button")
										   alternateButton:alternateBtn
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
	
	NSString *newJID = [self p_resultingJID];
	LPContactEntry *existingContactEntry = [m_roster contactEntryForAddress:newJID];
	
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


- (IBAction)addContactSelectedNewJIDKind:(id)sender
{
	[self setHostOfJIDToBeAdded:[sender representedObject]];
	[self p_setupJIDTabViewInsidePlaceholderView:m_addContactPlaceholderView
								 previousKeyView:m_groupComboBox
									 nextKeyView:m_nameComboBox
					   makeInitialFirstResponder:NO];
	
	[self p_reevaluateEnabledStateOfButtons];
}

- (IBAction)addJIDSelectedNewJIDKind:(id)sender
{
	[self setHostOfJIDToBeAdded:[sender representedObject]];
	[self p_setupJIDTabViewInsidePlaceholderView:m_addJIDPlaceholderView
								 previousKeyView:nil
									 nextKeyView:nil
					   makeInitialFirstResponder:NO];
	
	[self p_reevaluateEnabledStateOfButtons];
}

- (IBAction)ok:(id)sender
{
	[NSApp endSheet:m_currentlyOpenWindow returnCode:NSOKButton];
}

- (IBAction)cancel:(id)sender
{
	[NSApp endSheet:m_currentlyOpenWindow returnCode:NSCancelButton];
}


@end

