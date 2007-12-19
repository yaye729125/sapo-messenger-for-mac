//
//  LPFileTransfersManager.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


@class LPFileTransfer, LPContactEntry;


@interface LPFileTransfersManager : NSObject
{
	id						m_delegate;
	NSMutableDictionary		*m_activeFileTransfersByID;		// NSNumber with the file transfer ID --> LPFileTransfer
	
	int						m_numberOfIncomingFileTransfersWaitingToBeAccepted;
}

+ (LPFileTransfersManager *)fileTransfersManager;

- (id)delegate;
- (void)setDelegate:(id)delegate;

- (int)numberOfFileTransfers;
- (int)numberOfIncomingFileTransfersWaitingToBeAccepted;

- (LPFileTransfer *)fileTransferForID:(int)transferID;
- (LPFileTransfer *)startSendingFile:(NSString *)pathname toContactEntry:(LPContactEntry *)contactEntry;

@end


@interface NSObject (LPFileTransfersManagerDelegate)
- (void)fileTransfersManager:(LPFileTransfersManager *)manager didReceiveIncomingFileTransfer:(LPFileTransfer *)newFileTransfer;
- (void)fileTransfersManager:(LPFileTransfersManager *)manager willStartOutgoingFileTransfer:(LPFileTransfer *)newFileTransfer;
@end
