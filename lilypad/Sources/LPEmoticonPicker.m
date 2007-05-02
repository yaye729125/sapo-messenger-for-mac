//
//  LPEmoticonPicker.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPEmoticonPicker.h"
#import "LPEmoticonMatrix.h"
#import "LPEmoticonSet.h"

// For GetDblTime()
#import <Carbon/Carbon.H>


/* 0.955 is the exact value currently used by Apple as the alpha transparency for menu "windows" (on Mac OS X 10.4, at least) */
#define LPEmoticonPickerMenuWindowAlpha		0.955


@interface LPEmoticonPicker (Private)
- (NSWindow *)p_menuWindow;
- (void)p_showMenuWindowWithTopLeftPoint:(NSPoint)topLeftPoint parentWindow:(NSWindow *)parentWin;
- (void)p_fadeOutMenuWindow;
- (void)p_fadeOutMenuWindowStep:(NSTimer *)timer;
- (void)p_shouldStopRunningMenuWithNotification:(NSNotification *)notif;
@end


@implementation LPEmoticonPicker


- initWithEmoticonSet:(LPEmoticonSet *)emoticonSet
{
	if (self = [super init]) {
		m_emoticonSet = [emoticonSet retain];
	}
	return self;
}


- (void)dealloc
{
	[m_emoticonSet release];
	[m_emoticonView release];
	[m_menuWindow close];
	[m_menuWindow release];
	[super dealloc];
}


- (NSWindow *)p_menuWindow
{
	if (m_menuWindow == nil) {
		[NSBundle loadNibNamed:@"EmoticonPicker" owner:self];
		
		[m_emoticonMatrix loadEmoticonsFromSet:m_emoticonSet];
		
		/* Resize the window so that the entire matrix fits inside it snugly (the matrix is
		resized dynamicaly when it loads the emoticons from the set we gave it) */
		NSRect emoticonViewFrame = [m_emoticonView frame];
		NSRect matrixFrame = [m_emoticonMatrix frame];
		float  margin = matrixFrame.origin.x;
		emoticonViewFrame.size.width  = NSMaxX(matrixFrame) + margin;
		emoticonViewFrame.size.height = NSMaxY(matrixFrame) + margin;
		
		[m_emoticonView setFrame:emoticonViewFrame];
		
		m_menuWindow = [[NSWindow alloc] initWithContentRect:emoticonViewFrame
												   styleMask:NSBorderlessWindowMask
													 backing:NSBackingStoreBuffered
													   defer:NO];
		[m_menuWindow setReleasedWhenClosed:NO];
		[m_menuWindow setHasShadow:YES];
		[m_menuWindow setLevel:NSPopUpMenuWindowLevel];
		
		[[m_menuWindow contentView] addSubview:m_emoticonView];

		[m_emoticonView release];
		m_emoticonView = nil;
	}
	return m_menuWindow;
}


- (void)p_showMenuWindowWithTopLeftPoint:(NSPoint)topLeftPoint parentWindow:(NSWindow *)parentWin
{
	// This forces the window to load if it isn't loaded already
	NSWindow *smileyMenuWindow = [self p_menuWindow];

	[smileyMenuWindow setFrameTopLeftPoint:topLeftPoint];
	
	/* Constrain the window positioning in order to make its entire content area visible and available to the user. This
	also avoids placing the window under the Dock. */
	NSRect screenRect = [[parentWin screen] visibleFrame];
	NSRect windowFrame = [smileyMenuWindow frame];
	
	if (NSContainsRect(screenRect, windowFrame) == NO) {
		float dX = 0.0, dY = 0.0;
		
		if (NSMinX(screenRect) > NSMinX(windowFrame)) {
			dX = NSMinX(screenRect) - NSMinX(windowFrame);
		}
		else if (NSMaxX(screenRect) < NSMaxX(windowFrame)) {
			dX = NSMaxX(screenRect) - NSMaxX(windowFrame);
		}
		
		if (NSMinY(screenRect) > NSMinY(windowFrame)) {
			dY = NSMinY(screenRect) - NSMinY(windowFrame);
		}
		else if (NSMaxY(screenRect) < NSMaxY(windowFrame)) {
			dY = NSMaxY(screenRect) - NSMaxY(windowFrame);
		}
		
		[smileyMenuWindow setFrame:NSOffsetRect(windowFrame, dX, dY) display:NO];
	}
	
	[smileyMenuWindow setAlphaValue:LPEmoticonPickerMenuWindowAlpha];
	[smileyMenuWindow makeKeyAndOrderFront:nil];	
	[smileyMenuWindow makeFirstResponder:m_emoticonMatrix];
}


