//
//  LPGrowingTextField.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
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
