//
//  LPModelessAlert.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


@class LPContactEntry;


@interface LPModelessAlert : NSWindowController
{
	IBOutlet NSTextField	*m_msgField;
	IBOutlet NSTextField	*m_infoMsgField;
	IBOutlet NSView			*m_buttonsBox;
	IBOutlet NSButton		*m_firstButton;
	IBOutlet NSButton		*m_secondButton;
	IBOutlet NSButton		*m_thirdButton;
	
	id						m_delegate;
	SEL						m_didEndSel;
	void					*m_ctxInfo;
	int						m_returnCode;
}

+ modelessAlert;
- init;

- (NSString *)messageText;
- (void)setMessageText:(NSString *)msg;
- (NSString *)informativeText;
- (void)setInformativeText:(NSString *)infoMsg;
- (NSString *)firstButtonTitle;
- (void)setFirstButtonTitle:(NSString *)title;
- (NSString *)secondButtonTitle;
- (void)setSecondButtonTitle:(NSString *)title;
- (NSString *)thirdButtonTitle;
- (void)setThirdButtonTitle:(NSString *)title;

// didEndSelector must be of the form:
//     - (void)alertDidEnd:(LPModelessAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)showWindowWithDelegate:(id)delegate didEndSelector:(SEL)sel contextInfo:(void *)contextInfo makeKey:(BOOL)keyFlag;

- (IBAction)firstButtonClicked:(id)sender;
- (IBAction)secondButtonClicked:(id)sender;
- (IBAction)thirdButtonClicked:(id)sender;

@end
