//
//  LPLogger.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPLogger.h"


#ifdef LP_DEBUG_LOGGER_ENABLED


#include <stdarg.h>
#include <stdio.h>
#include <unistd.h>


void _LPDebugLogInit (void)
{
#ifdef LP_DEBUG_LOGGER_LOG_FILE
	/* If a file path for logging debug output was defined, then redirect stderr and stdout to go to that file.
	This will effectively make every output written using NSLog - which is about everything in a Cocoa app,
	including the logging of exceptions - go to that file. */
	
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	FILE *outputFile = fopen(LP_DEBUG_LOGGER_LOG_FILE, "a");
	
	NSBundle *bundle = [NSBundle mainBundle];
	NSString *header = [NSString stringWithFormat:@"%@\n%@\nBundle ID: %@\nBuild: %@\nPreferred Localizations: %@\n",
		@"****************************************",
		[NSDate date],
		(bundle ? [bundle objectForInfoDictionaryKey:@"CFBundleIdentifier"] : @""),
		(bundle ? [bundle objectForInfoDictionaryKey:@"CFBundleVersion"] : @""),
		(bundle ? [bundle preferredLocalizations] : @"")];
	
	fprintf(outputFile, "\n\n%s\n", [header UTF8String]);
	
	// Redirect stderr and stdout to write to this file
	dup2(fileno(outputFile), STDOUT_FILENO);
	dup2(fileno(outputFile), STDERR_FILENO);
	fclose(outputFile);
	
	[pool release];
	
#endif	// LP_DEBUG_LOGGER_LOG_FILE
}


void _LPDebugLog (BOOL do_write, NSString *fmt, ...)
{
	if (do_write) {
		va_list args;
		
		va_start(args, fmt);
		NSLogv(fmt, args);
		va_end(args);
	}
}


#endif	// LP_DEBUG_LOGGER_ENABLED

