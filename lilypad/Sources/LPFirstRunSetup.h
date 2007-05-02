//
//  LPFirstRunSetup.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


@class LPAccountsController;


@interface LPFirstRunSetup : NSWindowController
{
    IBOutlet NSImageView	*m_backgroundView;
    IBOutlet NSTextField	*m_passwordField;
	
	NSString	*m_JID;
	NSString	*m_password;
}

+ (LPFirstRunSetup *)firstRunSetup;

- (NSString *)JID;
- (void)setJID:(NSString *)aJID;
- (NSString *)password;
- (void)setPassword:(NSString *)aPassword;

- (void)runModal;

- (LPAccountsController *)accountsController;

- (IBAction)okClicked:(id)sender;
- (IBAction)quitClicked:(id)sender;

@end
