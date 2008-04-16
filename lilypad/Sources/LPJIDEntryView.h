//
//  LPJIDEntryView.h
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


@class LPAccount;
@class LPAccountsController;


@interface LPJIDEntryView : NSView
{
	// Top-level NIB objects
	// These are not marked with "IBOutlet" so that they don't show up in IB when this view
	// is used inside another client NIB file.
	NSView				*m_assembledControlsView;
	
	NSPopUpButton		*m_servicePopUp;
	NSPopUpButton		*m_accountPopUp;
	NSTabView			*m_JIDTabView;
	
	NSTextField			*m_normalJIDTextField;
	NSTextField			*m_sapoJIDTextField;
	NSTextField			*m_sapoHostnameTextField;
	NSTextField			*m_transportJIDTextField;
	NSTextField			*m_transportNameTextField;
	NSTextField			*m_phoneNrTextField;
	
	// The text-field currently being displayed and where the user can enter text.
	// One of: m_normalJIDTextField, m_sapoJIDTextField, m_transportJIDTextField, m_phoneNrTextField.
	NSTextField			*m_jidEntryTextField;
	
	id					m_delegate;
	
	LPAccount			*m_account;
	NSString			*m_selectedServiceHostname;
}

- (id)initWithFrame:(NSRect)frameRect;

- (id)delegate;
- (void)setDelegate:(id)delegate;

- (LPAccountsController *)accountsController;

- (LPAccount *)account;
- (NSString *)selectedServiceHostname;
- (void)setSelectedServiceHostname:(NSString *)hostname;

// The text-field currently being displayed and where the user can enter text.
// One of: m_normalJIDTextField, m_sapoJIDTextField, m_transportJIDTextField, m_phoneNrTextField.
- (NSTextField *)JIDEntryTextField;
- (NSString *)enteredJID;

- (IBAction)serviceSelectionDidChange:(id)sender;
- (IBAction)accountSelectionDidChange:(id)sender;

@end


@interface NSObject (LPJIDEntryViewDelegate)
- (void)JIDEntryViewEnteredJIDDidChange:(LPJIDEntryView *)view;
- (void)JIDEntryViewEntryTextFieldDidChange:(LPJIDEntryView *)view;
@end

