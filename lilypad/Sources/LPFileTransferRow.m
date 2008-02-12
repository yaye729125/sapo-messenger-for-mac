//
//  LPFileTransferRow.m
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPFileTransferRow.h"
#import "LPFileTransfer.h"
#import "LPContactEntry.h"
#import "LPListView.h"


#pragma mark Some useful NSString additions

@interface NSString (HumanReadableFileSizesAdditions)
+ (NSString *)humanReadableNumericStringWithFileSize:(unsigned long long)fileSize unitName:(NSString **)outUnitName;
+ (NSString *)humanReadableStringWithFileSize:(unsigned long long)fileSize;
+ (NSString *)humanReadableStringWithCurrentSize:(unsigned long long)currentSize ofTotalSize:(unsigned long long)totalSize;
@end

@implementation NSString (HumanReadableFileSizesAdditions)

+ (NSString *)humanReadableNumericStringWithFileSize:(unsigned long long)fileSize  unitName:(NSString **)outUnitName
{
	unsigned long long oneKB = (1ull << 10);
	unsigned long long oneMB = (1ull << 20);
	unsigned long long oneGB = (1ull << 30);
	unsigned long long oneTB = (1ull << 40);
	
	if (fileSize < oneMB) {
		if (outUnitName)
			*outUnitName = NSLocalizedString(@"KB", @"kilobytes unit name");
		return [NSString localizedStringWithFormat:@"%.1f", ((double)fileSize / (double)oneKB)];
	}
	else if (fileSize < oneGB) {
		if (outUnitName)
			*outUnitName = NSLocalizedString(@"MB", @"megabytes unit name");
		return [NSString localizedStringWithFormat:@"%.1f", ((double)fileSize / (double)oneMB)];
	}
	else if (fileSize < oneTB) {
		if (outUnitName)
			*outUnitName = NSLocalizedString(@"GB", @"gigabytes unit name");
		return [NSString localizedStringWithFormat:@"%.1f", ((double)fileSize / (double)oneGB)];
	}
	else {
		if (outUnitName)
			*outUnitName = NSLocalizedString(@"TB", @"terabytes unit name");
		return [NSString localizedStringWithFormat:@"%.1f", ((double)fileSize / (double)oneTB)];
	}
}

+ (NSString *)humanReadableStringWithFileSize:(unsigned long long)fileSize
{
	NSString *unitStr;
	NSString *numStr = [NSString humanReadableNumericStringWithFileSize:fileSize unitName:&unitStr];
	return [NSString stringWithFormat:@"%@ %@", numStr, unitStr];
}

+ (NSString *)humanReadableStringWithCurrentSize:(unsigned long long)currentSize ofTotalSize:(unsigned long long)totalSize
{
	NSString *currentSizeNumStr, *totalSizeNumStr;
	NSString *currentSizeUnitStr, *totalSizeUnitStr;
	
	currentSizeNumStr = [NSString humanReadableNumericStringWithFileSize:currentSize unitName:&currentSizeUnitStr];
	totalSizeNumStr = [NSString humanReadableNumericStringWithFileSize:totalSize unitName:&totalSizeUnitStr];
	
	if ([currentSizeUnitStr isEqualToString:totalSizeUnitStr])
		return [NSString stringWithFormat:@"%@ %@ %@ %@",
			currentSizeNumStr,
			NSLocalizedString(@"of", @"in file transfers, as in \"X of Y bytes transferred\""),
			totalSizeNumStr, totalSizeUnitStr];
	else
		return [NSString stringWithFormat:@"%@ %@ %@ %@ %@",
			currentSizeNumStr, currentSizeUnitStr,
			NSLocalizedString(@"of", @"in file transfers, as in \"X of Y bytes transferred\""),
			totalSizeNumStr, totalSizeUnitStr];
}

@end


#pragma mark -


#define LPFileTransferRowHeightWithProgressBar		70.0
#define LPFileTransferRowHeightWithoutProgressBar	55.0


