//
//  LPCurrentITunesTrackMonitor.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


@interface LPCurrentITunesTrackMonitor : NSObject
{
	NSAppleScript	*m_script;
	
	NSString		*m_album;
	NSString		*m_artist;
	NSString		*m_title;
	BOOL			m_isPlaying;
}
- (NSString *)album;
- (NSString *)artist;
- (NSString *)title;
- (BOOL)isPlaying;
@end


// Notifications
extern NSString *LPCurrentITunesTrackDidChange;

