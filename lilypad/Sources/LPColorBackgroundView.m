//
//  LPColorBackgroundView.m
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPColorBackgroundView.h"


static void
LPShadedColorFunc (void *info, const float *inValues, float *outValues)
{
	float *colorComponents = (float *)info;
	
	float r_min = colorComponents[0];
	float g_min = colorComponents[1];
	float b_min = colorComponents[2];
	float a_min = colorComponents[3];
	
	float r_delta = colorComponents[4] - r_min;
	float g_delta = colorComponents[5] - g_min;
	float b_delta = colorComponents[6] - b_min;
	float a_delta = colorComponents[7] - a_min;
	
	outValues[0] = r_min + (inValues[0] * r_delta);
	outValues[1] = g_min + (inValues[0] * g_delta);
	outValues[2] = b_min + (inValues[0] * b_delta);
	outValues[3] = a_min + (inValues[0] * a_delta);
}


@implementation LPColorBackgroundView

- (id)initWithFrame:(NSRect)frame
{
    if (self = [super initWithFrame:frame]) {
		m_shadingOrientation = LPNoBackgroundShading;
		m_bgColor = [[NSColor whiteColor] retain];
    }
    return self;
}

- (void)dealloc
{
	[m_bgColor release];
	[m_minEdgeShadingRGBColor release];
	[m_maxEdgeShadingRGBColor release];
	[m_borderColor release];
	[super dealloc];
}

- (NSColor *)backgroundColor
{
	return [[m_bgColor copy] autorelease];
}

- (void)setBackgroundColor:(NSColor *)color
{
	if (color != m_bgColor) {
		[m_bgColor release];
		m_bgColor = [color copy];
		
		[self setNeedsDisplay:YES];
	}
}

- (LPBackgroundShadingOrientation)backgroundShadingOrientation
{
	return m_shadingOrientation;
}

- (NSColor *)minEdgeShadingColor
{
	return [[m_minEdgeShadingRGBColor copy] autorelease];
}

- (NSColor *)maxEdgeShadingColor
{
	return [[m_maxEdgeShadingRGBColor copy] autorelease];
}

- (void)setShadedBackgroundWithOrientation:(LPBackgroundShadingOrientation)orientation
							  minEdgeColor:(NSColor *)minEdgeColor
							  maxEdgeColor:(NSColor *)maxEdgeColor
{
	m_shadingOrientation = orientation;
	
	[m_minEdgeShadingRGBColor release];
	m_minEdgeShadingRGBColor = [[minEdgeColor colorUsingColorSpaceName:NSCalibratedRGBColorSpace] copy];
	
	[m_maxEdgeShadingRGBColor release];
	m_maxEdgeShadingRGBColor = [[maxEdgeColor colorUsingColorSpaceName:NSCalibratedRGBColorSpace] copy];
	
	[self setNeedsDisplay:YES];
}

- (NSColor *)borderColor
{
	return [[m_borderColor retain] autorelease];
}

- (void)setBorderColor:(NSColor *)color
{
	if (color != m_borderColor) {
		[m_borderColor release];
		m_borderColor = [color retain];
		
		[self setNeedsDisplay:YES];
	}
}

- (void)drawRect:(NSRect)rect
{
	LPBackgroundShadingOrientation orientation = [self backgroundShadingOrientation];
	
	if (orientation == LPNoBackgroundShading) {
		NSGraphicsContext *gc = [NSGraphicsContext currentContext];
		NSPoint originInWinCoord = [self convertPoint:[self bounds].origin toView:nil];
		
		[gc saveGraphicsState];
		[gc setPatternPhase:originInWinCoord];
		[[self backgroundColor] set];
		NSRectFill(rect);
		[gc restoreGraphicsState];
	}
	else {
		struct CGFunctionCallbacks callbacks = { 0, &LPShadedColorFunc, NULL };
		float  colorComponents[8];
		
		[m_minEdgeShadingRGBColor getRed:&colorComponents[0]
								   green:&colorComponents[1]
									blue:&colorComponents[2]
								   alpha:&colorComponents[3]];
		[m_maxEdgeShadingRGBColor getRed:&colorComponents[4]
								   green:&colorComponents[5]
									blue:&colorComponents[6]
								   alpha:&colorComponents[7]];
		
		NSRect				bounds			= [self bounds];
		CGColorSpaceRef		colorSpace		= CGColorSpaceCreateWithName(kCGColorSpaceUserRGB);
		CGFunctionRef		shadingFunction	= CGFunctionCreate((void *)colorComponents, 1, NULL, 4, NULL, &callbacks);
		CGShadingRef		shading			= CGShadingCreateAxial(colorSpace,
																   CGPointMake(bounds.origin.x, bounds.origin.y),
																   ( orientation == LPHorizontalBackgroundShading ?
																	 CGPointMake(NSMaxX(bounds), NSMinY(bounds)) :
																	 CGPointMake(NSMinX(bounds), NSMaxY(bounds)) ),
																   shadingFunction,
																   YES, YES);
		
		CGContextDrawShading([[NSGraphicsContext currentContext] graphicsPort], shading);
		
		CGShadingRelease(shading);
		CGFunctionRelease(shadingFunction);
		CGColorSpaceRelease(colorSpace);
	}
	
	NSColor *borderColor = [self borderColor];

	if (borderColor) {
		[borderColor set];
		NSFrameRect([self bounds]);
	}
}

@end
