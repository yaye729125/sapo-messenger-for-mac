//
//  LPFileTransfer.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPFileTransfer.h"

#include <unistd.h>


// Notifications
NSString *LPFileTransferDidChangeStateNotification = @"LPFileTransferDidChangeState";


@interface LPFileTransfer (Private)
- (void)p_setState:(LPFileTransferState)state;
- (void)p_setLocalFilePath:(NSString *)actualPathName;
@end


@implementation LPFileTransfer

+ (LPFileTransfer *)incomingTransferFromContactEntry:(LPContactEntry *)contactEntry ID:(int)transferID filename:(NSString *)filename description:(NSString *)description size:(unsigned long long)fileSize account:(LPAccount *)account
{
	// Get the destination folder for the download
	NSString *downloadsFolder = [[NSUserDefaults standardUserDefaults] objectForKey:@"DownloadsFolder"];
	
	// Temporary destination filepath. It's temporary because it will be updated later, anyway. When the user accepts
	// the transfer, if a file already exists at this path, then an alternative free one will be created and our internal
	// data will be updated accordingly.
	NSString *tempFilepath = [downloadsFolder stringByAppendingPathComponent:filename];
	
	return [[[[self class] alloc] initWithID:transferID
										type:LPIncomingTransfer
									 account:account
							peerContactEntry:contactEntry
								filePathname:tempFilepath
								 description:description
									fileSize:fileSize] autorelease];
}


+ (LPFileTransfer *)outgoingTransferToContactEntry:(LPContactEntry *)contactEntry sourceFilePathname:(NSString *)pathname description:(NSString *)description account:(LPAccount *)account
{
	// Determine the file size
	NSDictionary *attribs = [[NSFileManager defaultManager] fileAttributesAtPath:pathname traverseLink:YES];
	int fileID = -1;
	
	if ([[attribs objectForKey:NSFileType] isEqualToString:NSFileTypeDirectory]) {
		fileID = [[LFAppController fileCreatePendingTo:[contactEntry ID]] intValue];
	}
	else {
		// It's a regular file, we can start the transfer right away
		fileID = [[LFAppController fileStartTo:[contactEntry ID]
									sourcePath:pathname
								   description:description] intValue];
	}
	
	return [[[[self class] alloc] initWithID:fileID
										type:LPOutgoingTransfer
									 account:account
							peerContactEntry:contactEntry
								filePathname:pathname
								 description:description
							  fileAttributes:attribs] autorelease];
}


- initWithID:(int)transferID type:(LPFileTransferType)transferType account:(LPAccount *)account peerContactEntry:(LPContactEntry *)contactEntry filePathname:(NSString *)pathname description:(NSString *)description fileSize:(unsigned long long)fileSize
{
	if (self = [super init]) {
		m_ID = transferID;
		m_type = transferType;
		m_account = [account retain];
		m_peerContactEntry = [contactEntry retain];
		m_description = [description copy];
		m_localFilePathname = [pathname copy];
		m_fileSize = fileSize;
		m_state = LPFileTransferWaitingToBeAccepted;
		
		if (transferType == LPOutgoingTransfer)
			m_localFileExists = YES;
	}
	return self;
}


- initWithID:(int)transferID type:(LPFileTransferType)transferType account:(LPAccount *)account peerContactEntry:(LPContactEntry *)contactEntry filePathname:(NSString *)pathname description:(NSString *)description fileAttributes:(NSDictionary *)attribs
{
	self = [self initWithID:transferID
					   type:transferType
					account:account
		   peerContactEntry:contactEntry
			   filePathname:pathname
				description:description
				   fileSize:[attribs fileSize]];

	if (self != nil
		&& transferType == LPOutgoingTransfer
		&& [[attribs objectForKey:NSFileType] isEqualToString:NSFileTypeDirectory])
	{
		m_state = LPFileTransferPackaging;
		
		// Package the directory
		NSString	*baseTmpDir = NSTemporaryDirectory();
		NSString	*mktempTemplate = [baseTmpDir stringByAppendingPathComponent:@"PreProcessed-File-Transfer-XXXX"];
		char		mktempResult[1020];
		
		strncpy(mktempResult, [mktempTemplate UTF8String], MIN([mktempTemplate length] + 1, 1020));
		mkdtemp(mktempResult);
		mktempResult[1019] = '\0';
		
		NSString *tempWorkingDir = [NSString stringWithUTF8String:mktempResult];
		NSString *tempFilename = [NSString stringWithFormat:@"%@.zip", [pathname lastPathComponent]];
		
		m_packagingTask = [[NSTask alloc] init];
		[m_packagingTask setCurrentDirectoryPath:tempWorkingDir];
		[m_packagingTask setLaunchPath:@"/usr/bin/ditto"];
		[m_packagingTask setArguments:[NSArray arrayWithObjects:
			@"-c", @"-k", @"--keepParent",
			pathname, tempFilename, nil]];
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(p_filePackagingDidFinish:)
													 name:NSTaskDidTerminateNotification
												   object:m_packagingTask];
		[m_packagingTask launch];
		
		m_packageFilePath = [[tempWorkingDir stringByAppendingPathComponent:tempFilename] copy];
	}
	return self;
}