@interface LPFileTransferRow (Private)
- (void)p_updateCellRects;
- (void)p_updateTextCellsColors;
- (BOOL)p_isProgressBarHidden;
- (void)p_setProgressBarHidden:(BOOL)flag;
- (void)p_updateStatusTextCellValue;
- (void)p_updateAcceptOrRevealButton;
- (BOOL)p_shouldShowAcceptButton;
- (void)p_showAcceptButton;
- (void)p_showRevealButton;
@end


@implementation LPFileTransferRow

- initWithFrame:(NSRect)frame
{
	frame.size.height = 40.0;
	
	if (self = [super initWithFrame:frame]) {
		m_fileIconCell = [[NSImageCell alloc] initImageCell:[NSImage imageNamed:@"NSApplicationIcon"]];
		
		m_fileNameTextLineCell = [[NSTextFieldCell alloc] initTextCell:@""];
		[m_fileNameTextLineCell setFont:
			[NSFont systemFontOfSize:[NSFont systemFontSizeForControlSize:NSSmallControlSize]]];
		[m_fileNameTextLineCell setLineBreakMode:NSLineBreakByTruncatingMiddle];
		
		m_otherContactTextLineCell = [[NSTextFieldCell alloc] initTextCell:@""];
		[m_otherContactTextLineCell setFont:
			[NSFont systemFontOfSize:[NSFont systemFontSizeForControlSize:NSMiniControlSize]]];
		[m_otherContactTextLineCell setLineBreakMode:NSLineBreakByTruncatingMiddle];

		m_statusTextLineCell = [[NSTextFieldCell alloc] initTextCell:@""];
		[m_statusTextLineCell setFont:
			[NSFont systemFontOfSize:[NSFont systemFontSizeForControlSize:NSMiniControlSize]]];
		[m_statusTextLineCell setLineBreakMode:NSLineBreakByTruncatingMiddle];
		
		m_stopButtonCell = [[NSButtonCell alloc] initImageCell:[NSImage imageNamed:@"TransferStop"]];
		[m_stopButtonCell setAlternateImage:[NSImage imageNamed:@"TransferStopPressed"]];
		[m_stopButtonCell setBezeled:NO];
		[m_stopButtonCell setBordered:NO];
		[m_stopButtonCell setButtonType:NSMomentaryChangeButton];
		[m_stopButtonCell setImagePosition:NSImageOnly];

		[m_stopButtonCell setTarget:self];
		[m_stopButtonCell setAction:@selector(stop:)];

		m_acceptOrRevealButtonCell = [[NSButtonCell alloc] initImageCell:[NSImage imageNamed:@"TransferReveal"]];
		[m_acceptOrRevealButtonCell setAlternateImage:[NSImage imageNamed:@"TransferRevealPressed"]];
		[m_acceptOrRevealButtonCell setBezeled:NO];
		[m_acceptOrRevealButtonCell setBordered:NO];
		[m_acceptOrRevealButtonCell setButtonType:NSMomentaryChangeButton];
		[m_acceptOrRevealButtonCell setImagePosition:NSImageOnly];
		
		[m_acceptOrRevealButtonCell setTarget:self];
		[m_acceptOrRevealButtonCell setAction:@selector(acceptOrReveal:)];
		[m_acceptOrRevealButtonCell setEnabled:NO];
		
		// The correct frame will be set in -p_updateCellRects
		m_progressBar = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(0.0, 0.0, 10.0, 10.0)];
		[m_progressBar setUsesThreadedAnimation:YES];
		[m_progressBar setControlSize:NSSmallControlSize];
		[m_progressBar setStyle:NSProgressIndicatorBarStyle];
		[m_progressBar setIndeterminate:YES];
		[m_progressBar sizeToFit];
		[self addSubview:m_progressBar];
		[self p_setProgressBarHidden:NO];
		
		[self p_updateCellRects];
		[self p_updateTextCellsColors];
	}
	return self;
}


- (void)dealloc
{
	[self setRepresentedFileTransfer:nil];
	
	[m_fileIconCell release];
	[m_fileNameTextLineCell release];
	[m_otherContactTextLineCell release];
	[m_statusTextLineCell release];
	[m_stopButtonCell release];
	[m_acceptOrRevealButtonCell release];
	[m_progressBar release];
	
	[super dealloc];
}


- (id)delegate
{
	return m_delegate;
}


