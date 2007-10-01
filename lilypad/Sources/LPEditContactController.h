//
//  LPEditContactController.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


@class LPContact, LPAddContactController;
@class LPColorBackgroundView;


@interface LPEditContactController : NSWindowController
{
	// Main Groups of Views
	IBOutlet NSView					*m_regularElements;
	IBOutlet NSView					*m_debuggingElements;
	
	IBOutlet LPColorBackgroundView	*m_headerBackground;
	IBOutlet NSTextField			*m_contactNameField;
	IBOutlet NSArrayController		*m_entriesController;
	IBOutlet NSTextView				*m_connectionsDescriptionView;
	IBOutlet NSTableView			*m_contactEntriesTableView;
	
	IBOutlet NSObjectController		*m_contactController;
	
	id								m_delegate;
	LPContact						*m_contact;
	LPAddContactController			*m_addContactController;
}

- initWithContact:(LPContact *)contact delegate:(id)delegate;

- (LPContact *)contact;
- (NSString *)groupsListString;

- (IBAction)renameContact:(id)sender;
- (IBAction)addContactEntry:(id)sender;
- (IBAction)removeContactEntries:(id)sender;

@end


@interface NSObject (LPEditContactControllerDelegate)
- (void)editContactControllerWindowWillClose:(LPEditContactController *)editCtrl;
- (void)editContactController:(LPEditContactController *)ctrl editContact:(LPContact *)contact;
@end
