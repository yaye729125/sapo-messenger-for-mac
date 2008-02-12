//
//  LPAvatarEditorView.h
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


@interface LPAvatarEditorView : NSView
{
	NSSize		m_minAvatarSize;
	NSSize		m_maxAvatarSize;
	NSImage		*m_originalImage;
	float		m_zoomFactor;
	NSPoint		m_cropRectCenterInImage;
	
	BOOL		m_draggingImage;
	NSPoint		m_previousMouseLocationInDrag;
	BOOL		m_displayDropAcceptableFeedback;
	
	NSRect		m_currentCropRect;
	NSRect		m_currentImageRect;
}

- (NSSize)minAvatarSize;
- (void)setMinAvatarSize:(NSSize)minSize;
- (NSSize)maxAvatarSize;
- (void)setMaxAvatarSize:(NSSize)maxSize;

- (NSImage *)originalImage;
- (void)setOriginalImage:(NSImage *)img;

+ (NSArray *)acceptedPasteboardTypes;
+ (BOOL)canImportContentsOfPasteboard:(NSPasteboard *)pboard;
- (void)setOriginalImageFromPasteboard:(NSPasteboard *)pboard;

- (NSImage *)finalAvatarImage;

- (NSPoint)cropRectCenterInImageScale;
- (void)setCropRectCenterInImageScale:(NSPoint)center;

/* Valid zoom values:
 *     0.0  =>  entire original image inside the crop rect;	crop rect at its MAX size;
 *     1.0  =>  original image at its natural size;			crop rect at its MAX size;
 *     2.0  =>  original image at its natural size;			crop rect ar its MIN size.
 */
- (float)zoomFactor;
- (void)setZoomFactor:(float)factor;
- (void)zoomToFullestImageDisplayFactor;

@end