- (void)setDelegate:(id)delegate
{
	m_delegate = delegate;
}


- (LPFileTransfer *)representedFileTransfer
{
	return m_fileTransfer;
}


- (void)setRepresentedFileTransfer:(LPFileTransfer *)fileTransfer
{
	if (fileTransfer != m_fileTransfer) {
		[m_fileTransfer removeObserver:self forKeyPath:@"state"];
		[m_fileTransfer removeObserver:self forKeyPath:@"localFilePath"];
		[m_fileTransfer removeObserver:self forKeyPath:@"localFileExists"];
		[m_fileTransfer removeObserver:self forKeyPath:@"fileSize"];
		[m_fileTransfer removeObserver:self forKeyPath:@"currentFileOffset"];
		[m_fileTransfer removeObserver:self forKeyPath:@"transferSpeedBytesPerSecond"];
		
		[m_fileTransfer release];
		m_fileTransfer = [fileTransfer retain];
		
		if (m_fileTransfer != nil) {
			[m_fileTransfer addObserver:self forKeyPath:@"state" options:0 context:NULL];
			[m_fileTransfer addObserver:self forKeyPath:@"localFilePath" options:0 context:NULL];
			[m_fileTransfer addObserver:self forKeyPath:@"localFileExists" options:0 context:NULL];
			[m_fileTransfer addObserver:self forKeyPath:@"fileSize" options:0 context:NULL];
			[m_fileTransfer addObserver:self forKeyPath:@"currentFileOffset" options:0 context:NULL];
			[m_fileTransfer addObserver:self forKeyPath:@"transferSpeedBytesPerSecond" options:0 context:NULL];
			
			
			// Set up the text cells
			LPContactEntry *peerContactEntry = [fileTransfer peerContactEntry];
			
			[m_fileNameTextLineCell setStringValue:[fileTransfer filename]];
			[m_otherContactTextLineCell setStringValue:
				[NSString stringWithFormat:([fileTransfer type] == LPIncomingTransfer ?
											NSLocalizedString(@"Received from: %@ (%@)", @"in file transfers, contact name (address)") :
											NSLocalizedString(@"Sent to: %@ (%@)", @"in file transfers, contact name (address)")),
					[[peerContactEntry contact] name],
					[peerContactEntry humanReadableAddress]]];
			[self p_updateStatusTextCellValue];
			
			// Set up the icon cell
			NSWorkspace *ws = [NSWorkspace sharedWorkspace];
			
			if ([fileTransfer localFileExists]) {
				// Get the local (possibly customized) icon for the specific file being sent
				[m_fileIconCell setImage:[ws iconForFile:[fileTransfer localFilePath]]];
			} else {
				// Simply get the generic icon for this file type
				[m_fileIconCell setImage:[ws iconForFileType:[[fileTransfer localFilePath] pathExtension]]];
			}
		}
		
		[self p_updateAcceptOrRevealButton];
		[self setNeedsDisplay:YES];
	}
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:@"state"]) {
		switch ([object state]) {
			case LPFileTransferPackaging:
			case LPFileTransferWaitingToBeAccepted:
				[m_progressBar setIndeterminate:YES];
				break;
			case LPFileTransferRunning:
				[m_progressBar setIndeterminate:NO];
				break;
			case LPFileTransferWasNotAccepted:
			case LPFileTransferAbortedWithError:
			case LPFileTransferCancelled:
			case LPFileTransferCompleted:
				[self p_setProgressBarHidden:YES];
				break;
		}
		[self p_updateStatusTextCellValue];
		[self p_updateAcceptOrRevealButton];
	}
	else if ([keyPath isEqualToString:@"localFilePath"]) {
		[m_fileNameTextLineCell setStringValue:[object filename]];
		[self setNeedsDisplay:YES];
	}
	else if ([keyPath isEqualToString:@"localFileExists"]) {
		[self p_updateAcceptOrRevealButton];
	}
	else if ([keyPath isEqualToString:@"currentFileOffset"]
			 || [keyPath isEqualToString:@"fileSize"]
			 || [keyPath isEqualToString:@"transferSpeedBytesPerSecond"]) {
		[m_progressBar setDoubleValue:(((double)[object currentFileOffset] / (double)[object fileSize]) * 100.0)];
		[self p_updateStatusTextCellValue];
	}
	else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}


