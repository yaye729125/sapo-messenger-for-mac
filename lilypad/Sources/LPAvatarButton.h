//
//  LPAvatarButton.h
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


@interface LPAvatarButton : NSButton
{
	NSTrackingRectTag	m_trackingRect;
	id					m_delegate;
}
- (id)delegate;
- (void)setDelegate:(id)delegate;
@end

@interface NSObject (LPAvatarButtonDelegate)
- (void)avatarButton:(LPAvatarButton *)bttn receivedDropWithPasteboard:(NSPasteboard *)pboard;
@end


@interface LPAvatarButtonCell : NSButtonCell
{
	BOOL m_mouseInCell;
}
@end
