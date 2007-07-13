//
//  LPFileTransferRow.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>
#import "LPListViewRow.h"


@class LPFileTransfer;


@interface LPFileTransferRow : LPListViewRow
{
	id					m_delegate;
	LPFileTransfer		*m_fileTransfer;
	
	NSRect				m_fileIconRect;
	NSRect				m_fileNameTextLineRect;
	NSRect				m_otherContactTextLineRect;
	NSRect				m_statusTextLineRect;
	NSRect				m_stopButtonRect;
	NSRect				m_acceptOrRevealButtonRect;
	
	NSImageCell			*m_fileIconCell;
	NSTextFieldCell		*m_fileNameTextLineCell;
	NSTextFieldCell		*m_otherContactTextLineCell;
	NSTextFieldCell		*m_statusTextLineCell;
	NSButtonCell		*m_stopButtonCell;
	NSButtonCell		*m_acceptOrRevealButtonCell;
	
	NSProgressIndicator	*m_progressBar;
	BOOL				m_isProgressBarHidden;
	
	NSCell				*m_trackingCell;
}

- (id)delegate;
- (void)setDelegate:(id)delegate;
- (LPFileTransfer *)representedFileTransfer;
- (void)setRepresentedFileTransfer:(LPFileTransfer *)fileTransfer;

- (NSRect)rectOfFileIcon;
- (NSRect)rectOfFileNameTextLine;
- (NSRect)rectOfOtherContactTextLine;
- (NSRect)rectOfStatusTextLine;
- (NSRect)rectOfStopButton;
- (NSRect)rectOfAcceptOrRevealButton;

- (IBAction)stop:(id)sender;
- (IBAction)acceptOrReveal:(id)sender;
- (IBAction)performStop:(id)sender;

@end