- (void)setFrame:(NSRect)frameRect
{
	[super setFrame:frameRect];
	[self p_updateCellRects];
}


- (NSRect)rectOfFileIcon
{
	return m_fileIconRect;
}

- (NSRect)rectOfFileNameTextLine
{
	return m_fileNameTextLineRect;
}

- (NSRect)rectOfOtherContactTextLine
{
	return m_otherContactTextLineRect;
}

- (NSRect)rectOfStatusTextLine
{
	return m_statusTextLineRect;
}

- (NSRect)rectOfStopButton
{
	return m_stopButtonRect;
}

- (NSRect)rectOfAcceptOrRevealButton
{
	return m_acceptOrRevealButtonRect;
}


- (void)setHighlighted:(BOOL)flag
{
	[super setHighlighted:flag];
	[self p_updateTextCellsColors];
}


- (void)setShowsFirstResponder:(BOOL)flag
{
	[super setShowsFirstResponder:flag];
	[self p_updateTextCellsColors];
}


- (void)drawRect:(NSRect)rect
{
	[super drawRect:rect];
	
	// DEBUG
//	[[NSColor greenColor] set];
//	NSFrameRect(m_fileIconRect);
//	[[NSColor orangeColor] set];
//	NSFrameRect(m_fileNameTextLineRect);
//	[[NSColor blueColor] set];
//	NSFrameRect(m_otherContactTextLineRect);
//	[[NSColor grayColor] set];
//	NSFrameRect(m_statusTextLineRect);
//	[[NSColor redColor] set];
//	NSFrameRect(m_stopButtonRect);
//	[[NSColor cyanColor] set];
//	NSFrameRect(m_acceptOrRevealButtonRect);
	
	[m_fileIconCell				drawWithFrame:[self rectOfFileIcon]				inView:self];
	[m_fileNameTextLineCell		drawWithFrame:[self rectOfFileNameTextLine]		inView:self];
	[m_otherContactTextLineCell drawWithFrame:[self rectOfOtherContactTextLine]	inView:self];
	[m_statusTextLineCell		drawWithFrame:[self rectOfStatusTextLine]		inView:self];
	[m_acceptOrRevealButtonCell	drawWithFrame:[self rectOfAcceptOrRevealButton]	inView:self];
	
	if ([self p_isProgressBarHidden] == NO)
		[m_stopButtonCell		drawWithFrame:[self rectOfStopButton]			inView:self];
	
	// Draw the success/error badge as needed
	NSImage *badge = nil;
	
	if ([[self representedFileTransfer] state] == LPFileTransferAbortedWithError)
		badge = [NSImage imageNamed:@"ErrorBadge"];
	else if ([[self representedFileTransfer] state] == LPFileTransferCompleted)
		badge = [NSImage imageNamed:@"SuccessBadge"];
	
	if (badge) {
		[badge compositeToPoint:NSMakePoint(NSMinX(m_fileIconRect) - 2.0, NSMinY(m_fileIconRect) - 2.0)
					  operation:NSCompositeSourceOver];
	}
}


