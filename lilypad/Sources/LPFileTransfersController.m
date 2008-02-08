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
#import "LPContact.h"
#import "LPContactEntry.h"

#import "LPEventNotificationsHandler.h"

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
	// Stop observing all the file transfers
	NSEnumerator *ftEnum = [m_rowControllers objectEnumerator];
	LPFileTransferRow *ftRow;
	while (ftRow = [ftEnum nextObject]) {
		[[ftRow representedFileTransfer] removeObserver:self forKeyPath:@"state"];
	}
	
	[m_rowControllers release];
	[super dealloc];
}


- (void)windowDidLoad
{
	[self setWindowFrameAutosaveName:@"LPFileTransfersWindow"];
	[[self window] setExcludedFromWindowsMenu:YES];
	
	[m_listView setDelegate:self];
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:@"state"]) {
		
		LPFileTransferState newState = [[change valueForKey:NSKeyValueChangeNewKey] intValue];
		LPFileTransferState oldState = [[change valueForKey:NSKeyValueChangeOldKey] intValue];
		
		LPFileTransferType transferType = [(LPFileTransfer *)object type];
		
		// Emit notifications if needed
		if (newState == LPFileTransferCompleted) {
			LPEventNotificationsHandler *nh = [LPEventNotificationsHandler defaultHandler];
			[nh notifyCompletionOfFileTransferWithFileName:[object filename]
											   withContact:[[object peerContactEntry] contact]];
		}
		else if (newState == LPFileTransferRunning && oldState == LPFileTransferWaitingToBeAccepted
				 && transferType == LPOutgoingTransfer) {
			// It was accepted
			LPEventNotificationsHandler *nh = [LPEventNotificationsHandler defaultHandler];
			[nh notifyAcceptanceOfFileTransferWithFileName:[object filename]
											   fromContact:[[object peerContactEntry] contact]];
		}
		else if ((newState == LPFileTransferWasNotAccepted && transferType == LPOutgoingTransfer)
				 || newState == LPFileTransferAbortedWithError) {
			LPEventNotificationsHandler *nh = [LPEventNotificationsHandler defaultHandler];
			[nh notifyFailureOfFileTransferWithFileName:[object filename]
											fromContact:[[object peerContactEntry] contact]
									   withErrorMessage:[object lastErrorMessage]];
		}
	}
	else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}


- (void)p_addRowView:(LPFileTransferRow *)rowController
{
	[self willChangeValueForKey:@"numberOfTransfers"];
	[m_rowControllers addObject:rowController];
	[self didChangeValueForKey:@"numberOfTransfers"];
	
	[m_listView addRowView:rowController];
	[m_listView scrollPoint:NSMakePoint(0.0, ([m_listView isFlipped] ? NSMaxY([m_listView bounds]) : 0.0) )];
	
	[[rowController representedFileTransfer] addObserver:self
											  forKeyPath:@"state"
												 options:( NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld )
												 context:NULL];
}


- (void)p_removeRowView:(LPFileTransferRow *)rowController
{
	// Sanity check: only allow the removal of transfers that are not currently active
	LPFileTransferState transferState = [[rowController representedFileTransfer] state];
	
	if (transferState == LPFileTransferWasNotAccepted ||
		transferState == LPFileTransferAbortedWithError ||
		transferState == LPFileTransferCancelled ||
		transferState == LPFileTransferCompleted)
	{
		[[rowController representedFileTransfer] removeObserver:self forKeyPath:@"state"];
		[m_listView removeRowView:rowController];
		
		[self willChangeValueForKey:@"numberOfTransfers"];
		[m_rowControllers removeObject:rowController];
		[self didChangeValueForKey:@"numberOfTransfers"];
	}
}


- (void)addFileTransfer:(LPFileTransfer *)transfer
{
	LPFileTransferRow *rowController = [[LPFileTransferRow alloc] init];
	
	[rowController setDelegate:self];
	[rowController setListView:m_listView];
	[rowController setRepresentedFileTransfer:transfer];
	
	[self p_addRowView:rowController];
	[rowController release];
	
	
	if ([transfer type] == LPIncomingTransfer) {
		LPEventNotificationsHandler *nh = [LPEventNotificationsHandler defaultHandler];
		[nh notifyReceptionOfFileTransferOfferWithFileName:[transfer filename]
											   fromContact:[[transfer peerContactEntry] contact]];
	}
}


- (unsigned int)numberOfTransfers
{
	return [m_rowControllers count];
}


- (IBAction)clearFileTransfers:(id)sender
{
	// Iterate on an immutable copy because we will be removing elements from this very same array.
	NSEnumerator *rowCtrlEnum = [[[m_rowControllers copy] autorelease] objectEnumerator];
	LPFileTransferRow *rowController;
	
	while (rowController = [rowCtrlEnum nextObject]) {
		[self p_removeRowView:rowController];
	}
}


#pragma mark -
#pragma mark LPListView Delegate Methods


- (void)listView:(LPListView *)l didSelect:(BOOL)flag viewAtIndex:(int)subviewIndex
{
//	[[m_rowControllers objectAtIndex:subviewIndex] setSelected:flag];
}


- (void)listView:(LPListView *)lv removeRowView:(LPListViewRow *)rowView
{
	[self p_removeRowView:(LPFileTransferRow *)rowView];
}


@end
