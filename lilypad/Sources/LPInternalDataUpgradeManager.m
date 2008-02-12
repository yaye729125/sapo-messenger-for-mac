//
//  LPInternalDataUpgradeManager.m
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
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
	
	[NSApp runModalForWindow:m_window];
}

- (void)p_closeWindow
{
	if ([NSApp modalWindow] == m_window) {
		[NSApp abortModal];
		[m_progressIndicator stopAnimation:nil];
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
	[self p_closeWindow];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(p_showWindow) object:nil];
}

- (void)upgradeInternalDataIfNeeded
{
	if ([LPMessageCenter needsToMigrateMessageCenterStore]) {
		// Detach the migration in a new thread because it blocks until it's done
		[NSThread detachNewThreadSelector:@selector(p_detachedMessageCenterMigration:) toTarget:self withObject:nil];
		
		// Pop the window only if it takes more than 0.5 seconds to run
		[self performSelector:@selector(p_showWindow) withObject:nil afterDelay:0.5];
		
		while (!m_done) {
			[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
		}
		
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(p_showWindow) object:nil];
	}
}

@end
