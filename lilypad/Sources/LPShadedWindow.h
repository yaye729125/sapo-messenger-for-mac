//
//  LPShadedWindow.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Authors: Joao Pavao <jppavao@criticalsoftware.com>
//           Jason Kim <jason@512k.org>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//
//
// A window that replaces the default textured window with a smoothly shaded one.
//
// This window is currently intended only for very minimal use, as it has a non-standard UI
// appearance. It is used with the roster to give it a distinct look, but should be used sparingly.
//

#import <Cocoa/Cocoa.h>


@interface LPShadedWindow : NSWindow
- (void)_updateBackgroundForSize:(NSSize)size;
@end