- (void)mouseDown:(NSEvent *)theEvent
{
	NSPoint mouseLocation = [self convertPoint:[theEvent locationInWindow] fromView:nil];
	
	if ([self mouse:mouseLocation inRect:m_acceptOrRevealButtonRect]) {
		m_trackingCell = m_acceptOrRevealButtonCell;
		
		[m_acceptOrRevealButtonCell highlight:YES withFrame:m_acceptOrRevealButtonRect inView:self];
		[m_acceptOrRevealButtonCell trackMouse:theEvent inRect:m_acceptOrRevealButtonRect ofView:self untilMouseUp:NO];
		[m_acceptOrRevealButtonCell highlight:NO withFrame:m_acceptOrRevealButtonRect inView:self];
	}
	else if ([self mouse:mouseLocation inRect:m_stopButtonRect] && ([self p_isProgressBarHidden] == NO)) {
		m_trackingCell = m_stopButtonCell;
		
		[m_stopButtonCell highlight:YES withFrame:m_stopButtonRect inView:self];
		[m_stopButtonCell trackMouse:theEvent inRect:m_stopButtonRect ofView:self untilMouseUp:NO];
		[m_stopButtonCell highlight:NO withFrame:m_stopButtonRect inView:self];
	}
	else {
		m_trackingCell = nil;
		
		if ([theEvent clickCount] == 2) {
			LPFileTransfer *fileTransfer = [self representedFileTransfer];

			if ([self mouse:mouseLocation inRect:m_fileIconRect] && [fileTransfer localFileExists]) {
				if ([[NSWorkspace sharedWorkspace] openFile:[fileTransfer localFilePath]] == NO) {
					// Failed to open
					NSBeginAlertSheet(NSLocalizedString(@"Can't find the file.", @"\"open file\" button in the file transfers window"),
									  NSLocalizedString(@"OK", @""), nil, nil,
									  [self window], nil, NULL, NULL, NULL,
									  [NSString stringWithFormat:NSLocalizedString(@"Can't open the file \"%@\" because it moved since you transferred it.", @"\"open file\" button in the file transfers window"), [fileTransfer filename]]);
				}
			}
		}
		else {
			[super mouseDown:theEvent];
		}
	}
}


- (void)mouseDragged:(NSEvent *)theEvent
{
	NSPoint mouseLocation = [self convertPoint:[theEvent locationInWindow] fromView:nil];
	
	if ((m_trackingCell == m_acceptOrRevealButtonCell) && [self mouse:mouseLocation inRect:m_acceptOrRevealButtonRect]) {
		[m_acceptOrRevealButtonCell highlight:YES withFrame:m_acceptOrRevealButtonRect inView:self];
		[m_acceptOrRevealButtonCell trackMouse:theEvent inRect:m_acceptOrRevealButtonRect ofView:self untilMouseUp:NO];
		[m_acceptOrRevealButtonCell highlight:NO withFrame:m_acceptOrRevealButtonRect inView:self];
	}
	else if ((m_trackingCell == m_stopButtonCell) && [self mouse:mouseLocation inRect:m_stopButtonRect]
			 && ([self p_isProgressBarHidden] == NO)) {
		[m_stopButtonCell highlight:YES withFrame:m_stopButtonRect inView:self];
		[m_stopButtonCell trackMouse:theEvent inRect:m_stopButtonRect ofView:self untilMouseUp:NO];
		[m_stopButtonCell highlight:NO withFrame:m_stopButtonRect inView:self];
	}
	else {
		[super mouseDragged:theEvent];
	}
}


- (IBAction)stop:(id)sender
{
	[[self representedFileTransfer] cancel];
}


- (IBAction)acceptOrReveal:(id)sender
{
	if ([self p_shouldShowAcceptButton]) {
		[[self representedFileTransfer] acceptIncomingFileTransfer:YES];
	}
	else {
		[[NSWorkspace sharedWorkspace] selectFile:[[self representedFileTransfer] localFilePath]
						 inFileViewerRootedAtPath:@""];
	}
}


- (IBAction)performStop:(id)sender
{
	[m_stopButtonCell performClick:self];
}


#pragma mark -
#pragma mark Private Methods


#define LPFileTransferRow_IconSize	32.0

