//
//  LPSendSMSController.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


@class LPColorBackgroundView, LPContact;


@interface LPSendSMSController : NSWindowController
{
	IBOutlet LPColorBackgroundView	*m_colorBackgroundView;
	IBOutlet NSTextField			*m_characterCountField;
	IBOutlet NSTextView				*m_messageTextView;
	IBOutlet NSTokenField			*m_recipientsField;
	
	IBOutlet NSObjectController		*m_accountsController;
	
	id								m_delegate;
}

- initWithContact:(LPContact *)contact delegate:(id)delegate;
- initWithContacts:(NSArray *)contactList delegate:(id)delegate;

/*
 * Array with instances of LPContactEntry (for JIDs on the roster) and
 * NSString (for JIDs entered directly by the user in the Send SMS window,
 * and which are not present in the roster).
 */
- (NSArray *)recipients;
- (void)setRecipients:(NSArray *)recipients;

- (IBAction)selectSMSAddress:(id)sender;
- (IBAction)sendSMS:(id)sender;

@end


@interface NSObject (LPSendSMSController)
- (void)smsControllerWindowWillClose:(LPSendSMSController *)smsCtrl;
@end