- (int)pickEmoticonNrUsingTopLeftPoint:(NSPoint)topLeftPoint parentWindow:(NSWindow *)parentWin
{
	// Clear the highlighted cell from the previous run
	[m_emoticonMatrix setHighlightedCell:nil];
	
	[self p_showMenuWindowWithTopLeftPoint:topLeftPoint parentWindow:parentWin];
	[m_menuWindow setAcceptsMouseMovedEvents:YES];
	[m_emoticonMatrix setEnabled:YES];

	// If the application deactivates we would like to stop running the menu automatically
	NSNotificationCenter *notifCenter = [NSNotificationCenter defaultCenter];
	[notifCenter addObserver:self
					selector:@selector(p_shouldStopRunningMenuWithNotification:)
						name:NSApplicationDidResignActiveNotification
					  object:NSApp];
	[notifCenter addObserver:self
					selector:@selector(p_shouldStopRunningMenuWithNotification:)
						name:NSWindowWillMoveNotification
					  object:nil];
	
	m_isRunningEventTrackingLoop = YES;
	m_clickedCellTag = LPEmoticonPickerNoneSelected;
	
	/* If we started with the mouse button still being pressed, then we want to send a mouseUp event when we finish
	this event loop so that any still pressed button that is still doing its own event tracking loop can wrap up
	and redraw itself appropriately and in a clean way. */
	BOOL	startedWithMouseButtonStillDown = ([[NSApp currentEvent] type] == NSLeftMouseDown);
	
	NSEvent *initialEvent = [NSApp currentEvent];
	NSPoint initialMousePosition = [m_menuWindow mouseLocationOutsideOfEventStream];
	NSDate  *initialDate = [NSDate date];
	
	/* We also want AppKit and System defined events so that we also track application activation and deactivation */
	unsigned int eventMask = ( NSLeftMouseDownMask		| NSRightMouseDownMask		| NSOtherMouseDownMask		|
							   NSLeftMouseUpMask		| NSRightMouseUpMask		| NSOtherMouseUpMask		|
							   NSLeftMouseDraggedMask	| NSRightMouseDraggedMask	| NSOtherMouseDraggedMask	|
							   NSMouseMovedMask			| NSAppKitDefinedMask		| NSSystemDefinedMask		);
	NSEvent *theEvent = nil;
	
	// Run the mouse tracking loop
	while ((m_shouldStopRunningMenu == NO) && (theEvent = [m_menuWindow nextEventMatchingMask:eventMask])) {
		switch ([theEvent type]) {
			case NSMouseMoved:
			case NSLeftMouseDragged:
			case NSRightMouseDragged:
			case NSOtherMouseDragged:
				// Let the smiley matrix update the highlighted cell
				[m_emoticonMatrix mouseMoved:theEvent];
				break;
				
			case NSLeftMouseUp:
			case NSRightMouseUp:
			case NSOtherMouseUp:
				if (NSPointInRect([m_menuWindow mouseLocationOutsideOfEventStream],
								  NSInsetRect(NSMakeRect(initialMousePosition.x, initialMousePosition.y, 1.0, 1.0),
											  -5.0, -5.0))
					&& ((-[initialDate timeIntervalSinceNow]) < ((double)GetDblTime() / 60.0)))
				{
					/* Mouse button went up very close to the place where it went down originally and within the time
					interval that defines a double click. This means that this is still the click that originally opened
					the menu, so just consume the event and don't do anything. */
					break;
				}
				else if (NSPointInRect([m_menuWindow mouseLocationOutsideOfEventStream], [m_emoticonMatrix frame])) {
					[m_emoticonMatrix mouseUp:theEvent];
				}
				else if (NSPointInRect([NSEvent mouseLocation], [m_menuWindow frame])) {
					// somewhere else inside the menu window: just ignore it
					break;
				}
				else {
					[self stopRunningMenu];
				}
				break;
				
			case NSLeftMouseDown:
			case NSRightMouseDown:
			case NSOtherMouseDown:
				if (NSPointInRect([NSEvent mouseLocation], [m_menuWindow frame]) == FALSE) {
					[self stopRunningMenu];
				}
				break;
				
			default:
				[NSApp sendEvent:theEvent];
		}
	}

	/* Cleanup whatever happened during the loop from the event queue */
	[NSApp discardEventsMatchingMask:NSAnyEventMask beforeEvent:theEvent];
	
	if (startedWithMouseButtonStillDown) {
		/* If we started with the mouse button still being pressed, then we want to send a mouseUp event when we finish
		this event loop so that any still pressed button that is still doing its own event tracking loop can wrap up
		and redraw itself appropriately and in a clean way. */
		[NSApp postEvent:[NSEvent mouseEventWithType:([initialEvent type] + 1) // Mouse up events have a type code of +1 relative to
																			   // the mouse down event for the same button
											location:[initialEvent locationInWindow]
									   modifierFlags:[initialEvent modifierFlags]
										   timestamp:[theEvent timestamp]
										windowNumber:[initialEvent windowNumber]
											 context:[initialEvent context]
										 eventNumber:[initialEvent eventNumber]
										  clickCount:[initialEvent clickCount]
											pressure:[initialEvent pressure]]
				 atStart:YES];
	}
	
	m_isRunningEventTrackingLoop = NO;
	m_shouldStopRunningMenu = NO;

	[notifCenter removeObserver:self];

	[m_emoticonMatrix setEnabled:NO];
	[m_menuWindow setAcceptsMouseMovedEvents:NO];
	[self p_fadeOutMenuWindow];
	
	return m_clickedCellTag;
}


