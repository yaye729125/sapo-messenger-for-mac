//
//  LPAccountNameTextField.h
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>
#import "LPEmbossedTextField.h"


@interface LPAccountNameTextField : LPEmbossedTextField
{
	NSMutableArray *m_stringValues;
}

- (NSString *)stringValueAtIndex:(unsigned)index;
- (void)addStringValue:(NSString *)string;
- (void)insertStringValue:(NSString *)string atIndex:(unsigned)index;

- (void)clearAllStringValues;

- (void)mouseDown:(NSEvent *)theEvent;
- (IBAction)toggleDisplay:(id)sender;

@end
