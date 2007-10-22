//
//  LPAccountNameTextField.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPAccountNameTextField.h"


@implementation LPAccountNameTextField

- initWithFrame:(NSRect)frameRect
{
	if (self = [super initWithFrame:frameRect]) {
		m_stringValues = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void)awakeFromNib
{
	if (m_stringValues == nil) {
		m_stringValues = [[NSMutableArray alloc] init];
	}
}

- (void)dealloc
{
	[m_stringValues release];
	[super dealloc];
}

- (void)p_synchronizeDisplayWithStringsList
{
	if ([m_stringValues count] > 0) {
		NSString *displayedString = [self stringValue];
		if (![m_stringValues containsObject:displayedString]) {
			[self setStringValue:[self stringValueAtIndex:0]];
		}
	}
	else {
		[self setStringValue:@"--"];
	}
}

- (NSString *)stringValueAtIndex:(unsigned)index
{
	return (index < [m_stringValues count] ? [m_stringValues objectAtIndex:index] : nil);
}

- (void)addStringValue:(NSString *)string
{
	[m_stringValues addObject:string];
	[self p_synchronizeDisplayWithStringsList];
}

- (void)insertStringValue:(NSString *)string atIndex:(unsigned)index
{
	[m_stringValues insertObject:string atIndex:index];
	[self p_synchronizeDisplayWithStringsList];
}

- (void)clearAllStringValues
{
	[m_stringValues removeAllObjects];
	[self p_synchronizeDisplayWithStringsList];
}

- (void)mouseDown:(NSEvent *)theEvent
{
	[self toggleDisplay:nil];
}

- (IBAction)toggleDisplay:(id)sender
{
	NSString *displayedString = [self stringValue];
	int displayedStringIndex = [m_stringValues indexOfObject:displayedString];
	
	if (displayedStringIndex != NSNotFound && [m_stringValues count] > 0) {
		// Move to the next one
		int nextIndex = (displayedStringIndex + 1) % [m_stringValues count];
		[self setStringValue:[self stringValueAtIndex:nextIndex]];
	}
	else {
		// Just make sure that the text field is synchronized with the internal list of strings
		[self p_synchronizeDisplayWithStringsList];
	}
}

@end
