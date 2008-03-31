//
//  LPCurrentITunesTrackMonitor.m
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informa›es sobre o licenciamento, leia o ficheiro README.
//

#import "LPCurrentITunesTrackMonitor.h"


// Notifications
NSString *LPCurrentITunesTrackDidChange = @"LPCurrentITunesTrackDidChange";


@interface LPCurrentITunesTrackMonitor ()  // Private Methods
- (void)p_setAlbum:(NSString *)theAlbum;
- (void)p_setArtist:(NSString *)theArtist;
- (void)p_setTitle:(NSString *)theTitle;
- (void)p_setStreamTitle:(NSString *)theTitle;
- (void)p_setPlaying:(BOOL)flag;
- (void)p_updateDataFromITunes;
- (void)p_delayedUpdateWithiTunesPlayStatusChangeNotification:(NSNotification *)theNotification;
- (void)p_iTunesPlayStatusChanged:(NSNotification *)theNotification;
@end


@implementation LPCurrentITunesTrackMonitor

- init
{
	if (self = [super init]) {
		// Set up the AppleScript
		NSString		*scriptPath = [[NSBundle mainBundle] pathForResource:@"iTunesCurrentTrack" ofType:@"scpt"];
		NSURL			*scriptURL = [NSURL fileURLWithPath:scriptPath];
		NSDictionary	*errorDict = nil;
		
		m_script = [[NSAppleScript alloc] initWithContentsOfURL:scriptURL error:&errorDict];
		
		// Initialize all the values now
		[self p_updateDataFromITunes];
		
		[[NSDistributedNotificationCenter defaultCenter] addObserver:self
															selector:@selector(p_iTunesPlayStatusChanged:)
																name:@"com.apple.iTunes.playerInfo"
															  object:nil];
	}
	return self;
}

- (void)dealloc
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	[[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
	
	[m_script release];
	[m_album release];
	[m_artist release];
	[m_title release];
	[m_streamTitle release];
	[super dealloc];
}

- (NSString *)album
{
	return [[m_album copy] autorelease];
}

- (NSString *)artist
{
	return [[m_artist copy] autorelease];
}

- (NSString *)title
{
	return [[m_title copy] autorelease];
}

- (NSString *)streamTitle
{
	return [[m_streamTitle copy] autorelease];
}

- (BOOL)isPlaying
{
	return m_isPlaying;
}


#pragma mark -


- (void)p_setAlbum:(NSString *)theAlbum
{
	if (theAlbum != m_album) {
		[self willChangeValueForKey:@"album"];
		[m_album release];
		m_album = [theAlbum copy];
		[self didChangeValueForKey:@"album"];
	}
}

- (void)p_setArtist:(NSString *)theArtist
{
	if (theArtist != m_artist) {
		[self willChangeValueForKey:@"artist"];
		[m_artist release];
		m_artist = [theArtist copy];
		[self didChangeValueForKey:@"artist"];
	}
}

- (void)p_setTitle:(NSString *)theTitle
{
	if (theTitle != m_title) {
		[self willChangeValueForKey:@"title"];
		[m_title release];
		m_title = [theTitle copy];
		[self didChangeValueForKey:@"title"];
	}
}

- (void)p_setStreamTitle:(NSString *)theTitle
{
	if (theTitle != m_streamTitle) {
		[self willChangeValueForKey:@"streamTitle"];
		[m_streamTitle release];
		m_streamTitle = [theTitle copy];
		[self didChangeValueForKey:@"streamTitle"];
	}
}

- (void)p_setPlaying:(BOOL)flag
{
	if (flag != m_isPlaying) {
		[self willChangeValueForKey:@"playing"];
		m_isPlaying = flag;
		[self didChangeValueForKey:@"playing"];
	}
}


- (void)p_updateDataFromITunes
{
	NSAppleEventDescriptor *returnedDescriptor;
	NSDictionary *errorDict = nil;
	
	// Run the AppleScript
	returnedDescriptor = [m_script executeAndReturnError:&errorDict];
	
	int nrOfItems = [returnedDescriptor numberOfItems];
	
	if (returnedDescriptor == nil || nrOfItems == 0) {
		// Reset everything
		[self p_setAlbum:nil];
		[self p_setArtist:nil];
		[self p_setTitle:nil];
		[self p_setStreamTitle:nil];
		[self p_setPlaying:NO];
	}
	else if (nrOfItems >= 3) {
		// We have new data to set
		NSAppleEventDescriptor *descr;
		
		descr = [returnedDescriptor descriptorAtIndex:1];
		[self p_setTitle:( ([descr descriptorType] == typeUnicodeText) ? [descr stringValue] : nil )];
		descr = [returnedDescriptor descriptorAtIndex:2];
		[self p_setArtist:( ([descr descriptorType] == typeUnicodeText) ? [descr stringValue] : nil )];
		descr = [returnedDescriptor descriptorAtIndex:3];
		[self p_setAlbum:( ([descr descriptorType] == typeUnicodeText) ? [descr stringValue] : nil )];
		descr = [returnedDescriptor descriptorAtIndex:4];
		[self p_setStreamTitle:( ([descr descriptorType] == typeUnicodeText) ? [descr stringValue] : nil )];
		
		[self p_setPlaying:YES];
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:LPCurrentITunesTrackDidChange object:self];
}


- (void)p_delayedUpdateWithiTunesPlayStatusChangeNotification:(NSNotification *)theNotification
{
	if ([[[theNotification userInfo] objectForKey:@"Player State"] isEqualToString:@"Stopped"]) {
		/*
		 * Don't try to get anything from iTunes if it is stopped. When iTunes quits, it broadcasts this
		 * notification with a "Player State" == "Stopped". But if we try to get state info from iTunes
		 * while it is quitting, -[NSAppleScript executeAndReturnError:] hangs waiting for a reply from
		 * iTunes. So we just reset everything in here and don't run our applescript at all.
		 */
		[self p_setAlbum:nil];
		[self p_setArtist:nil];
		[self p_setTitle:nil];
		[self p_setStreamTitle:nil];
		[self p_setPlaying:NO];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:LPCurrentITunesTrackDidChange object:self];
	}
	else {
		[self p_updateDataFromITunes];
	}
}


- (void)p_iTunesPlayStatusChanged:(NSNotification *)theNotification
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	[self performSelector:@selector(p_delayedUpdateWithiTunesPlayStatusChangeNotification:)
			   withObject:theNotification
			   afterDelay:5.0];
}


@end
