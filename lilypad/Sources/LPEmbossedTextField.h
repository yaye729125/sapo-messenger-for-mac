//
//  LPEmbossedTextField.h
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Authors: Joao Pavao <jpavao@co.sapo.pt>
//           Jason Kim <jason@512k.org>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//
//
// Displays text with an embossed appearance (as is common in Apple's textured windows).
//
// This subclass of NSTextField is used primarily for labels, and isn't as robust as it ultimately
// could be.
//

#import <Cocoa/Cocoa.h>


@interface LPEmbossedTextField : NSTextField 
- (void)drawRect:(NSRect)rect;
@end
