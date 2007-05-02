//
//  LPAddContactController.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


@class LPRoster, LPContact, LPSapoAgents;


@interface LPAddContactController : NSObject
{
	// Top-level NIB objects
	IBOutlet NSWindow			*m_addContactWindow;
	IBOutlet NSWindow			*m_addJIDWindow;
	IBOutlet NSTabView			*m_JIDTabView;
	
	IBOutlet NSButton			*m_addContactButton;
	IBOutlet NSButton			*m_addJIDButton;
	
	IBOutlet NSComboBox			*m_nameComboBox;
	IBOutlet NSComboBox			*m_groupComboBox;
	IBOutlet NSView				*m_addContactPlaceholderView;
	IBOutlet NSView				*m_addJIDPlaceholderView;
	
	IBOutlet NSPopUpButton		*m_addContactKindPopUp;
	IBOutlet NSPopUpButton		*m_addJIDKindPopUp;
	
	IBOutlet NSTextField		*m_normalJIDTextField;
	IBOutlet NSTextField		*m_sapoJIDTextField;
	IBOutlet NSTextField		*m_sapoHostnameTextField;
	IBOutlet NSTextField		*m_transportJIDTextField;
	IBOutlet NSTextField		*m_transportNameTextField;
	IBOutlet NSTextField		*m_phoneNrTextField;
	
	IBOutlet NSObjectController	*m_contactController;
	
	id					m_delegate;
	
	NSWindow			*m_parentWindow;
	NSWindow			*m_currentlyOpenWindow;
	NSTextField			*m_jidEntryTextField;
	
	LPRoster			*m_roster;
	LPContact			*m_contact;
	LPSapoAgents		*m_sapoAgents;
	
	NSString			*m_hostOfJIDToBeAdded;
}

- initWithRoster:(LPRoster *)roster delegate:(id)delegate;

- (LPSapoAgents *)sapoAgents;
- (void)setSapoAgents:(LPSapoAgents *)sapoAgents;
- (NSString *)hostOfJIDToBeAdded;
- (void)setHostOfJIDToBeAdded:(NSString *)hostname;
- (LPContact *)contact;
- (void)setContact:(LPContact *)contact;

- (NSWindow *)addContactWindow;
- (NSWindow *)addJIDWindow;
- (void)runForAddingContactAsSheetForWindow:(NSWindow *)parentWindow;
- (void)runForAddingJIDToContact:(LPContact *)contact asSheetForWindow:(NSWindow *)parentWindow;

- (IBAction)addContactSelectedNewJIDKind:(id)sender;
- (IBAction)addJIDSelectedNewJIDKind:(id)sender;
- (IBAction)ok:(id)sender;
- (IBAction)cancel:(id)sender;

@end


@interface NSObject (LPAddContactControllerDelegate)
- (NSMenu *)addContactController:(LPAddContactController *)addContactCtrl menuForAddingJIDsWithAction:(SEL)action;
@end

