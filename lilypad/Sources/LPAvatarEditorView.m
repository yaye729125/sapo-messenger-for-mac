//
//  LPAvatarEditorView.m
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informa›es sobre o licenciamento, leia o ficheiro README.
//

#import "LPAvatarEditorView.h"


@interface LPAvatarEditorView (Private)
- (void)p_resetOrigin;
- (float)p_imageSizeCoefficientForZoomFactor:(float)zoomFactor;
- (void)p_updateCropRect;
- (void)p_updateImageRect;
- (NSPoint)p_cropRectCenterInViewScale;
- (void)p_setCropRectCenterInViewScale:(NSPoint)center;
- (NSRect)p_cropRect;
- (NSRect)p_imageDrawingRect;
- (void)p_sanitizeCropRectCenterForImageRect:(NSRect)imageRect;
- (void)p_drawScaledImage;
@end


#pragma mark -


@implementation LPAvatarEditorView

- (id)initWithFrame:(NSRect)frame
{
    if (self = [super initWithFrame:frame]) {
		m_minAvatarSize = NSMakeSize( 32.0,  32.0);
		m_maxAvatarSize = NSMakeSize(128.0, 128.0);
		m_zoomFactor = 1.0;
		m_cropRectCenterInImage = NSMakePoint(0.0, 0.0);
		
		[self p_resetOrigin];
		[self p_updateCropRect];
		[self p_updateImageRect];
		
		[self registerForDraggedTypes:[[self class] acceptedPasteboardTypes]];
    }
    return self;
}


- (void)dealloc
{
	[m_originalImage release];
	[super dealloc];
}


#pragma mark -
#pragma mark Private


- (void)p_resetOrigin
{
	NSRect bounds = [self bounds];
	float originX = -floorf(NSWidth(bounds) / 2.0);
	float originY = -floorf(NSHeight(bounds) / 2.0);
	
	[self setBoundsOrigin:NSMakePoint(originX, originY)];
}


- (float)p_imageSizeCoefficientForZoomFactor:(float)zoomFactor
{
	NSImage *img = [self originalImage];
	
	if (img == nil || zoomFactor >= 1.0) {
		return 1.0;
	}
	else {
		NSSize imageSize = [img size];
		NSSize minSize = [self maxAvatarSize];
		
		float coefficientForMinWidth  = minSize.width  / imageSize.width;
		float coefficientForMinHeight = minSize.height / imageSize.height;
		// Don't allow the image to expand
		float coefficientForMinImageSize = MIN(1.0, MIN(coefficientForMinWidth, coefficientForMinHeight));
		
		// zoomFactor = 0.0  =>  coef = coefficientForMinImageSize (i.e., min size)
		// zoomFactor = 1.0  =>  coef = 1.0 (i.e., natural size)
		float coef = (1.0 - coefficientForMinImageSize) * zoomFactor + coefficientForMinImageSize;
		
		return coef;
	}
}


- (void)p_updateCropRect
{
	float zoomFactor = [self zoomFactor];
	NSSize size;
	
	if (zoomFactor <= 1.0) {
		size = [self maxAvatarSize];
	}
	else {
		// scale it as needed between the MIN and MAX size
		NSSize	maxSize = [self maxAvatarSize];
		NSSize	minSize = [self minAvatarSize];
		float	widthDelta  = maxSize.width  - minSize.width;
		float	heightDelta = maxSize.height - minSize.height;
		
		// zoomFactor = 1.0  =>  coef = 1.0 (i.e., max size)
		// zoomFactor = 2.0  =>  coef = 0.0 (i.e., min size)
		float	coef = 2.0 - zoomFactor;
		
		// make it always be an even number so that it changes size in a consistent manner
		size.width  = ceilf((coef *  widthDelta + minSize.width ) / 2.0) * 2.0;
		size.height = ceilf((coef * heightDelta + minSize.height) / 2.0) * 2.0;
	}
	
	m_currentCropRect = NSMakeRect(-(size.width / 2.0), -(size.height / 2.0), size.width, size.height);
	[self setNeedsDisplay:YES];
}