- (void)p_setState:(LPFileTransferState)state
{
	if (state != m_state) {
		[self willChangeValueForKey:@"state"];
		m_state = state;
		[self didChangeValueForKey:@"state"];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:LPFileTransferDidChangeStateNotification
															object:self];
		
		// Clean up the packaged file if we can
		if (state == LPFileTransferWasNotAccepted ||
			state == LPFileTransferAbortedWithError ||
			state == LPFileTransferCancelled ||
			state == LPFileTransferCompleted)
		{
			if ([m_packagingTask isRunning])
				[m_packagingTask terminate];
			[m_packagingTask release];
			m_packagingTask = nil;
			
			if (m_packageFilePath != nil) {
				NSString *tempWorkingDirectory = [m_packageFilePath stringByDeletingLastPathComponent];
				
				// This will also delete the contents of the directory recursivelly
				[[NSFileManager defaultManager] removeFileAtPath:tempWorkingDirectory handler:nil];
				
				[m_packageFilePath release];
				m_packageFilePath = nil;
			}
		}
	}
}


- (void)p_setLocalFilePath:(NSString *)actualPathName
{
	if ([m_localFilePathname isEqualToString:actualPathName] == NO) {
		[self willChangeValueForKey:@"localFilePath"];
		[m_localFilePathname release];
		m_localFilePathname = [actualPathName copy];
		[self didChangeValueForKey:@"localFilePath"];
	}
}
	

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[m_account release];
	[m_peerContactEntry release];
	[m_localFilePathname release];
	[m_description release];
	[m_lastErrorMessage release];
	[m_dateOfLastSpeedUpdate release];
	
	[m_packagingTask terminate];
	[m_packagingTask release];
	[m_packageFilePath release];
	
	[super dealloc];
}


#pragma mark -
#pragma mark NSTask Notifications


- (void)p_filePackagingDidFinish:(NSNotification *)notif
{
	NSTask *task = [notif object];
	
	if ([task terminationStatus] == 0) {
		// Update the file size
		NSDictionary *attribs = [[NSFileManager defaultManager] fileAttributesAtPath:m_packageFilePath traverseLink:YES];
		
		[self willChangeValueForKey:@"fileSize"];
		m_fileSize = [attribs fileSize];
		[self didChangeValueForKey:@"fileSize"];
		
		// Send the packaged file
		[LFAppController fileStartPendingID:[self ID]
										 To:[m_peerContactEntry ID]
								 sourcePath:m_packageFilePath
								description:m_description];
		
		[self p_setState:LPFileTransferWaitingToBeAccepted];
	}
	else if ([self state] == LPFileTransferPackaging) {
		[self p_setState:LPFileTransferAbortedWithError];
	}
	
	// Release all the NSTask stuff
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:NSTaskDidTerminateNotification
												  object:m_packagingTask];
	[m_packagingTask autorelease];
	m_packagingTask = nil;
}


#pragma mark -
#pragma mark Accessors


- (id)delegate
{
	return m_delegate;
}

- (void)setDelegate:(id)delegate
{
	m_delegate = delegate;
}


- (int)ID
{
	return m_ID;
}


- (LPFileTransferType)type
{
	return m_type;
}


- (LPFileTransferState)state
{
	return m_state;
}


- (LPAccount *)account
{
	return [[m_account retain] autorelease];
}


- (LPContactEntry *)peerContactEntry
{
	return [[m_peerContactEntry retain] autorelease];
}


- (NSString *)filename
{
	return [[self localFilePath] lastPathComponent];
}


- (NSString *)description
{
	return [[m_description copy] autorelease];
}


- (NSString *)localFilePath
{
	return [[m_localFilePathname copy] autorelease];
}


- (BOOL)localFileExists
{
	return m_localFileExists;
}


- (NSString *)lastErrorMessage
{
	return [[m_lastErrorMessage copy] autorelease];
}


- (unsigned long long)fileSize
{
	return m_fileSize;
}


- (unsigned long long)currentFileOffset
{
	return m_currentOffset;
}


- (unsigned long long)transferSpeedBytesPerSecond
{
	return m_transferSpeed;
}


