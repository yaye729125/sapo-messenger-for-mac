//
//  LPEmoticonPicker.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


@class LPEmoticonSet, LPEmoticonMatrix;


#define LPEmoticonPickerNoneSelected	-1


/*!
    @class		 LPEmoticonPicker
    @abstract    Controller of a popup menu for picking emoticons.
    @discussion  Controller of a popup menu for picking emoticons. It displays emoticons from a given emoticon set.
*/

@interface LPEmoticonPicker : NSObject
{
	LPEmoticonSet				*m_emoticonSet;
	
	// These are loaded from our private nib file
	IBOutlet NSView				*m_emoticonView;
	IBOutlet LPEmoticonMatrix	*m_emoticonMatrix;
	IBOutlet NSTextField		*m_emoticonCaptionField;
	IBOutlet NSTextField		*m_emoticonASCIISequenceField;
	
	NSWindow	*m_menuWindow;
	
	BOOL	m_isRunningEventTrackingLoop;
	BOOL	m_shouldStopRunningMenu;
	int		m_clickedCellTag;
}

- initWithEmoticonSet:(LPEmoticonSet *)emoticonSet;

/*!
    @abstract   Open a popup menu for picking an emoticon.
    @discussion Open a popup menu for picking an emoticon. This method will open the menu and run a private event tracking loop until
				either an emoticon is picked or the operation is cancelled (by clicking outside of the menu, for example). When the loop
				is stopped, the menu is closed and the number for the picked emoticon is returned.
	@param		topLeftPoint Desired top left point for the displayed menu window in screen coordinates.
	@param		parentWin	 Window associated to the menu.
	@result		The number of the picked emoticon or LPEmoticonPickerNoneSelected if the event loop had to be finished without the user
				picking any emoticon.
*/
- (int)pickEmoticonNrUsingTopLeftPoint:(NSPoint)topLeftPoint parentWindow:(NSWindow *)parentWin;
/*!
    @abstract   Open a popup menu for picking an emoticon.
    @discussion Open a popup menu for picking an emoticon. This method is similar to pickEmoticonNrUsingTopLeftPoint:parentWindow: but it
				takes the desired top right corner for the menu instead.
	@see		pickEmoticonNrUsingTopLeftPoint:parentWindow:
*/
- (int)pickEmoticonNrUsingTopRightPoint:(NSPoint)topRightPoint parentWindow:(NSWindow *)parentWin;

/*!
    @abstract   Stops running the emoticon menu's private event tracking loop and closes the menu.
*/
- (void)stopRunningMenu;

@end
