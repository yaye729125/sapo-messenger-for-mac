//
//  LPAddContactController.h
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


@class LPRoster, LPContact;
@class LPJIDEntryView;


@interface LPAddContactController : NSObject
{
	// Top-level NIB objects
	IBOutlet NSWindow			*m_addContactWindow;
	IBOutlet NSWindow			*m_addJIDWindow;
	
	IBOutlet NSButton			*m_addContactButton;
	IBOutlet NSButton			*m_addJIDButton;
	
	IBOutlet NSComboBox			*m_nameComboBox;
	IBOutlet NSComboBox			*m_groupComboBox;
	
	IBOutlet LPJIDEntryView		*m_addContactAddressEntryView;
	IBOutlet LPJIDEntryView		*m_addJIDAddressEntryView;
	
	IBOutlet NSTextView			*m_addContactReasonTextView;
	IBOutlet NSTextView			*m_addJIDReasonTextView;
	
	IBOutlet NSObjectController	*m_contactController;
	
	id					m_delegate;
	
	NSWindow			*m_parentWindow;
	NSWindow			*m_currentlyOpenWindow;
	
	LPRoster			*m_roster;
	LPContact			*m_contact;
}

- initWithRoster:(LPRoster *)roster delegate:(id)delegate;

- (NSString *)hostOfJIDToBeAdded;
- (void)setHostOfJIDToBeAdded:(NSString *)hostname;
- (LPContact *)contact;
- (void)setContact:(LPContact *)contact;

- (NSString *)JID;
- (void)setJID:(NSString *)theJID;
- (NSString *)contactName;
- (void)setContactName:(NSString *)contactName;
- (NSString *)groupName;
- (void)setGroupName:(NSString *)groupName;

- (NSWindow *)addContactWindow;
- (NSWindow *)addJIDWindow;
- (void)runForAddingContactAsSheetForWindow:(NSWindow *)parentWindow;
- (void)runForAddingJIDToContact:(LPContact *)contact asSheetForWindow:(NSWindow *)parentWindow;

- (IBAction)ok:(id)sender;
- (IBAction)cancel:(id)sender;

@end
