//
//  LPCurrentITunesTrackMonitor.h
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informa��es sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


@interface LPCurrentITunesTrackMonitor : NSObject
{
	NSAppleScript	*m_script;
	
	NSString		*m_album;
	NSString		*m_artist;
	NSString		*m_title;
	NSString		*m_streamTitle;
	BOOL			m_isPlaying;
}
- (NSString *)album;
- (NSString *)artist;
- (NSString *)title;
- (NSString *)streamTitle;
- (BOOL)isPlaying;
@end


// Notifications
extern NSString *LPCurrentITunesTrackDidChange;

