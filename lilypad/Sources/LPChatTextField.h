//
//  LPChatTextField.h
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>
#import "LPGrowingTextField.h"

@interface LPChatTextField : LPGrowingTextField
{
	id m_customFieldEditor;
}
- (id)customFieldEditor;
@end


@interface NSObject (LPChatTextFieldDelegate)
- (BOOL)chatTextFieldShouldSupportFileDrops:(LPChatTextField *)tf;
- (BOOL)chatTextField:(LPChatTextField *)tf sendFileWithPathname:(NSString *)filepath;
@end