- (void)p_updateCellRects
{
	[self removeAllToolTips];
	
	NSRect myBounds = [self bounds];
	float boundsMaxY = NSMaxY(myBounds);
	
	m_fileIconRect = NSMakeRect(NSMinX(myBounds) + 10.0,
								NSMidY(myBounds) - LPFileTransferRow_IconSize / 2.0,
								LPFileTransferRow_IconSize,
								LPFileTransferRow_IconSize);
	[self addToolTipRect:m_fileIconRect owner:self userData:&m_fileIconRect];
	
	NSSize revealButtonSize = [m_acceptOrRevealButtonCell cellSize];
	
	m_acceptOrRevealButtonRect = NSMakeRect(NSMaxX(myBounds) - 10.0 - revealButtonSize.width,
											NSMidY(myBounds) - revealButtonSize.height / 2.0,
											revealButtonSize.width,
											revealButtonSize.height);
	
	m_stopButtonRect = m_acceptOrRevealButtonRect;
	
	if ([self p_isProgressBarHidden] == NO) {
		m_stopButtonRect.origin.x -= (revealButtonSize.width + 6);
		m_stopButtonRect.origin.y = m_acceptOrRevealButtonRect.origin.y = (boundsMaxY - 50.0);
		[self addToolTipRect:m_stopButtonRect owner:self userData:&m_stopButtonRect];
	}
	[self addToolTipRect:m_acceptOrRevealButtonRect owner:self userData:&m_acceptOrRevealButtonRect];
	
	float middleCellsMinX = NSMaxX(m_fileIconRect) + 10.0;
	float middleCellsWidth = NSMinX(m_stopButtonRect) - middleCellsMinX - 8.0;
	
	float fileNameTextLineHeight = [m_fileNameTextLineCell cellSize].height;
	m_fileNameTextLineRect = NSMakeRect(middleCellsMinX,
										boundsMaxY - 20.0,
										middleCellsWidth,
										fileNameTextLineHeight);
	
	float otherContactTextLineHeight = [m_otherContactTextLineCell cellSize].height;
	m_otherContactTextLineRect = NSMakeRect(middleCellsMinX,
											boundsMaxY - 34.0,
											middleCellsWidth,
											otherContactTextLineHeight);

	NSRect progressBarFrame = [m_progressBar frame];
	[m_progressBar setFrame:NSMakeRect(middleCellsMinX,
									   boundsMaxY - 50.0,
									   middleCellsWidth,
									   NSHeight(progressBarFrame))];
	
	float statusLineHeight = [m_statusTextLineCell cellSize].height;
	m_statusTextLineRect = NSMakeRect(middleCellsMinX,
									  NSMinY(myBounds) + 6.0,
									  middleCellsWidth,
									  statusLineHeight);
	
	[self setNeedsDisplay:YES];
}


- (NSString *)view:(NSView *)view stringForToolTip:(NSToolTipTag)tag point:(NSPoint)point userData:(void *)userData
{
	NSString *res = @"";
	
	if (userData == &m_fileIconRect && [m_fileTransfer localFileExists]) {
		res = NSLocalizedString(@"Double-click to open", @"tooltip for the file transfers window");
	}
	else if (userData == &m_acceptOrRevealButtonRect) {
		if ([m_fileTransfer state] == LPFileTransferWaitingToBeAccepted && [m_fileTransfer type] == LPIncomingTransfer) {
			res = NSLocalizedString(@"Accept", @"tooltip for the file transfers window");
		}
		else if ([m_fileTransfer localFileExists]) {
			res = NSLocalizedString(@"Show in Finder", @"tooltip for the file transfers window");
		}
	}
	else if (userData == &m_stopButtonRect) {
		res = NSLocalizedString(@"Stop", @"tooltip for the file transfers window");
	}
	
	return res;
}


- (void)p_updateTextCellsColors
{
	if ([self isHighlighted] && [self showsFirstResponder]) {
		[m_fileNameTextLineCell setTextColor:[NSColor whiteColor]];
		[m_otherContactTextLineCell setTextColor:[NSColor whiteColor]];
		[m_statusTextLineCell setTextColor:[NSColor whiteColor]];
	}
	else {
		[m_fileNameTextLineCell setTextColor:[NSColor blackColor]];
		[m_otherContactTextLineCell setTextColor:[NSColor grayColor]];
		[m_statusTextLineCell setTextColor:[NSColor grayColor]];
	}
	[self setNeedsDisplay:YES];
}


- (BOOL)p_isProgressBarHidden
{
	return m_isProgressBarHidden;
}


- (void)p_setProgressBarHidden:(BOOL)flag
{
	m_isProgressBarHidden = flag;
	[m_progressBar setHidden:flag];
	
	if (flag) {
		[m_progressBar stopAnimation:nil];
		[self setHeight:LPFileTransferRowHeightWithoutProgressBar];
	} else {
		[m_progressBar startAnimation:nil];
		[self setHeight:LPFileTransferRowHeightWithProgressBar];
	}
	
	[self p_updateCellRects];
	[self setNeedsDisplay:YES];
}


