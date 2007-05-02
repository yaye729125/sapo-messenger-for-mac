//
//  LPTermsOfUseController.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>

@interface LPTermsOfUseController : NSWindowController
{
    IBOutlet NSButton *m_okButton;
    IBOutlet NSMatrix *m_radioButtons;
    IBOutlet NSTextView *m_textView;
}

+ (LPTermsOfUseController *)termsOfUse;
- init;
- (int)runModal;

- (IBAction)cancelClicked:(id)sender;
- (IBAction)okClicked:(id)sender;
- (IBAction)radioButtonClicked:(id)sender;
@end
