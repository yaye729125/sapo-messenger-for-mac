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
	IBOutlet NSArrayController		*m_entriesController;
	IBOutlet NSObjectController		*m_contactController;
	
	id			m_delegate;
	LPContact	*m_contact;
}

- initWithContact:(LPContact *)contact delegate:(id)delegate;
- (LPContact *)contact;

- (IBAction)sendSMS:(id)sender;

@end


@interface NSObject (LPSendSMSController)
- (void)smsControllerWindowWillClose:(LPSendSMSController *)smsCtrl;
@end
