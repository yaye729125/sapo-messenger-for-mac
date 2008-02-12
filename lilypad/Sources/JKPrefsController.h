//
//  JKPrefsController.h
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Authors: Jason Kim <jason@512k.org>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//
//
// A generic controller that provides basic facilities for a standard Cocoa preferences window.
//
// This class is intended for use as a base class to derive custom preference controllers. 
// Subclasses should override initializePrefPanes and loadNib as appropriate (see implementation
// for a few more details).
//

#import <Cocoa/Cocoa.h>


@interface JKPrefsController : NSObject 
{
	IBOutlet NSWindow	*m_window;
	NSMutableArray		*m_identifiers;
	NSMutableDictionary *m_views;
	NSMutableDictionary *m_toolbarItems;
}
- (IBAction)showPrefs:(id)sender;
- (void)addPrefWithView:(NSView *)view label:(NSString *)label image:(NSImage *)image identifier:(NSString *)identifier;
- (void)initializePrefPanes;
- (void)loadNib;
- (NSWindow *)window;
@end