- (void)p_updateImageRect
{
	NSImage *img = [self originalImage];
	
	if (img) {
		NSSize imageSize = [img size];
		NSSize zoomedImageSize;
		float zoomFactor = [self zoomFactor];
		
		if (zoomFactor >= 1.0) {
			zoomedImageSize = imageSize;
		}
		else {
			float coef = [self p_imageSizeCoefficientForZoomFactor:zoomFactor];
			// make it always be an even number so that it changes size in a consistent manner
			zoomedImageSize = NSMakeSize( ceilf((coef * imageSize.width ) / 2.0) * 2.0 ,
										  ceilf((coef * imageSize.height) / 2.0) * 2.0 );
		}
		
		NSRect imageRect = NSMakeRect(floorf(zoomedImageSize.width / -2.0),
									  floorf(zoomedImageSize.height / -2.0),
									  zoomedImageSize.width,
									  zoomedImageSize.height);
		
		// Sizes may have changed. Clamp the crop rect center in the image to a valid position.
		[self p_sanitizeCropRectCenterForImageRect:imageRect];
		NSPoint cropRectCenter = [self p_cropRectCenterInViewScale];
		
		m_currentImageRect = NSOffsetRect(imageRect, -cropRectCenter.x, -cropRectCenter.y);
	}
	else {
		m_currentImageRect = NSZeroRect;
	}
	[self setNeedsDisplay:YES];
}


- (NSPoint)p_cropRectCenterInViewScale
{
	NSPoint	cropRectCenterInImageScale = [self cropRectCenterInImageScale];
	float	zoomFactor = [self zoomFactor];
	float	coef = [self p_imageSizeCoefficientForZoomFactor:zoomFactor];
	
	return NSMakePoint(floorf(coef * cropRectCenterInImageScale.x), floorf(coef * cropRectCenterInImageScale.y));
}


- (void)p_setCropRectCenterInViewScale:(NSPoint)center
{
	float	zoomFactor = [self zoomFactor];
	float	coef = [self p_imageSizeCoefficientForZoomFactor:zoomFactor];
	NSPoint	cropRectCenterInImageScale = NSMakePoint(center.x / coef, center.y / coef);
	
	m_cropRectCenterInImage = cropRectCenterInImageScale;
}


- (NSRect)p_cropRect
{
	return m_currentCropRect;
}


- (NSRect)p_imageDrawingRect
{
	return m_currentImageRect;
}


- (void)p_sanitizeCropRectCenterForImageRect:(NSRect)imageRect
{
	// Clamp the cropRectCenter to the inside of the crop rect
	NSRect	cropRect = [self p_cropRect];
	float	halfCropRectWidth = NSWidth(cropRect) / 2.0;
	float	halfCropRectHeight = NSHeight(cropRect) / 2.0;
	
	// The center will be allowed to reside anywhere inside the following rect. It consists of the
	// imageRect with a border added so that the image can go right to the margin of the crop rect.
	NSRect	legalCenterRect = NSInsetRect(imageRect, -halfCropRectWidth, -halfCropRectHeight);
	NSPoint	currentCenter = [self p_cropRectCenterInViewScale];
	NSPoint sanitizedCenter;
	
	sanitizedCenter.x = MIN(MAX(currentCenter.x, NSMinX(legalCenterRect)), NSMaxX(legalCenterRect));
	sanitizedCenter.y = MIN(MAX(currentCenter.y, NSMinY(legalCenterRect)), NSMaxY(legalCenterRect));
	
	// Reading the center and then setting it back in view coordinates will add up errors because we're
	// clamping values to the nearest integers in a lot of places in order to avoid drawing a blurred image
	// (it happens when it isn't draw to exact pixel boundaries).
	// So, we only set this back if absolutelly necessary.
	if (sanitizedCenter.x != currentCenter.x || sanitizedCenter.y != currentCenter.y) {
		[self p_setCropRectCenterInViewScale:sanitizedCenter];
	}
}


