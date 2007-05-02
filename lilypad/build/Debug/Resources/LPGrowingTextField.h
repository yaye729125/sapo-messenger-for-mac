//
//  LPGrowingTextField.h
//  Lilypad
//
//  Created by João Pavão on 06/06/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface LPGrowingTextField : NSTextField
{
	float	m_verticalPadding;
	BOOL	m_calculatingSize; // To avoid reentrancy issues
}
- (void)calcContentSize;
@end

@interface NSObject (LPGrowingTextFieldDelegate)
- (void)growingTextField:(LPGrowingTextField *)textField contentSizeDidChange:(NSSize)neededSize;
@end
