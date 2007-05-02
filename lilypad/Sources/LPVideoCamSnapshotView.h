//
//  LPVideoCamSnapshotView.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>
#import <QuickTime/QuickTime.h>


@interface LPVideoCamSnapshotView : NSQuickDrawView
{
	SeqGrabComponent	m_seqGrabComponent;
	SGChannel			m_channelRef;
}
+ (BOOL)videoCameraHardwareExists;
- (BOOL)isPreviewing;
- (BOOL)startPreviewing;
- (void)stopPreviewing;
- (NSImage *)captureFrame;
@end
