//
//  AppDelegate.h
//  multiLayout
//
//  Created by Felix Jankowski on 18.11.11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>


#define MENU_INDEX_FOR_FIRST_KEYBOARD 5

@class DDHidKeyboard;


@interface AppDelegate : NSObject <NSApplicationDelegate>
{
    bool automaticSwitching;
    TISInputSourceRef currentLayout;
    
    IBOutlet NSMenu *statusMenu;
    NSStatusItem * statusItem;
    
    NSArray * keyboardLayouts;
    
    NSArray * keyboards;
    long  lastKeystroke;
    
    NSTimer * timer;
    CGEventTapProxy proxy;
}


CGEventRef myCGEventCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon);

void tap_keyboard(void);

- (IBAction) setAutomaticSwitching:(id)sender;
- (IBAction) quitApplication:(id)sender;



- (void) loadNewKeyboards: (NSArray *) new_keyboards;
- (void) updateMenu;

@end



@interface AppDelegate (DDHidKeyboardDelegate)

- (void) ddhidKeyboard: (DDHidKeyboard *) keyboard
               keyDown: (unsigned) usageId;

- (void) ddhidKeyboard: (DDHidKeyboard *) keyboard
                 keyUp: (unsigned) usageId;

@end