//
//  LPColorBackgroundView.h
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


typedef enum {
	LPNoBackgroundShading,
	LPHorizontalBackgroundShading,
	LPVerticalBackgroundShading
} LPBackgroundShadingOrientation;


@interface LPColorBackgroundView : NSView
{
	LPBackgroundShadingOrientation	m_shadingOrientation;
	
	NSColor		*m_bgColor;
	NSColor		*m_minEdgeShadingRGBColor;
	NSColor		*m_maxEdgeShadingRGBColor;
	NSColor		*m_borderColor;
}

- (NSColor *)backgroundColor;
- (void)setBackgroundColor:(NSColor *)color;
- (LPBackgroundShadingOrientation)backgroundShadingOrientation;
- (NSColor *)minEdgeShadingColor;
- (NSColor *)maxEdgeShadingColor;
- (void)setShadedBackgroundWithOrientation:(LPBackgroundShadingOrientation)orientation
							  minEdgeColor:(NSColor *)minEdgeColor
							  maxEdgeColor:(NSColor *)maxEdgeColor;
- (NSColor *)borderColor;
- (void)setBorderColor:(NSColor *)color;

@end
