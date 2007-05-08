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

	[m_bottomBarView setBackgroundColor:[NSColor colorWithDeviceWhite:0.80 alpha:1.0]];
	[m_bottomBarView setBorderColor:[NSColor colorWithDeviceWhite:(2.0/3.0) alpha:1.0]];
	
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


- (void)addFileTransfer:(LPFileTransfer *)transfer
{
	[transfer addObserver:self
			   forKeyPath:@"state"
				  options:( NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld )
				  context:NULL];
	
	
	LPFileTransferRow *rowController = [[LPFileTransferRow alloc] init];
	
	[rowController setDelegate:self];
	[rowController setListView:m_listView];
	[rowController setRepresentedFileTransfer:transfer];
	
	[m_rowControllers addObject:rowController];
	[rowController release];
	
	[m_listView addRowView:rowController];
	[m_listView scrollPoint:NSMakePoint(0.0, ([m_listView isFlipped] ? NSMaxY([m_listView bounds]) : 0.0) )];
	
	
	if ([transfer type] == LPIncomingTransfer) {
		LPEventNotificationsHandler *nh = [LPEventNotificationsHandler defaultHandler];
		[nh notifyReceptionOfFileTransferOfferWithFileName:[transfer filename]
											   fromContact:[[transfer peerContactEntry] contact]];
	}
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
