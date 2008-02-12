//
//  JKAnimatedGroupTableView.h
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Authors: Joao Pavao <jpavao@co.sapo.pt>
//           Jason Kim <jason@512k.org>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//
//
// Extends JKGroupTableView to provide fancy-pants animation during open and close.
//
//

#import <Cocoa/Cocoa.h>
#import "JKGroupTableView.h"


@interface JKAnimatedGroupTableView : JKGroupTableView
{
	NSDictionary	*m_animationData;
	float			m_smoothAnimationProgress;
	BOOL			m_animationIsRunning;
	int				m_animatedGroupIndex;
}

- (float)animationDuration;
- (unsigned int)animationFramesPerSecond;
- (void)collapseGroupAtIndex:(unsigned int)groupIndex animate:(BOOL)doAnimation;
- (void)expandGroupAtIndex:(unsigned int)groupIndex animate:(BOOL)doAnimation;

@end
