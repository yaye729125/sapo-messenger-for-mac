//
//  LPFileTransfersController.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPFileTransfersController.h"
#import "LPFileTransferRow.h"
#import "LPFileTransfer.h"

#import "LPColorBackgroundView.h"
#import "LPListView.h"


@implementation LPFileTransfersController

- init
{
	if (self = [self initWithWindowNibName:@"FileTransfers"]) {
		m_rowControllers = [[NSMutableArray alloc] init];
	}
	return self;
}


- (void)dealloc
{
	[m_rowControllers release];
	[super dealloc];
}


- (void)windowDidLoad
{
	[self setWindowFrameAutosaveName:@"LPFileTransfersWindow"];
	[[self window] setExcludedFromWindowsMenu:YES];

	[m_bottomBarView setBackgroundColor:[NSColor colorWithDeviceWhite:0.80 alpha:1.0]];
	[m_bottomBarView setBorderColor:[NSColor colorWithDeviceWhite:(2.0/3.0) alpha:1.0]];
	
	[m_listView setDelegate:self];
}


- (void)addFileTransfer:(LPFileTransfer *)transfer
{
	LPFileTransferRow *rowController = [[LPFileTransferRow alloc] init];
	
	[rowController setDelegate:self];
	[rowController setListView:m_listView];
	[rowController setRepresentedFileTransfer:transfer];
	
	[m_rowControllers addObject:rowController];
	[rowController release];
	
	[m_listView addRowView:rowController];
	[m_listView scrollPoint:NSMakePoint(0.0, ([m_listView isFlipped] ? NSMaxY([m_listView bounds]) : 0.0) )];
}


#pragma mark -
#pragma mark LPListView Delegate Methods


- (void)listView:(LPListView *)l didSelect:(BOOL)flag viewAtIndex:(int)subviewIndex
{
//	[[m_rowControllers objectAtIndex:subviewIndex] setSelected:flag];
}


#pragma mark -
#pragma mark LPFileTransferRow Delegate Methods


- (void)fileTransferRowDidCancel:(LPFileTransferRow *)rowController
{
	[m_listView removeRowView:rowController];
	[m_rowControllers removeObject:rowController];
}


@end
