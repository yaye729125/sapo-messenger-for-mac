//
//  LPAccountsPopUpButtonController.h
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

@interface LPAccountsPopUpButtonController : NSObject
{
	NSPopUpButton	*m_popUpButton;
	LPAccount		*m_selectedAccount;
}

- (NSPopUpButton *)popUpButton;
- (void)setPopUpButton:(NSPopUpButton *)button;
- (LPAccount *)selectedAccount;
- (void)setSelectedAccount:(LPAccount *)account;

- (IBAction)accountSelectionDidChange:(id)sender;

@end
