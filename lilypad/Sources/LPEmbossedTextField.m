//
//  LPEmbossedTextField.m
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Authors: Joao Pavao <jpavao@co.sapo.pt>
//           Jason Kim <jason@512k.org>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPEmbossedTextField.h"


static NSDictionary *_textAttribs = nil;


@implementation LPEmbossedTextField


- (void)drawRect:(NSRect)rect
{
	NSAttributedString *attributedString;
	
	if (_textAttribs == nil) {
		NSShadow *shadow = [[NSShadow alloc] init];
		
		[shadow setShadowColor:[NSColor colorWithCalibratedWhite:1.0 alpha:0.65]];
		[shadow setShadowBlurRadius:0.0];
		[shadow setShadowOffset:NSMakeSize(0.0, -1.0)];
		
		_textAttribs = [[NSDictionary alloc] initWithObjectsAndKeys:
			shadow, NSShadowAttributeName,
			nil];
		[shadow release];
	}
	
	NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
	[paragraphStyle setAlignment:[self alignment]];
	[paragraphStyle setLineBreakMode:[[self cell] lineBreakMode]];
	[paragraphStyle setBaseWritingDirection:[self baseWritingDirection]];
	
	NSMutableDictionary *attribs = [_textAttribs mutableCopy];
	[attribs setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
	[paragraphStyle release];
	
	attributedString = [[NSAttributedString alloc] initWithString:[self stringValue] attributes:attribs];
	[attribs release];
	
	[self setAttributedStringValue:attributedString];
	[attributedString release];

	[super drawRect:rect];
}


@end
