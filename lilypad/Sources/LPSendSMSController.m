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
#import "NSString+JIDAdditions.h"


@implementation LPSendSMSController

- (void)p_addContactEntryToRecipients:(LPContactEntry *)contactEntry
{
	NSArray *recipients = [self recipients];
	
	if (![recipients containsObject:contactEntry]) {
		[self setRecipients:[recipients arrayByAddingObject:contactEntry]];
	}
}

- (void)p_addContactToRecipients:(LPContact *)contact
{
	NSArray *smsEntries = [contact smsContactEntries];
	NSSet *smsEntriesSet = [NSSet setWithArray:smsEntries];
	NSSet *recipientsSet = [NSSet setWithArray:[self recipients]];
	
	if (![recipientsSet intersectsSet:smsEntriesSet] && [smsEntries count] > 0)
		[self p_addContactEntryToRecipients:[smsEntries objectAtIndex:0]];
}

- (void)p_removeContactEntryFromRecipients:(LPContactEntry *)contactEntry
{
	NSArray *recipients = [self recipients];
	
	if ([recipients containsObject:contactEntry]) {
		NSMutableArray *newRecipients = [[recipients mutableCopy] autorelease];
		
		[newRecipients removeObject:contactEntry];
		[self setRecipients:newRecipients];
	}
}

- (void)p_removeContactFromRecipients:(LPContact *)contact
{
	NSEnumerator *entryEnum = [[contact smsContactEntries] objectEnumerator];
	LPContactEntry *entry;
	while (entry = [entryEnum nextObject]) {
		[self p_removeContactEntryFromRecipients:entry];
	}
}

- (void)p_replaceContactEntryFromRecipients:(LPContactEntry *)prevEntry withContactEntry:(LPContactEntry *)newEntry
{
	NSArray *recipients = [self recipients];
	
	if ([recipients containsObject:prevEntry] && ![recipients containsObject:newEntry]) {
		NSMutableArray *newRecipients = [[recipients mutableCopy] autorelease];
		NSUInteger prevEntryIndex = [newRecipients indexOfObject:prevEntry];
		
		[newRecipients replaceObjectAtIndex:prevEntryIndex withObject:newEntry];
		[self setRecipients:newRecipients];
	}
}

#pragma mark -

- initWithContact:(LPContact *)contact delegate:(id)delegate
{
	if (self = [self initWithWindowNibName:@"SendSMS"]) {
		m_delegate = delegate;
		[self p_addContactToRecipients:contact];
	}
	return self;
}

- (void)windowDidLoad
{
	[m_colorBackgroundView setBackgroundColor:
		[NSColor colorWithPatternImage:( [[LPAccountsController sharedAccountsController] isOnline] ?
										 [NSImage imageNamed:@"chatIDBackground"] :
										 [NSImage imageNamed:@"chatIDBackground_Offline"] )]];
	[m_colorBackgroundView setBorderColor:[NSColor colorWithCalibratedWhite:0.60 alpha:1.0]];
	
	[m_characterCountField setStringValue:[NSString stringWithFormat: NSLocalizedString(@"%d characters",
																						@"SMS window character count"), 0]];
	
	[m_accountsController setContent:[LPAccountsController sharedAccountsController]];
}


- (NSArray *)recipients
{
	NSArray *recipients = [m_recipientsField objectValue];
	return (recipients != nil ? recipients : [NSArray array]);
}


- (void)setRecipients:(NSArray *)recipients
{
	// Since we use the NSTokenField itself to store the values, then make sure that our window is loaded first
	[self window];
	
	[m_recipientsField setObjectValue:recipients];
}


- (IBAction)selectSMSAddress:(id)sender
{
	LPContactEntry *originalEntry = [sender representedObject];
	
	NSString *phoneJID = [[sender title] internalPhoneJIDRepresentation];
	LPContactEntry *selectedEntry = [[LPRoster roster] contactEntryInAnyAccountForAddress:phoneJID];
	
	[self p_replaceContactEntryFromRecipients:originalEntry withContactEntry:selectedEntry];
}