- (void)p_updateStatusTextCellValue
{
	NSString *value = nil;
	LPFileTransfer *transfer = [self representedFileTransfer];
	
	switch ([transfer state]) {
		
		case LPFileTransferPackaging:
			value = ( [transfer type] == LPIncomingTransfer ?
					  NSLocalizedString(@"Unpackaging the received file", @"file transfers window - status label") :
					  NSLocalizedString(@"Packaging the files", @"file transfers window - status label") );
			break;
			
		case LPFileTransferWaitingToBeAccepted:
			value = [NSString stringWithFormat:
				( [transfer type] == LPIncomingTransfer ?
				  NSLocalizedString(@"%@ - Do you want to receive the file?", @"file transfers window - status label") :
				  NSLocalizedString(@"%@ - Waiting for acceptance", @"file transfers window - status label") ),
				[NSString humanReadableStringWithFileSize:[transfer fileSize]]];
			break;
			
		case LPFileTransferWasNotAccepted:
			value = [NSString stringWithFormat:NSLocalizedString(@"%@ - Rejected!", @"file transfers window - status label"),
				[NSString humanReadableStringWithFileSize:[transfer fileSize]]];
			break;
			
		case LPFileTransferRunning:
		{
			unsigned long long transferSpeed = [transfer transferSpeedBytesPerSecond];
			
			if (transferSpeed > 0) {
				value = [NSString stringWithFormat:NSLocalizedString(@"%@ (%@/s)", @"file transfer speed, just translate the \"/s\""),
					[NSString humanReadableStringWithCurrentSize:[transfer currentFileOffset]
													 ofTotalSize:[transfer fileSize]],
					[NSString humanReadableStringWithFileSize:transferSpeed]];
			} else {
				value = [NSString humanReadableStringWithCurrentSize:[transfer currentFileOffset]
														 ofTotalSize:[transfer fileSize]];
			}
			break;
		}
			
		case LPFileTransferAbortedWithError:
			value = [NSString stringWithFormat:NSLocalizedString(@"%@ - Error: %@", @"file transfer window - status label"),
				[NSString humanReadableStringWithCurrentSize:[transfer currentFileOffset]
												 ofTotalSize:[transfer fileSize]],
				[transfer lastErrorMessage]];
			break;
			
		case LPFileTransferCancelled:
			value = [NSString stringWithFormat:NSLocalizedString(@"%@ - Cancelled", @"file transfer window - status label"),
				[NSString humanReadableStringWithCurrentSize:[transfer currentFileOffset]
												 ofTotalSize:[transfer fileSize]]];
			break;
			
		case LPFileTransferCompleted:
			value = [NSString humanReadableStringWithFileSize:[transfer fileSize]];
			break;
			
		default:
			break;
	}
	
	[m_statusTextLineCell setStringValue:value];
	[self setNeedsDisplay:YES];
}


- (void)p_updateAcceptOrRevealButton
{
	if ([self p_shouldShowAcceptButton])
		[self p_showAcceptButton];
	else
		[self p_showRevealButton];
	
	[self setNeedsDisplay:YES];
}

- (BOOL)p_shouldShowAcceptButton
{
	return ([m_fileTransfer type] == LPIncomingTransfer &&
			[m_fileTransfer state] == LPFileTransferWaitingToBeAccepted);
}


- (void)p_showAcceptButton
{
	[m_acceptOrRevealButtonCell setEnabled:YES];
	[m_acceptOrRevealButtonCell setImage:[NSImage imageNamed:@"TransferAccept"]];
	[m_acceptOrRevealButtonCell setAlternateImage:[NSImage imageNamed:@"TransferAcceptPressed"]];
}


- (void)p_showRevealButton
{
	[m_acceptOrRevealButtonCell setEnabled:[m_fileTransfer localFileExists]];
	[m_acceptOrRevealButtonCell setImage:[NSImage imageNamed:@"TransferReveal"]];
	[m_acceptOrRevealButtonCell setAlternateImage:[NSImage imageNamed:@"TransferRevealPressed"]];
}


@end
