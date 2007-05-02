//
//  LPRosterTextFieldCell.h
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
// Displays a two-line representation of a user's status, as seen in iChat. (Note that the avatar
// itself is displayed in a separate table column for simplicity, as also implemented in iChat.)
// 
// TODO: Implement various display arrangements according to user preferences.
//
// NOTE: This class is not yet intended for use with the editing mechanisms; it is only designed
// for display use in NSTableViews.
//


#import <Cocoa/Cocoa.h>


@interface LPRosterTextFieldCell : NSTextFieldCell 
- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView;
@end
