//
//  LPShadedWindow.m
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
// NOTE: The shading is implemented in a similar manner to Apple's default "brushed metal" texture;
// a pattern is simply generated with the appropriate dimensions and drawn in a tiled fashion. 
//
// Whereas the brushed metal is a pattern with the same width of a window, our shading is a pattern
// with the same height as the window, and is repeated horizontally to fill the window. This is, 
// of course, much faster than using CoreGraphics to fill the entire window.
//
// It may be worth noting that the shading seems quite fast with Quartz 2D Extreme enabled (GPU
// accelerated rasterization), but this is not yet a default OS feature as of Tiger.
//
// TODO: Allow the shading to be customized?
//

#import "LPShadedWindow.h"


void _LPShadedColor1(void *info, float const *inData, float *outData);
void _LPShadedColor2(void *info, float const *inData, float *outData);


@implementation LPShadedWindow


#pragma mark -
#pragma mark NSWindow Overrides


- (void)setFrame:(NSRect)frameRect display:(BOOL)flag
{			
	if ([self styleMask] & NSTexturedBackgroundWindowMask)
		[self _updateBackgroundForSize:frameRect.size];
	
	[super setFrame:frameRect display:flag];
}


#pragma mark -
#pragma mark Private Methods


- (void)_updateBackgroundForSize:(NSSize) size
{
	// Initialize our shading pattern image with the appropriate size (namely, the window
	// height for a vertical gradient).
	NSImage *shadingImage = [[NSImage alloc] initWithSize:NSMakeSize(1, size.height)];

	// Draw into the shading image.
	[shadingImage lockFocus];
	{
		CGColorSpaceRef grayscaleColorspace = CGColorSpaceCreateDeviceGray();
		
		CGContextRef context;
		CGFunctionRef function1, function2;
		CGShadingRef shading1, shading2;
		CGFunctionCallbacks callbacks1 = { 0, _LPShadedColor1, NULL };
		CGFunctionCallbacks callbacks2 = { 0, _LPShadedColor2, NULL };
		
		// Prepare CoreGraphics data structures.
		context = (CGContextRef) [[NSGraphicsContext currentContext] graphicsPort];
		
		// Create the callback function.
		function1 = CGFunctionCreate(NULL, 1, NULL, 2, NULL, &callbacks1);
		function2 = CGFunctionCreate(NULL, 1, NULL, 2, NULL, &callbacks2);
		
		// Define the shadings.
		shading1 = CGShadingCreateAxial(grayscaleColorspace,
										CGPointMake(0.0, size.height - 90.0),
										CGPointMake(0.0, size.height),
										function1,
										true,
										true);
		shading2 = CGShadingCreateAxial(grayscaleColorspace,
										CGPointMake(0.0, 0.0),
										CGPointMake(0.0, 40.0),
										function2,
										true,
										false);
		
		// Draw.
		CGContextDrawShading(context, shading1);
		CGContextDrawShading(context, shading2);
		
		// Clean up.
		CGShadingRelease(shading1);
		CGShadingRelease(shading2);
		CGFunctionRelease(function1);
		CGFunctionRelease(function2);
		CGColorSpaceRelease(grayscaleColorspace);
		
	}
	[shadingImage unlockFocus];
	
	[self setBackgroundColor:[NSColor colorWithPatternImage:shadingImage]];
	[shadingImage release];
}


@end


#pragma mark -
#pragma mark CGShading Callback


void _LPShadedColor1(void *info, float const *inData, float *outData)
{
	outData[0] = (inData[0] * 0.27) + 0.63;
	outData[1] = 1.0;
}

void _LPShadedColor2(void *info, float const *inData, float *outData)
{
	outData[0] = (inData[0] * 0.24) + 0.39;
	outData[1] = 1.0;
}
