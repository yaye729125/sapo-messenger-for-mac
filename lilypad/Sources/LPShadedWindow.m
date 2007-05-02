//
//  LPShadedWindow.m
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


void _LPShadedColor(void *info, float const *inData, float *outData);


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
		CGContextRef context;
		CGFunctionRef function;
		CGShadingRef shading;
		CGFunctionCallbacks callbacks = { 0, _LPShadedColor, NULL };
		
		// Prepare CoreGraphics data structures.
		context = (CGContextRef) [[NSGraphicsContext currentContext] graphicsPort];
		
		// Create the callback function.
		function = CGFunctionCreate(NULL,
									1,
									NULL,
									4,
									NULL,
									&callbacks);
		
		// Define the shading.
		shading = CGShadingCreateAxial(CGColorSpaceCreateDeviceRGB(),
									   CGPointMake(0, 0),
									   CGPointMake(0, size.height),
									   function,
									   false,
									   false);
		
		// Draw.
		CGContextDrawShading(context, shading);
		
		// Clean up.
		CGShadingRelease(shading);
		CGFunctionRelease(function);
	}
	[shadingImage unlockFocus];
	
	[self setBackgroundColor:[NSColor colorWithPatternImage:shadingImage]];
	[shadingImage release];
}


@end


#pragma mark -
#pragma mark CGShading Callback


void _LPShadedColor(void *info, float const *inData, float *outData)
{
	float value = (inData[0] * 0.25) + 0.65;

	// FIXME: Our shading is currently hardcoded.
	outData[0] = value;
	outData[1] = value;
	outData[2] = value;
	outData[3] = 1.0;
}