- (void)p_drawScaledImage
{
	NSImage	*img = [self originalImage];
	NSSize	imageSize = [img size];
	
	NSGraphicsContext *context = [NSGraphicsContext currentContext];
	[context setImageInterpolation:( m_draggingImage ? NSImageInterpolationNone : NSImageInterpolationHigh)];
	
	[img drawInRect:[self p_imageDrawingRect]
		   fromRect:NSMakeRect(0.0, 0.0, imageSize.width, imageSize.height)
		  operation:NSCompositeSourceOver
		   fraction:1.0];
}


#pragma mark -


- (BOOL)isFlipped
{
	return NO;
}


- (BOOL)isOpaque
{
	return YES;
}


- (void)drawRect:(NSRect)rect
{
	NSRect bounds = [self bounds];
	
	// Draw the background
	[[NSColor whiteColor] set];
	NSRectFill(bounds);
	
	// Draw the image
	[self p_drawScaledImage];
	
	// Draw the crop rect mask
	NSRect			drawingCropRect = NSOffsetRect([self p_cropRect], 0.5, 0.5); // fit pixel boundaries
	NSBezierPath	*path = [NSBezierPath bezierPathWithRect:NSInsetRect([self bounds], -1.0, -1.0)];
	// Now draw the inside rect in a clockwise direction so that it's considered to be outside the path.
	// We end up with a "rectangular doughnut" path.
	[path moveToPoint:NSMakePoint(NSMinX(drawingCropRect), NSMinY(drawingCropRect))];
	[path lineToPoint:NSMakePoint(NSMinX(drawingCropRect), NSMaxY(drawingCropRect))];
	[path lineToPoint:NSMakePoint(NSMaxX(drawingCropRect), NSMaxY(drawingCropRect))];
	[path lineToPoint:NSMakePoint(NSMaxX(drawingCropRect), NSMinY(drawingCropRect))];
	[path closePath];
	
	[[NSColor colorWithCalibratedWhite:0.0 alpha:0.40] setStroke];
	[[NSColor colorWithCalibratedWhite:1.0 alpha:0.80] setFill];
	[path fill];
	[path stroke];
	
	// Draw our frame
	[[NSColor darkGrayColor] set];
	NSFrameRectWithWidth(bounds, (m_displayDropAcceptableFeedback ? 3.0 : 1.0));
}


- (void)setFrame:(NSRect)frame
{
	[super setFrame:frame];
	[self p_resetOrigin];
}


- (void)resetCursorRects
{
	[self addCursorRect:[self visibleRect] cursor:[NSCursor openHandCursor]];
}


- (void)mouseDown:(NSEvent *)theEvent
{
	m_draggingImage = YES;
	m_previousMouseLocationInDrag = [theEvent locationInWindow];
	[[NSCursor closedHandCursor] push];
}


- (void)mouseDragged:(NSEvent *)theEvent
{
	NSPoint	mouseLocation = [theEvent locationInWindow];
	float	deltaX = mouseLocation.x - m_previousMouseLocationInDrag.x;
	float	deltaY = mouseLocation.y - m_previousMouseLocationInDrag.y;
	
	m_previousMouseLocationInDrag = mouseLocation;
	
	float coef = [self p_imageSizeCoefficientForZoomFactor:[self zoomFactor]];
	NSPoint cropRectCenter = [self cropRectCenterInImageScale];
	cropRectCenter.x -= deltaX / coef;
	cropRectCenter.y -= deltaY / coef;
	
	// It will be clamped automatically inside this setter
	[self setCropRectCenterInImageScale:cropRectCenter];
}


- (void)mouseUp:(NSEvent *)theEvent
{
	[NSCursor pop];
	m_draggingImage = NO;
	
	// Redisplay with the higher-quality image interpolation
	[self setNeedsDisplay:YES];
}


- (BOOL)acceptsFirstResponder
{
	return YES;
}


#pragma mark Copy & Paste


- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	SEL action = [menuItem action];
	
	if (action == @selector(copy:)) {
		return ([self originalImage] != nil);
	}
	else if (action == @selector(paste:)) {
		return [[self class] canImportContentsOfPasteboard:[NSPasteboard generalPasteboard]];
	}
	else {
		return YES;
	}
}


