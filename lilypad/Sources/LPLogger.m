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


/*
 * Logging debug output to the file at the pathname LP_DEBUG_LOGGER_LOG_FILE can be enabled by setting
 * the user defaults key "DebugLoggingToFileEnabled" to TRUE.
 *
 * Both stdout and stderr are being used as the destination for debugging messages throughout the app:
 *    - stderr is naturally used by Cocoa's error and exception logging facilities, including our own use of
 *      the NSLog() functions.
 *    - stdout is being used for the verbose output from the core, which can be used to understand what's happening
 *      inside the app at any given moment in time.
 *
 * If logging debug output to a file is enabled, then we redirect stdout and stderr to go to that file. If logging
 * to a file is not enabled, then we keep stderr as it is so that we get errors and exceptions logged in the system
 * console, and we redirect stdout to /dev/null so that all the unnecessary verbose output gets dumped.
 */


#import "LPLogger.h"

#include <stdarg.h>
#include <stdio.h>
#include <unistd.h>


// We override the write() function of the stream used for the core verbose output so that we can add
// a timestamp to the messages being written.
static int logger_writefn(void *cookie, const char *buf, int nbytes)
{
	static BOOL startingNewLine = TRUE;
	
	if (startingNewLine) {
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		fprintf((FILE *)cookie, "%s",
				[[[NSDate date] descriptionWithCalendarFormat:@"%Y-%m-%d %H:%M:%S.%F " timeZone:nil locale:nil] UTF8String]);
		[pool release];
	}
	
	startingNewLine = ((nbytes > 0) ? (buf[nbytes - 1] == '\n') : startingNewLine);
	
	return write(fileno((FILE *)cookie), buf, nbytes);
}

static int logger_closefn(void *cookie)
{
	return fclose((FILE *)cookie);
}



void LPDebugLogInit (void)
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	BOOL logToFileEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"DebugLoggingToFileEnabled"];
	
	if (logToFileEnabled) {
		FILE *debug_log = fopen(LP_DEBUG_LOGGER_LOG_FILE, "a");
		
		fclose(stdout);
		// The stream being open next will become stdout
		funopen((void *)debug_log, NULL, logger_writefn, NULL, logger_closefn);
		
		freopen(LP_DEBUG_LOGGER_LOG_FILE, "a", stderr);
		
		/*
		 * Set both of the streams to unbuffered mode.
		 *
		 * The core uses printf(...) in some places and fprintf(stderr, ...) in others. Due to this non-discriminate
		 * interleaving of the write operations to both of the output streams, if block buffering is used on stdout
		 * and/or stderr, then the messages will not be dumped to the file in the exact same order that the *printf()
		 * function calls were made. We're logging a stream of debugging/error messages here, so order is important!
		 */
		setvbuf(debug_log, NULL, _IONBF, 0);
		setvbuf(stdout, NULL, _IONBF, 0);
		setvbuf(stderr, NULL, _IONBF, 0);
		
		NSBundle *bundle = [NSBundle mainBundle];
		NSString *header = [NSString stringWithFormat:@"%@\n%@\nBundle ID: %@\nBuild: %@\nPreferred Localizations: %@\n",
			@"****************************************",
			[NSDate date],
			(bundle ? [bundle objectForInfoDictionaryKey:@"CFBundleIdentifier"] : @""),
			(bundle ? [bundle objectForInfoDictionaryKey:@"CFBundleVersion"] : @""),
			(bundle ? [bundle preferredLocalizations] : @"")];
		
		// Use the original debug_log stream to avoid getting the timestamps from our overriden write() function.
		fprintf(debug_log, "\n\n\n%s\n", [header UTF8String]);
	}
	else {
		/*
		 * Dump all debugging output coming from the core to /dev/null.
		 * The core is using stdout as the output stream for these messages.
		 * We want stderr to behave normally so that Cocoa exceptions and other errors get logged to the console as usual.
		 */
		freopen("/dev/null", "a", stdout);
	}
	
	[pool release];
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

