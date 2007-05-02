//
//  LPAccountNameTextField.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>
#import "LPEmbossedTextField.h"


typedef enum {
	LPShowAccountName,
	LPShowAccountJID
} LPAccountNameFieldState;


@interface LPAccountNameTextField : LPEmbossedTextField
{
	NSString *m_name;
	NSString *m_jid;
	LPAccountNameFieldState m_currentState;
}

- (NSString *)accountName;
- (void)setAccountName:(NSString *)name;
- (NSString *)accountJID;
- (void)setAccountJID:(NSString *)jid;

- (void)mouseDown:(NSEvent *)theEvent;
- (IBAction)toggleDisplay:(id)sender;

@end