- (void)copy:(id)sender
{
	NSImage *img = [self finalAvatarImage];
	
	if (img) {
		NSPasteboard *pb = [NSPasteboard generalPasteboard];
		
		[pb declareTypes:[NSArray arrayWithObject:NSTIFFPboardType] owner:self];
		[pb setData:[img TIFFRepresentation] forType:NSTIFFPboardType];
	}
}


- (void)paste:(id)sender
{
	[self setOriginalImageFromPasteboard:[NSPasteboard generalPasteboard]];
}


#pragma mark Drag & Drop


- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
	NSDragOperation result = NSDragOperationNone;
	
	if ([[self class] canImportContentsOfPasteboard:[sender draggingPasteboard]]) {
		result = NSDragOperationCopy;
	}
	
	if (result != NSDragOperationNone) {
		// Provide visual feedback
		m_displayDropAcceptableFeedback = YES;
		[self setNeedsDisplay:YES];
	}
	
	return result;
}


- (void)draggingExited:(id <NSDraggingInfo>)sender
{
	m_displayDropAcceptableFeedback = NO;
	[self setNeedsDisplay:YES];
}


- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	m_displayDropAcceptableFeedback = NO;
	[self setNeedsDisplay:YES];
	
	[self setOriginalImageFromPasteboard:[sender draggingPasteboard]];
	return YES;
}


#pragma mark -
#pragma mark Accessors


- (NSSize)minAvatarSize
{
	return m_minAvatarSize;
}


- (void)setMinAvatarSize:(NSSize)minSize
{
	m_minAvatarSize = minSize;
	[self p_updateCropRect];
	[self p_updateImageRect];
}


- (NSSize)maxAvatarSize
{
	return m_maxAvatarSize;
}


- (void)setMaxAvatarSize:(NSSize)maxSize
{
	m_maxAvatarSize = maxSize;
	[self p_updateCropRect];
	[self p_updateImageRect];
}


- (NSImage *)originalImage
{
	return [[m_originalImage retain] autorelease];
}


- (void)setOriginalImage:(NSImage *)img
{
	[m_originalImage release];
	m_originalImage = [img retain];
	
	[self setCropRectCenterInImageScale:NSMakePoint(0.0, 0.0)];
#warning TO DO: zoom factor
	//[self setZoomFactor:0.0];
	[self zoomToFullestImageDisplayFactor];
}


+ (NSArray *)acceptedPasteboardTypes
{
	return [NSArray arrayWithObjects:
		NSFileContentsPboardType,
		NSFilenamesPboardType,
		NSPDFPboardType,
		NSTIFFPboardType,
		NSPICTPboardType,
		nil];
}


+ (BOOL)canImportContentsOfPasteboard:(NSPasteboard *)pboard
{
	BOOL result = NO;
	NSString *pboardType = [pboard availableTypeFromArray:[self acceptedPasteboardTypes]];
	
    if ([pboardType isEqualToString:NSFilenamesPboardType]) {
		NSArray *files = [pboard propertyListForType:NSFilenamesPboardType];
		if (([files count] == 1) && [[NSImage imageFileTypes] containsObject:[[files objectAtIndex:0] pathExtension]]) {
			result = YES;
		}
	}
	else if (pboardType != nil) {
		result = YES;
	}
	
	return result;
}


