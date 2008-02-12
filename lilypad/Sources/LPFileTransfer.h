//
//  LPFileTransfer.h
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


@class LPContactEntry, LPAccount;


typedef enum {
	LPIncomingTransfer,
	LPOutgoingTransfer
} LPFileTransferType;


typedef enum {
	LPFileTransferPackaging,
	LPFileTransferWaitingToBeAccepted,
	LPFileTransferWasNotAccepted,
	LPFileTransferRunning,
	LPFileTransferAbortedWithError,
	LPFileTransferCancelled,
	LPFileTransferCompleted
} LPFileTransferState;


@interface LPFileTransfer : NSObject
{
	int					m_ID;
	id					m_delegate;
	
	LPFileTransferType	m_type;
	LPFileTransferState	m_state;
	
	LPContactEntry		*m_peerContactEntry;
	NSString			*m_description;
	NSString			*m_localFilePathname;
	BOOL				m_localFileExists;
	NSString			*m_lastErrorMessage;

	unsigned long long	m_fileSize;
	unsigned long long	m_currentOffset;
	unsigned long long	m_transferSpeed; // in bytes per second
	
	NSTask				*m_packagingTask;
	NSString			*m_packageFilePath;
	
	// The following two instance variables are used for the transfer speed calculations
	unsigned long long	m_bytesTransferredSinceLastSpeedUpdate;
	NSDate				*m_dateOfLastSpeedUpdate;
}

+ (LPFileTransfer *)incomingTransferFromContactEntry:(LPContactEntry *)contactEntry ID:(int)transferID filename:(NSString *)filename description:(NSString *)description size:(unsigned long long)fileSize;
+ (LPFileTransfer *)outgoingTransferToContactEntry:(LPContactEntry *)contactEntry sourceFilePathname:(NSString *)pathname description:(NSString *)description;
- initWithID:(int)transferID type:(LPFileTransferType)transferType peerContactEntry:(LPContactEntry *)contactEntry filePathname:(NSString *)pathname description:(NSString *)description fileSize:(unsigned long long)fileSize;
- initWithID:(int)transferID type:(LPFileTransferType)transferType peerContactEntry:(LPContactEntry *)contactEntry filePathname:(NSString *)pathname description:(NSString *)description fileAttributes:(NSDictionary *)attribs;

- (id)delegate;
- (void)setDelegate:(id)delegate;

- (int)ID;
- (LPFileTransferType)type;
- (LPFileTransferState)state;
- (LPContactEntry *)peerContactEntry;
- (NSString *)filename;
- (NSString *)description;
- (NSString *)localFilePath;
- (BOOL)localFileExists;
- (NSString *)lastErrorMessage;
- (unsigned long long)fileSize;
- (unsigned long long)currentFileOffset;
- (unsigned long long)transferSpeedBytesPerSecond;

- (void)acceptIncomingFileTransfer:(BOOL)accept;
- (void)cancel;

- (void)handleLocalFileCreatedWithPathName:(NSString *)actualPathName;
- (void)handleReceivedUpdatedFileSize:(unsigned long long)actualFileSize;
- (void)handleFileTransferAccepted;
- (void)handleProgressUpdateWithSentBytes:(unsigned long long)sentBytes currentProgress:(unsigned long long)currentProgress progressTotal:(unsigned long long)progressTotal;
- (void)handleFileTransferFinished;
- (void)handleFileTransferErrorWithMessage:(NSString *)errorMessage;

@end


// Notifications
extern NSString *LPFileTransferDidChangeStateNotification;


@interface NSObject (LPFileTransferDelegate)
- (void)fileTransfer:(LPFileTransfer *)fileTransfer didFailWithErrorMessage:(NSString *)errorMessage;
@end

