//
//  LPInternalDataUpgradeManager.m
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informa›es sobre o licenciamento, leia o ficheiro README.
//

#import "LPInternalDataUpgradeManager.h"
#import "LPMessageCenter.h"


@implementation LPInternalDataUpgradeManager

+ (LPInternalDataUpgradeManager *)upgradeManager
{
	return [[[[self class] alloc] init] autorelease];
}

- (void)p_showWindow
{
	if (m_window == nil) {
		[NSBundle loadNibNamed:@"InternalDataUpgrade" owner:self];
	}
	[m_progressIndicator setUsesThreadedAnimation:YES];
	[m_progressIndicator startAnimation:nil];
	
	if (m_modalSession == NULL) {
		m_modalSession = [NSApp beginModalSessionForWindow:m_window];
	}
}

- (void)p_closeWindow
{
	if (m_modalSession != NULL) {
		[m_progressIndicator stopAnimation:nil];
		
		[NSApp stopModal];
		[NSApp endModalSession:m_modalSession];
		m_modalSession = NULL;
	}
}

- (void)dealloc
{
	[self p_closeWindow];
	[m_window release];
	
	[super dealloc];
}

- (void)p_detachedMessageCenterMigration:(id)args
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[LPMessageCenter migrateMessageCenterStoreIfNeeded];
	[self performSelectorOnMainThread:@selector(p_messageCenterMigrationIsDone:)
						   withObject:nil waitUntilDone:NO];
	
	[pool release];
}

- (void)p_messageCenterMigrationIsDone:(id)args
{
	m_done = YES;
}

- (void)upgradeInternalDataIfNeeded
{
	// Check whether there are any old chat transcript files that need to be moved to a separate folder
	NSFileManager	*fm = [NSFileManager defaultManager];
	NSString		*chatTranscriptsFolder = LPChatTranscriptsFolderPath();
	NSArray			*transcriptFolderContents = [fm directoryContentsAtPath:chatTranscriptsFolder];
	NSPredicate		*filterPredicate = [NSPredicate predicateWithFormat:@"pathExtension == 'webarchive'"];
	NSArray			*webarchivesInBaseFolder = [transcriptFolderContents filteredArrayUsingPredicate:filterPredicate];
	
	if ([LPMessageCenter needsToMigrateMessageCenterStore] || [webarchivesInBaseFolder count] > 0) {
		NSRunLoop *currentRL = [NSRunLoop currentRunLoop];
		
		// Pop the window only if this takes more than 0.5 seconds to run
		[self performSelector:@selector(p_showWindow) withObject:nil afterDelay:0.5];
		
		if ([webarchivesInBaseFolder count] > 0) {
			NSString *prevCWD = [fm currentDirectoryPath];
			[fm changeCurrentDirectoryPath:chatTranscriptsFolder];
			
			NSString *destinationFolder = @"Old Chat Transcripts";
			[fm createDirectoryAtPath:destinationFolder attributes:nil];
			
			NSEnumerator *webarchivesEnumerator = [webarchivesInBaseFolder objectEnumerator];
			NSString *webarchive = nil;
			int iterationCounter = 0;
			
			while (webarchive = [webarchivesEnumerator nextObject]) {
				[fm movePath:webarchive toPath:[destinationFolder stringByAppendingPathComponent:webarchive] handler:nil];
				
				if ((iterationCounter % 20) == 0) {
					if (m_modalSession == NULL) {
						[currentRL runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
					} else {
						[NSApp runModalSession:m_modalSession];
					}
				}
				
				++iterationCounter;
			}
			
			[fm changeCurrentDirectoryPath:prevCWD];
		}
		
		
		if ([LPMessageCenter needsToMigrateMessageCenterStore]) {
			// Detach the migration in a new thread because it blocks until it's done
			[NSThread detachNewThreadSelector:@selector(p_detachedMessageCenterMigration:) toTarget:self withObject:nil];
			
			while (!m_done) {
				if (m_modalSession == NULL) {
					[currentRL runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
				} else {
					[NSApp runModalSession:m_modalSession];
				}
			}
		}
		
		[self p_closeWindow];
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(p_showWindow) object:nil];
	}
}

@end