- (void)acceptIncomingFileTransfer:(BOOL)accept
{
	NSAssert([self type] == LPIncomingTransfer, @"Cannot accept outgoing file transfers!");
	NSAssert([self state] == LPFileTransferWaitingToBeAccepted, @"File transfer is not waiting to be accepted.");
	
	if (accept) {
		// Get the destination folder for the download
		NSString *downloadsFolder = [[NSUserDefaults standardUserDefaults] objectForKey:@"DownloadsFolder"];
		
		// Check if the path exists and is a directory
		NSFileManager	*fm = [NSFileManager defaultManager];
		BOOL			isDir, fileExists;
		fileExists = [fm fileExistsAtPath:downloadsFolder isDirectory:&isDir];
		
		if (!fileExists || !isDir) {
			// Fallback to using the desktop folder
			downloadsFolder = [NSHomeDirectory() stringByAppendingPathComponent:@"Desktop"];
		}
		
		// Try to find a filename that doesn't exist yet. If the original filename exists, start testing
		// filename-1, filename-2, etc.
		NSString *filepath = [downloadsFolder stringByAppendingPathComponent:[self filename]];
		NSString *basename = nil, *extension = nil;
		int alternativeFilenameIndex = 0;
		
		while ([fm fileExistsAtPath:filepath]) {
			++alternativeFilenameIndex;
			if (basename == nil) {
				basename = [[filepath lastPathComponent] stringByDeletingPathExtension];
			}
			if (extension == nil) {
				extension = [filepath pathExtension];
			}
			
			NSString *newBasename = [NSString stringWithFormat:@"%@-%d", basename, alternativeFilenameIndex];
			if ([extension length] > 0) {
				filepath = [[downloadsFolder stringByAppendingPathComponent:newBasename] stringByAppendingPathExtension:extension];
			} else {
				filepath = [downloadsFolder stringByAppendingPathComponent:newBasename];
			}
		}
		
		// Update internal data
		[self p_setLocalFilePath:filepath];
		[self p_setState:LPFileTransferRunning];

		[LFAppController fileAccept:[self ID] destinationPath:[self localFilePath]];
	} else {
		[self cancel];
	}
}


- (void)cancel
{
	[LFAppController fileCancel:[self ID]];
	
	if (([self type] == LPIncomingTransfer) && ([self state] == LPFileTransferWaitingToBeAccepted)) {
		[self p_setState:LPFileTransferWasNotAccepted];
	}
	else {
		[self p_setState:LPFileTransferCancelled];
	}
}


#pragma mark -


- (void)handleLocalFileCreatedWithPathName:(NSString *)actualPathName
{
	// Update internal data
	[self p_setLocalFilePath:actualPathName];
}


- (void)handleReceivedUpdatedFileSize:(unsigned long long)actualFileSize
{
	if (actualFileSize != m_fileSize) {
		[self willChangeValueForKey:@"fileSize"];
		m_fileSize = actualFileSize;
		[self didChangeValueForKey:@"fileSize"];
	}
}


- (void)handleFileTransferAccepted
{
	[self p_setState:LPFileTransferRunning];
}


- (void)p_updateTransferSpeedWithAdditionalSentBytes:(unsigned long long)sentBytes
{
	m_bytesTransferredSinceLastSpeedUpdate += sentBytes;
	
	// Check if we should update the transfer speed info
	NSDate *currentDate = [[NSDate alloc] init];
	
	if ((m_dateOfLastSpeedUpdate == nil) ||
		([currentDate timeIntervalSinceDate:m_dateOfLastSpeedUpdate] >= 1.0))
	{
		[self willChangeValueForKey:@"transferSpeedBytesPerSecond"];
		m_transferSpeed = (double)m_bytesTransferredSinceLastSpeedUpdate
			/ [currentDate timeIntervalSinceDate:m_dateOfLastSpeedUpdate];
		[self didChangeValueForKey:@"transferSpeedBytesPerSecond"];
		
		m_bytesTransferredSinceLastSpeedUpdate = 0;
		[m_dateOfLastSpeedUpdate release];
		m_dateOfLastSpeedUpdate = [currentDate retain];
	}
	
	[currentDate release];
}


- (void)p_delayedUpdateTransferSpeed
{
	[self p_updateTransferSpeedWithAdditionalSentBytes:0ull];
}


- (void)handleProgressUpdateWithSentBytes:(unsigned long long)sentBytes currentProgress:(unsigned long long)currentProgress progressTotal:(unsigned long long)progressTotal
{
	[self p_updateTransferSpeedWithAdditionalSentBytes:sentBytes];

	// Force an update of the transfer speed some time from now so that in case we don't get any progress
	// updates in a while, the speed gets the chance to be updated to 0.
	[NSObject cancelPreviousPerformRequestsWithTarget:self
											 selector:@selector(p_delayedUpdateTransferSpeed)
											   object:nil];
	[self performSelector:@selector(p_delayedUpdateTransferSpeed)
			   withObject:nil
			   afterDelay:2.0];
	
	[self willChangeValueForKey:@"currentFileOffset"];
	m_currentOffset = currentProgress;
	[self didChangeValueForKey:@"currentFileOffset"];
	
	if ([self localFileExists] == NO) {
		[self willChangeValueForKey:@"localFileExists"];
		m_localFileExists = YES;
		[self didChangeValueForKey:@"localFileExists"];
	}
}


- (void)handleFileTransferFinished
{
	[self p_setState:LPFileTransferCompleted];
}


- (void)handleFileTransferErrorWithMessage:(NSString *)errorMessage
{
	[m_lastErrorMessage release];
	m_lastErrorMessage = [errorMessage copy];
	
	[self p_setState:LPFileTransferAbortedWithError];
	
	if ([[self delegate] respondsToSelector:@selector(fileTransfer:didFailWithErrorMessage:)]) {
		[[self delegate] fileTransfer:self didFailWithErrorMessage:errorMessage];
	}
}


@end

