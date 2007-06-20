//
//  LPModelessAlert.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informa›es sobre o licenciamento, leia o ficheiro README.
//

#import "LPModelessAlert.h"


@implementation LPModelessAlert

+ modelessAlert
{
	return [[[[self class] alloc] init] autorelease];
}

- init
{
	return [self initWithWindowNibName:@"ModelessAlert"];
}

- (void)dealloc
{
	[m_delegate release];
	[super dealloc];
}

- (NSString *)messageText
{
	return [m_msgField stringValue];
}

- (void)setMessageText:(NSString *)msg
{
	[self window];
	[m_msgField setStringValue:msg];
}

- (NSString *)informativeText
{
	return [m_infoMsgField stringValue];
}

- (void)setInformativeText:(NSString *)infoMsg
{
	[self window];
	[m_infoMsgField setStringValue:infoMsg];
}

- (NSString *)firstButtonTitle
{
	return [m_firstButton title];
}

- (void)setFirstButtonTitle:(NSString *)title
{
	[self window];
	[m_firstButton setTitle:title];
}

- (NSString *)secondButtonTitle
{
	return [m_secondButton title];
}

- (void)setSecondButtonTitle:(NSString *)title
{
	[self window];
	[m_secondButton setTitle:title];
}

- (NSString *)thirdButtonTitle
{
	return [m_thirdButton title];
}

- (void)setThirdButtonTitle:(NSString *)title
{
	[self window];
	[m_thirdButton setTitle:title];
}

#define BUTTON_HORIZ_SEPARATION  12.0
#define EXTRA_BUTTON_PADDING     20.0

- (void)p_layoutWindow
{
	NSRect windowFrame = [[self window] frame];
	NSRect firstButtonFrame = [m_firstButton frame];
	NSRect secondButtonFrame = [m_secondButton frame];
	NSRect thirdButtonFrame = [m_thirdButton frame];
	float delta;
	
	// Take care of the buttons
	float prevButtonRowWidth = NSMaxX(firstButtonFrame) - NSMinX(thirdButtonFrame);
	float newButtonRowWidth = 0.0;
	
	if ([[self firstButtonTitle] length] == 0)
		[self setFirstButtonTitle:NSLocalizedString(@"OK", @"")];
	
	delta = ([[m_firstButton cell] cellSize].width + EXTRA_BUTTON_PADDING) - NSWidth(firstButtonFrame);
	firstButtonFrame.size.width += delta;
	firstButtonFrame.origin.x -= delta;
	secondButtonFrame.origin.x -= delta;
	newButtonRowWidth += firstButtonFrame.size.width;
	[m_firstButton setFrame:firstButtonFrame];
	
	if ([[m_secondButton title] length] == 0) {
		[m_secondButton removeFromSuperview];
		m_secondButton = nil;
	} else {
		delta = ([[m_secondButton cell] cellSize].width + EXTRA_BUTTON_PADDING) - NSWidth(secondButtonFrame);
		secondButtonFrame.size.width += delta;
		secondButtonFrame.origin.x -= delta;
		newButtonRowWidth += BUTTON_HORIZ_SEPARATION + secondButtonFrame.size.width;
		[m_secondButton setFrame:secondButtonFrame];
	}
	
	if ([[m_thirdButton title] length] == 0) {
		[m_thirdButton removeFromSuperview];
		m_thirdButton = nil;
	} else {
		delta = ([[m_thirdButton cell] cellSize].width + EXTRA_BUTTON_PADDING) - NSWidth(thirdButtonFrame);
		thirdButtonFrame.size.width += delta;
		newButtonRowWidth += BUTTON_HORIZ_SEPARATION + thirdButtonFrame.size.width;
		[m_thirdButton setFrame:thirdButtonFrame];
	}
	
	// Do we need to grow the window horizontally?
	if (newButtonRowWidth > prevButtonRowWidth) {
		delta = newButtonRowWidth - prevButtonRowWidth;
		
		// The other views will be autoresized appropriately as per their "springs" mask
		// when we change the window frame.
		windowFrame.size.width += delta;
		[[self window] setFrame:windowFrame display:NO];
	}
	
	// Now size the text fields
	NSRect msgFrame = [m_msgField frame];
	NSRect infoMsgFrame = [m_infoMsgField frame];
	NSRect buttonsBoxFrame = [m_buttonsBox frame];
	
	NSSize msgIdealSize = [[m_msgField cell] cellSizeForBounds:[m_msgField bounds]];
	NSSize infoMsgIdealSize = [[m_infoMsgField cell] cellSizeForBounds:[m_infoMsgField bounds]];
	float msgHeightDelta = msgIdealSize.height - msgFrame.size.height;
	float infoMsgHeightDelta = infoMsgIdealSize.height - infoMsgFrame.size.height;
	
	msgFrame.origin.y -= msgHeightDelta;
	msgFrame.size.height += msgHeightDelta;
	infoMsgFrame.origin.y -= msgHeightDelta;
	buttonsBoxFrame.origin.y -= msgHeightDelta;
	windowFrame.origin.y -= msgHeightDelta;
	windowFrame.size.height += msgHeightDelta;
	
	infoMsgFrame.origin.y -= infoMsgHeightDelta;
	infoMsgFrame.size.height += infoMsgHeightDelta;
	buttonsBoxFrame.origin.y -= infoMsgHeightDelta;
	windowFrame.origin.y -= infoMsgHeightDelta;
	windowFrame.size.height += infoMsgHeightDelta;
	
	[m_msgField setFrame:msgFrame];
	[m_infoMsgField setFrame:infoMsgFrame];
	[m_buttonsBox setFrame:buttonsBoxFrame];
	[[self window] setFrame:windowFrame display:YES];
}

- (void)showWindowWithDelegate:(id)delegate didEndSelector:(SEL)sel contextInfo:(void *)contextInfo makeKey:(BOOL)keyFlag
{
	if (![[self window] isVisible]) {
		m_delegate = [delegate retain];
		m_didEndSel = sel;
		m_ctxInfo = contextInfo;
		
		// Force loading of the window
		[self window];
		[self p_layoutWindow];
		
		if (keyFlag) {
			[self showWindow:nil];
		} else {
			[[self window] orderFront:nil];
		}
		
		[NSApp requestUserAttention:NSInformationalRequest];
		[self retain];
	}
}

- (IBAction)firstButtonClicked:(id)sender
{
	m_returnCode = NSAlertFirstButtonReturn;
	[[self window] close];
}

- (IBAction)secondButtonClicked:(id)sender
{
	m_returnCode = NSAlertSecondButtonReturn;
	[[self window] close];
}

- (IBAction)thirdButtonClicked:(id)sender
{
	m_returnCode = NSAlertThirdButtonReturn;
	[[self window] close];
}

- (void)windowWillClose:(NSNotification *)aNotification
{
	if (m_delegate && m_didEndSel && [m_delegate respondsToSelector:m_didEndSel]) {
		NSMethodSignature *ms = [m_delegate methodSignatureForSelector:m_didEndSel];
		NSInvocation *inv = [NSInvocation invocationWithMethodSignature:ms];
		
		[inv setTarget:m_delegate];
		[inv setSelector:m_didEndSel];
		[inv setArgument:&self atIndex:2];
		[inv setArgument:&m_returnCode atIndex:3];
		[inv setArgument:&m_ctxInfo atIndex:4];
		
		[inv invoke];
	}
	
	[m_delegate release];
	m_delegate = nil;
	[self autorelease];
}

@end
