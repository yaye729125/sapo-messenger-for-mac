//
//  LPAccountPrefsListCell.m
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPAccountPrefsListCell.h"
#import "LPAccount.h"


@implementation LPAccountPrefsListCell

- (id)objectValue
{
	return [[m_account retain] autorelease];
}

- (void)setObjectValue:(id)obj
{
	m_account = obj;
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	// ** Calculate the rects where all the components of this cell will be drawn **
	NSRect enabledStatusRect, accountStatusRect, titleRect, auxRect;
	
	NSDivideRect(cellFrame, &enabledStatusRect, &auxRect, 20.0, NSMinXEdge);
	NSDivideRect(auxRect, &accountStatusRect, &titleRect, 20.0, NSMinXEdge);
	
	enabledStatusRect = NSInsetRect(enabledStatusRect, 1.0, 0.0);
	accountStatusRect = NSInsetRect(accountStatusRect, 1.0, 0.0);
	
	titleRect.origin.x += 2.0;
	titleRect.size.width -= 2.0;
	
	// Sub-divide the title rect into two separate areas for writing text (the description and the status)
	NSRect accountDescriptionTextRect, accountStatusTextRect;
	NSDivideRect(titleRect, &accountDescriptionTextRect, &accountStatusTextRect, ([[self font] pointSize] + 5.0), NSMinYEdge);
	
	
	// ** Start drawing stuff **
	id theAccount = [self objectValue];
	
	// Draw the "enabled" checkmark
	if ([theAccount isEnabled]) {
		NSImage *img = [NSImage imageNamed:@"AccountActive"];
		NSSize imgSize = [img size];
		NSPoint	imgTargetPoint = NSMakePoint(NSMidX(enabledStatusRect) - (imgSize.width / 2.0),
											 NSMidY(enabledStatusRect) - (imgSize.height / ([controlView isFlipped] ? (-2.0) : 2.0)));
		
		[img compositeToPoint:imgTargetPoint operation:NSCompositeSourceOver];
	}
	
	
	// Draw the account status icon
	NSImage	*statusImg = LPStatusIconFromStatus([theAccount status]);
	NSSize	statusImgSize = [statusImg size];
	NSPoint	statusImgTargetPoint = NSMakePoint(NSMidX(accountStatusRect) - (statusImgSize.width / 2.0),
											   NSMidY(accountStatusRect) - (statusImgSize.height / ([controlView isFlipped] ? (-2.0) : 2.0)));
	
	[statusImg compositeToPoint:statusImgTargetPoint operation:NSCompositeSourceOver];
	
	
	// Now, let's get to the textual items...
	NSMutableParagraphStyle *paragraphStyle = [[[NSMutableParagraphStyle alloc] init] autorelease];
	[paragraphStyle setLineBreakMode:NSLineBreakByTruncatingTail];
	
	NSWindow *myWin = [controlView window];
	BOOL textInTableShouldBeWhite = ([self isHighlighted] && [myWin firstResponder] == controlView && [myWin isKeyWindow]);
	
	
	// Draw the account description text
	NSString	*description = [theAccount description];
	BOOL		hasDescription = ([description length] > 0);
	NSColor		*accountDescriptionTextColor = ( textInTableShouldBeWhite ?
												 [NSColor whiteColor] : 
												 ( hasDescription ? [self textColor] : [NSColor grayColor]) );
	NSDictionary *attribsForAccountDescription = [NSDictionary dictionaryWithObjectsAndKeys:
		[self font], NSFontAttributeName,
		accountDescriptionTextColor, NSForegroundColorAttributeName,
		paragraphStyle, NSParagraphStyleAttributeName,
		nil];
	
	[(hasDescription ? description : @"<new account>") drawInRect:accountDescriptionTextRect withAttributes:attribsForAccountDescription];
	
	
	// Draw the account status text
	NSString				*status = NSLocalizedStringFromTable(LPStatusStringFromStatus([theAccount status]), @"Status", @"");
	NSColor					*accountStatusTextColor = [NSColor grayColor];
	
	if ([theAccount status] == LPStatusOffline) {
		LPAutoReconnectStatus reconnectStatus = [theAccount automaticReconnectionStatus];
		
		if (reconnectStatus == LPAutoReconnectWaitingForInterfaceToGoUp) {
			status = NSLocalizedString(@"Waiting for Interface", @"");
			accountStatusTextColor = [NSColor colorWithCalibratedRed:1.0 green:0.6 blue:0.6 alpha:1.0];
		}
		else if (reconnectStatus == LPAutoReconnectUsingMultipleRetryAttempts) {
			status = NSLocalizedString(@"Waiting to Retry", @"");
			accountStatusTextColor = [NSColor colorWithCalibratedRed:1.0 green:0.6 blue:0.6 alpha:1.0];
		}
	}
	
	NSColor			*accountStatusTextDisplayColor = ( textInTableShouldBeWhite ? [NSColor whiteColor] : accountStatusTextColor );
	NSDictionary	*attribsForAccountStatus = [NSDictionary dictionaryWithObjectsAndKeys:
		[[NSFontManager sharedFontManager] convertFont:[self font] toSize:([[self font] pointSize] - 2.0)], NSFontAttributeName,
		accountStatusTextDisplayColor, NSForegroundColorAttributeName,
		paragraphStyle, NSParagraphStyleAttributeName,
		nil];
	
	[status drawInRect:accountStatusTextRect withAttributes:attribsForAccountStatus];
}

@end
