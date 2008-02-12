//
//  LPFileTransfersManager.m
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPFileTransfersManager.h"
#import "LPFileTransfer.h"
#import "LPRoster.h"
#import "LPContactEntry.h"

#import "LFPlatformBridge.h"


static LPFileTransfersManager *s_transfersManager = nil;


@implementation LPFileTransfersManager

+ (LPFileTransfersManager *)fileTransfersManager
{
	if (s_transfersManager == nil) {
		s_transfersManager = [[LPFileTransfersManager alloc] init];
	}
	return s_transfersManager;
}

- init
{
	if (self = [super init]) {
		m_activeFileTransfersByID = [[NSMutableDictionary alloc] init];
		
		[LFPlatformBridge registerNotificationsObserver:self];
	}
	return self;
}

- (void)dealloc
{
	[LFPlatformBridge unregisterNotificationsObserver:self];
	
	[m_activeFileTransfersByID release];
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


#pragma mark -


- (void)p_updateNumberOfIncomingFileTransfersWaitingToBeAccepted
{
	NSPredicate *filterPredicate = [NSPredicate predicateWithFormat:@"type == %d && state == %d",
									LPIncomingTransfer, LPFileTransferWaitingToBeAccepted];
	NSArray *filteredFileTransfers = [[m_activeFileTransfersByID allValues] filteredArrayUsingPredicate:filterPredicate];
	
	int count = [filteredFileTransfers count];
	
	if (count != m_numberOfIncomingFileTransfersWaitingToBeAccepted) {
		[self willChangeValueForKey:@"numberOfIncomingFileTransfersWaitingToBeAccepted"];
		m_numberOfIncomingFileTransfersWaitingToBeAccepted = count;
		[self didChangeValueForKey:@"numberOfIncomingFileTransfersWaitingToBeAccepted"];
	}
}


- (void)p_addFileTransfer:(LPFileTransfer *)transfer
{
	NSAssert(([m_activeFileTransfersByID objectForKey:[NSNumber numberWithInt:[transfer ID]]] == nil),
			 @"There is already a registered file transfer for this ID");
	
	[m_activeFileTransfersByID setObject:transfer forKey:[NSNumber numberWithInt:[transfer ID]]];
	
	if ([transfer type] == LPIncomingTransfer) {
		[self p_updateNumberOfIncomingFileTransfersWaitingToBeAccepted];
		[transfer addObserver:self forKeyPath:@"state" options:0 context:NULL];
	}
}


- (void)p_removeFileTransfer:(LPFileTransfer *)transfer
{
	NSAssert(([m_activeFileTransfersByID objectForKey:[NSNumber numberWithInt:[transfer ID]]] != nil),
			 @"There is no registered file transfer for this ID");
	
	[m_activeFileTransfersByID removeObjectForKey:[NSNumber numberWithInt:[transfer ID]]];
	
	if ([transfer type] == LPIncomingTransfer) {
		[transfer removeObserver:self forKeyPath:@"state"];
		[self p_updateNumberOfIncomingFileTransfersWaitingToBeAccepted];
	}
}


#pragma mark -


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:@"state"]) {
		[self p_updateNumberOfIncomingFileTransfersWaitingToBeAccepted];
	}
	else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}


- (int)numberOfFileTransfers
{
	return [m_activeFileTransfersByID count];
}


- (int)numberOfIncomingFileTransfersWaitingToBeAccepted
{
	return m_numberOfIncomingFileTransfersWaitingToBeAccepted;
}


- (LPFileTransfer *)fileTransferForID:(int)transferID
{
	LPFileTransfer *transfer = [m_activeFileTransfersByID objectForKey:[NSNumber numberWithInt:transferID]];
	NSAssert1((transfer != nil), @"No LPFileTransfer having ID == %d exists", transferID);
	return transfer;
}


- (LPFileTransfer *)startSendingFile:(NSString *)pathname toContactEntry:(LPContactEntry *)contactEntry
{
	LPFileTransfer *newTransfer = [LPFileTransfer outgoingTransferToContactEntry:contactEntry
															  sourceFilePathname:pathname
																	 description:[pathname lastPathComponent]];
	[self p_addFileTransfer:newTransfer];
	
	// Only shoot the delegate method after we already have the file transfer registered under its ID in this manager
	if ([m_delegate respondsToSelector:@selector(fileTransfersManager:willStartOutgoingFileTransfer:)])
		[m_delegate fileTransfersManager:self willStartOutgoingFileTransfer:newTransfer];
	
	return newTransfer;
}


#pragma mark Bridge Notifications


- (void)leapfrogBridge_fileIncoming:(int)fileID
{
	NSDictionary	*properties  = [LFAppController fileGetProps:fileID];
	int				entryID      = [[properties objectForKey:@"entry_id"] intValue];
	NSString		*filename    = [properties objectForKey:@"filename"];
	NSString		*description = [properties objectForKey:@"desc"];
	long long		fileSize     = [[properties objectForKey:@"size"] longLongValue];
	LPContactEntry	*entry		 = [[LPRoster roster] contactEntryForID:entryID];
	
	LPFileTransfer *newTransfer = [LPFileTransfer incomingTransferFromContactEntry:entry
																				ID:fileID
																		  filename:filename
																	   description:description
																			  size:fileSize];
	[self p_addFileTransfer:newTransfer];
	
	if ([m_delegate respondsToSelector:@selector(fileTransfersManager:didReceiveIncomingFileTransfer:)])
		[m_delegate fileTransfersManager:self didReceiveIncomingFileTransfer:newTransfer];
}


// These are only being used by the HTTP POST file transfer
- (void)leapfrogBridge_fileIncomingCreated:(int)fileID :(NSString *)actualPathName
{
	[[self fileTransferForID:fileID] handleLocalFileCreatedWithPathName:actualPathName];
}


// These are only being used by the HTTP POST file transfer
- (void)leapfrogBridge_fileIncomingSize:(int)fileID :(int)actualFileSize
{
	[[self fileTransferForID:fileID] handleReceivedUpdatedFileSize:actualFileSize];
}


- (void)leapfrogBridge_fileAccepted:(int)fileID
{
	[[self fileTransferForID:fileID] handleFileTransferAccepted];
}


- (void)leapfrogBridge_fileProgress:(unsigned long long)fileID :(NSString *)status :(unsigned long long)sent :(unsigned long long)progressAt :(unsigned long long)progressTotal
{
	[[self fileTransferForID:fileID] handleProgressUpdateWithSentBytes:sent
													   currentProgress:progressAt
														 progressTotal:progressTotal];
}


- (void)leapfrogBridge_fileFinished:(int)fileID
{
	[[self fileTransferForID:fileID] handleFileTransferFinished];
}


- (void)leapfrogBridge_fileError:(int)fileID :(NSString *)message
{
	[[self fileTransferForID:fileID] handleFileTransferErrorWithMessage:message];
}


@end
