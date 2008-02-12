//
//  LPCustomBox.h
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Jason Kim <jason@512k.org>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//
//
// A view that draws a very simple box based on a provided image.
//
// Currently, LPCustomBox uses hardcoded values. A 16x16 image where each 6x6 corner is painted 
// into the corners of the view, and the intermediate 4x6 and 6x4 pieces are stretched to fill 
// the horizontal and vertical border edges, respectively; the center 4x4 portion is unused.
//
// (If this is confusing, draw yourself a diagram. ASCII art isn't worth the trouble.)
//

#import <Cocoa/Cocoa.h>


@interface LPCustomBox : NSBox {
	NSImage *_borderImage;
}

@end