- (void)setOriginalImageFromPasteboard:(NSPasteboard *)pb
{
	NSString *pbType = [pb availableTypeFromArray:[[self class] acceptedPasteboardTypes]];
	NSImage *importedImage = nil;
	
	if ([pbType isEqualToString:NSTIFFPboardType] || [pbType isEqualToString:NSPDFPboardType]) {
		importedImage = [[NSImage alloc] initWithData:[pb dataForType:pbType]];
	}
	else if ([pbType isEqualToString:NSPICTPboardType]) {
		// Imported PICT data resulted in an image that was very slow to drag around (don't ask me why),
		// so we're converting it to TIFF before importing.
		NSImage *pictImg = [[NSImage alloc] initWithData:[pb dataForType:pbType]];
		NSData *tiffRepData = [pictImg TIFFRepresentation];
		
		importedImage = [[NSImage alloc] initWithData:tiffRepData];
		
		[pictImg release];
	}
	else if ([pbType isEqualToString:NSFilenamesPboardType]) {
		NSArray *files = [pb propertyListForType:pbType];
		
		if ([files count] > 0) {
			NSString *filePath = [files objectAtIndex:0];
			
			importedImage = [[NSImage alloc] initWithContentsOfFile:filePath];
		}
	}
	else if ([pbType isEqualToString:NSFileContentsPboardType] ) {
		NSFileWrapper *fileContents = [pb readFileWrapper];
		NSData *imageData = [fileContents serializedRepresentation];
		
		importedImage = [[NSImage alloc] initWithData:imageData];
	}
	
	[self setOriginalImage:importedImage];
	[importedImage release];
}


- (NSImage *)finalAvatarImage
{
	NSRect		cropRect = [self p_cropRect];
	NSImage		*finalAvatar = [[NSImage alloc] initWithSize:NSMakeSize(NSWidth(cropRect), NSHeight(cropRect))];
	
	[finalAvatar lockFocus];
	{
		NSAffineTransform *transf = [NSAffineTransform transform];
		/* Put the origin (0, 0) at the center, just like this view does. This allows us to draw the original image
		into this cropped image using exactly the same method that the view uses to draw it. */
		[transf translateXBy:floorf(NSWidth(cropRect) / 2.0) yBy:floorf(NSHeight(cropRect) / 2.0)];
		[transf concat];
		
		// Make it high-quality for the final image
		[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
		[self p_drawScaledImage];
	}
	[finalAvatar unlockFocus];
	
	return [finalAvatar autorelease];
}


- (NSPoint)cropRectCenterInImageScale
{
	return m_cropRectCenterInImage;
}


- (void)setCropRectCenterInImageScale:(NSPoint)center
{
	m_cropRectCenterInImage = center;
	[self p_updateImageRect];
}


- (float)zoomFactor
{
	return m_zoomFactor;
}


- (void)setZoomFactor:(float)factor
{
	// Clamp the value to our valid range
	m_zoomFactor = MAX(MIN(factor, 2.0), 0.0);
	[self p_updateCropRect];
	[self p_updateImageRect];
}


- (void)zoomToFullestImageDisplayFactor
{
	NSImage *img = [self originalImage];
	float	finalZoomFactor = 1.0;
	
	if (!img) {
		finalZoomFactor = 1.0;
	}
	else {
		NSSize imageSize = [img size];
		NSSize minAvatarSize = [self minAvatarSize];
		NSSize maxAvatarSize = [self maxAvatarSize];
		
		if (imageSize.width < minAvatarSize.width && imageSize.height < minAvatarSize.height) {
			finalZoomFactor = 2.0;
		}
		else if (imageSize.width > maxAvatarSize.width && imageSize.height > maxAvatarSize.height) {
			NSSize minSize = [self maxAvatarSize];
			
			float coefficientForMinWidth		 = minSize.width  / imageSize.width;
			float coefficientForMinHeight		 = minSize.height / imageSize.height;
			float coefficientForMinImageSize	 = MIN(coefficientForMinWidth, coefficientForMinHeight);
			float coefficientForFullestImageSize = MAX(coefficientForMinWidth, coefficientForMinHeight);
			
			// zoomFactor = 0.0  =>  coef = coefficientForMinImageSize (i.e., min size)
			// zoomFactor = 1.0  =>  coef = 1.0 (i.e., natural size)
			finalZoomFactor = (coefficientForFullestImageSize - coefficientForMinImageSize)
								/ (1.0 - coefficientForMinImageSize);
		}
		else {
#warning TO DO: zoom factor
			finalZoomFactor = 1.0;
		}
	}
	
	[self setZoomFactor:finalZoomFactor];
}


@end