- (int)pickEmoticonNrUsingTopRightPoint:(NSPoint)topRightPoint parentWindow:(NSWindow *)parentWin
{
	NSSize windowSize = [[self p_menuWindow] frame].size;
	NSPoint topLeftForMenu = NSMakePoint(topRightPoint.x - windowSize.width, topRightPoint.y);
	
	return [self pickEmoticonNrUsingTopLeftPoint:topLeftForMenu parentWindow:parentWin];
}


- (void)stopRunningMenu
{
	m_shouldStopRunningMenu = YES;
}


- (void)p_fadeOutMenuWindow
{
	NSTimer *timer = [NSTimer timerWithTimeInterval:0.02
											 target:self
										   selector:@selector(p_fadeOutMenuWindowStep:)
										   userInfo:nil
											repeats:YES];
	NSRunLoop *runloop = [NSRunLoop currentRunLoop];
	
	/* Run in every mode so that the fade-out doesn't hang if another event-tracking loop is started right away
	by some other control */
	[runloop addTimer:timer forMode:NSDefaultRunLoopMode];
	[runloop addTimer:timer forMode:NSModalPanelRunLoopMode];
	[runloop addTimer:timer forMode:NSEventTrackingRunLoopMode];
}


- (void)p_fadeOutMenuWindowStep:(NSTimer *)timer
{
	float newAlpha = [m_menuWindow alphaValue] - 0.15;
	
	if (newAlpha > 0.0) {
		[m_menuWindow setAlphaValue:newAlpha];
	} else {
		[m_menuWindow close];
		[timer invalidate];
	}
}


- (void)p_shouldStopRunningMenuWithNotification:(NSNotification *)notif
{
	[self stopRunningMenu];
}


#pragma mark * LPEmoticonMatrix Delegate Methods


- (void)emoticonMatrix:(LPEmoticonMatrix *)matrix highlightedCellDidChange:(NSCell *)newlyHighlightedCell
{
	if (newlyHighlightedCell == nil) {
		[m_emoticonCaptionField setStringValue:@""];
		[m_emoticonASCIISequenceField setStringValue:@""];
	}
	else {
		[m_emoticonCaptionField setStringValue:[m_emoticonSet captionForEmoticonNr:[newlyHighlightedCell tag]]];
		[m_emoticonASCIISequenceField setStringValue:[m_emoticonSet defaultASCIISequenceForEmoticonNr:[newlyHighlightedCell tag]]];
	}
}


#pragma mark * LPEmoticonMatrix Delegate Methods


- (IBAction)cellInMatrixWasClicked:(id)sender
{
	[self stopRunningMenu];
	m_clickedCellTag = [[m_emoticonMatrix highlightedCell] tag];
}


@end
