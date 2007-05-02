//
//  LPVideoCamSnapshotView.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPVideoCamSnapshotView.h"


@implementation LPVideoCamSnapshotView

+ (void)initialize
{
	// Initialize the QuickTime toolbox
	EnterMovies();
}

+ (BOOL)videoCameraHardwareExists
{
	VideoDigitizerComponent vdComp;
	
	// Just try to find a default video digitizer component
    OSErr err = OpenADefaultComponent(videoDigitizerComponentType, 0, &vdComp);
	CloseComponent(vdComp);
	
	return (err == noErr);
}

- (id)initWithFrame:(NSRect)frame
{
    if (self = [super initWithFrame:frame]) {
        // Initialization code here.
    }
    return self;
}

- (void)dealloc
{
	[self stopPreviewing];
	[super dealloc];
}

- (BOOL)isOpaque
{
	return YES;
}

- (void)drawRect:(NSRect)rect
{
	[[NSColor whiteColor] set];
	NSRectFill(rect);
	[[NSColor darkGrayColor] set];
	NSFrameRect([self bounds]);
	
    [super drawRect:rect];
}

- (BOOL)isPreviewing
{
	return (m_seqGrabComponent != NULL);
}

- (BOOL)startPreviewing
{
	if ([self isPreviewing]) {
		// There's no reason to flag an error. Just keep previewing and return success.
		return YES;
	}
	else {
		OSErr err;
		
		// Open Sequence Grabber component
		err = OpenADefaultComponent(SeqGrabComponentType, 0, &m_seqGrabComponent);
		if (err != noErr)
			goto cleanupComponentAndBailOut;
		
		// Initialize Sequence Grabber component
		err = SGInitialize(m_seqGrabComponent);
		if (err != noErr)
			goto cleanupComponentAndBailOut;
		
		
		// Create the video channel
		/*
		 * If the camera is already busy or if there is no camera installed, this returns an error of
		 * couldntGetRequiredComponent = -9405. +[LPVideoCamSnapshotView videoCameraHardwareExists] should
		 * be used instead to distinguish between these two situations.
		 */
		err = SGNewChannel(m_seqGrabComponent, VideoMediaType, &m_channelRef);
		if (err != noErr)
			goto cleanupComponentAndBailOut;

		// Setup the graphics port into which the preview is to be drawn.
		// The view's QD port is only valid while the view is focused.
		[self lockFocus];
		err = SGSetGWorld(m_seqGrabComponent, [self qdPort], NULL);
		[self unlockFocus];
		if (err != noErr)
			goto cleanupComponentAndBailOut;
		
		
		// Set boundaries for new video channel: start by getting the bounds of the video source
		Rect channelRect;
		err = SGGetSrcVideoBounds(m_channelRef, &channelRect);
		if (err != noErr)
			goto cleanupChannelAndBailOut;
		
		NSRect	viewBounds = [self bounds];
		NSRect	usableViewRect = NSInsetRect(viewBounds, 5.0, 5.0); // 5.0 = 1px frame + 4px margin
		float	horizontalCoef = NSWidth(usableViewRect)  / (float)(channelRect.right  - channelRect.left);
		float	verticalCoef   = NSHeight(usableViewRect) / (float)(channelRect.bottom - channelRect.top );
		float	coef = MIN(horizontalCoef, verticalCoef);
		float	targetVideoWidth  = coef * channelRect.right;
		float	targetVideoHeight = coef * channelRect.bottom;
		float	horizontalMargin = (NSWidth(viewBounds)  - targetVideoWidth ) / 2.0;
		float	verticalMargin   = (NSHeight(viewBounds) - targetVideoHeight) / 2.0;
		Rect	targetVideoRect = {
			verticalMargin, horizontalMargin,
			NSHeight(viewBounds) - verticalMargin, NSWidth(viewBounds) - horizontalMargin
		};
		
		// Set boundaries for new video channel: NOW we're actually setting it
		err = SGSetChannelBounds(m_channelRef, &targetVideoRect);
		if (err != noErr)
			goto cleanupChannelAndBailOut;
		
		
		// Set usage for new video channel
		err = SGSetChannelUsage(m_channelRef, seqGrabPreview | seqGrabRecord);
		if (err != noErr)
			goto cleanupChannelAndBailOut;
		
		
		// Actually start the PREVIEW
		SGSetDataRef(m_seqGrabComponent, NULL, 0, seqGrabDontMakeMovie);
		err = SGStartPreview(m_seqGrabComponent);
		
		
		[NSTimer scheduledTimerWithTimeInterval:(1.0 / 30.0)
										 target:self
									   selector:@selector(idle:)
									   userInfo:nil
										repeats:YES];
		
cleanupChannelAndBailOut:
		if (err && m_channelRef) {  // cleanup on failure
			SGDisposeChannel(m_seqGrabComponent, m_channelRef);
			m_channelRef = NULL;
		}
		
cleanupComponentAndBailOut:
		if (err && (m_seqGrabComponent != NULL)) {  // cleanup on failure
			CloseComponent(m_seqGrabComponent);
			m_seqGrabComponent = NULL;
		}
		
		return (err == noErr);
	}
}

- (void)idle:(NSTimer *)timer
{
	if ([self isPreviewing]) {
		SGIdle(m_seqGrabComponent);
	}
	else {
		[timer invalidate];
	}
}

- (void)stopPreviewing
{
	if ([self isPreviewing]) {
		SGDisposeChannel(m_seqGrabComponent, m_channelRef);
		m_channelRef = NULL;
		CloseComponent(m_seqGrabComponent);
		m_seqGrabComponent = NULL;
	}
}

- (NSImage *)captureFrame
{
	NSImage *img = nil;
	
	if ([self isPreviewing]) {
		PicHandle pict;
		
		OSErr err = SGGrabPict(m_seqGrabComponent, &pict, NULL, 0, 0);
		
		if (err == noErr) {
			NSData	*imgData = [NSData dataWithBytes:(*pict) length:GetHandleSize((Handle)pict)];
			
			img = [[[NSImage alloc] initWithData:imgData] autorelease];
			DisposeHandle((Handle)pict);
		}
	}
	
	return img;
}

@end