- (IBAction)sendSMS:(id)sender
{
	LPRoster *roster = [LPRoster roster];
	NSMutableSet *alreadySentToEntries = [NSMutableSet set];
	
	NSEnumerator *recipientEnum = [[self recipients] objectEnumerator];
	id recipient;
	
	while (recipient = [recipientEnum nextObject]) {
		LPContactEntry *entry = nil;
		
		if ([recipient isKindOfClass:[LPContactEntry class]]) {
			entry = recipient;
		}
		else if ([recipient isKindOfClass:[NSString class]]) {
			NSString *phoneJID = [recipient internalPhoneJIDRepresentation];
			entry = [roster contactEntryInAnyAccountForAddress:phoneJID createNewHiddenWithNameIfNotFound:phoneJID];
		}
		
		if (entry != nil && ![alreadySentToEntries containsObject:entry]) {
			[LFAppController sendSMSToEntry:[entry ID] :[m_messageTextView string]];
			[alreadySentToEntries addObject:entry];
		}
	}
	
	[[self window] close];
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


#pragma mark -
#pragma mark NSTokenField Delegate Methods


- (NSArray *)tokenField:(NSTokenField *)tokenField completionsForSubstring:(NSString *)substring indexOfToken:(NSInteger)tokenIndex indexOfSelectedItem:(NSInteger *)selectedIndex
{
	NSMutableArray *matchingContactEntries = [NSMutableArray array];
	NSString *lowerSubstring = [substring lowercaseString];
	
	LPRoster *roster = [LPRoster roster];
	
	NSEnumerator *contactsEnum = [[roster allContacts] objectEnumerator];
	LPContact *contact;
	while (contact = [contactsEnum nextObject]) {
		if ([contact isInUserRoster] && [[contact smsContactEntries] count] > 0) {
			if ([[[contact name] lowercaseString] hasPrefix:lowerSubstring]) {
				[matchingContactEntries addObject:[contact name]];
				continue;
			}
			else {
				NSEnumerator *entriesEnum = [[contact smsContactEntries] objectEnumerator];
				LPContactEntry *entry;
				while (entry = [entriesEnum nextObject]) {
					NSString *entryPhoneJID = [entry address];
					
					if ([entryPhoneJID isPhoneJID]) {
						NSString *entryPhoneNr = ([entryPhoneJID hasPrefix:@"00351"] ?
												  [[entryPhoneJID JIDUsernameComponent] substringFromIndex:5] :
												  [entryPhoneJID JIDUsernameComponent]);
						
						if ([entryPhoneNr hasPrefix:lowerSubstring]) {
							if (![[self recipients] containsObject:entry]) {
								[matchingContactEntries addObject:entryPhoneNr];
							}
							break;
						}
					}
				}
			}
		}
	}
	
	return matchingContactEntries;
}


// If you return nil or don't implement these delegate methods, we will assume
// editing string = display string = represented object
- (NSString *)tokenField:(NSTokenField *)tokenField displayStringForRepresentedObject:(id)representedObject
{
	return ([representedObject isKindOfClass:[LPContactEntry class]] ?
			[[representedObject contact] name] :
			representedObject);
}


- (id)tokenField:(NSTokenField *)tokenField representedObjectForEditingString:(NSString *)editingString
{
	id representedObject = editingString;
	
	// Check whether we have it in the roster
	LPRoster		*roster = [LPRoster roster];
	
	NSString		*phoneJID = [editingString internalPhoneJIDRepresentation];
	LPContactEntry	*contactEntry = [roster contactEntryInAnyAccountForAddress:phoneJID
												    searchOnlyUserAddedEntries:YES];
	
	if (contactEntry != nil) {
		representedObject = contactEntry;
	}
	else {
		NSArray *smsContactEntries = [[roster contactForName:editingString] smsContactEntries];
		if ([smsContactEntries count] > 0) {
			representedObject = [smsContactEntries objectAtIndex:0];
		}
	}
	
	return representedObject;
}


// We put the string on the pasteboard before calling this delegate method. 
// By default, we write the NSStringPboardType as well as an array of NSStrings.
- (BOOL)tokenField:(NSTokenField *)tokenField writeRepresentedObjects:(NSArray *)objects toPasteboard:(NSPasteboard *)pboard
{
	//...
	return NO;
}


// Return an array of represented objects to add to the token field.
- (NSArray *)tokenField:(NSTokenField *)tokenField readFromPasteboard:(NSPasteboard *)pboard
{
	//...
	return [NSArray array];
}


- (NSMenu *)tokenField:(NSTokenField *)tokenField menuForRepresentedObject:(id)representedObject
{
	NSMenu *menu = [[NSMenu alloc] init];
	
	if ([representedObject isKindOfClass:[LPContactEntry class]]) {
		NSArray *recipients = [self recipients];
		
		NSEnumerator *entryEnum = [[[representedObject contact] smsContactEntries] objectEnumerator];
		LPContactEntry *contactEntry;
		
		while (contactEntry = [entryEnum nextObject]) {
			
			NSMenuItem *item = [menu addItemWithTitle:[contactEntry humanReadableAddress]
											   action:@selector(selectSMSAddress:)
										keyEquivalent:@""];
			
			[item setRepresentedObject:representedObject];
			
			if (contactEntry == representedObject) {
				[item setState:NSOnState];
			}
			
			if (![contactEntry isOnline] || (contactEntry != representedObject && [recipients containsObject:contactEntry])) {
				[item setEnabled:NO];
				[item setAction:NULL];
			}
		}
	}
	else {
		// TODO: "Add this phone nr to the roster"
		[menu addItemWithTitle:@"Add this phone nr to the roster" action:NULL keyEquivalent:@""];
	}
	
	return [menu autorelease];
}


- (BOOL)tokenField:(NSTokenField *)tokenField hasMenuForRepresentedObject:(id)representedObject
{
	return YES;
}


@end
