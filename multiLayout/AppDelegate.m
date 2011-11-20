//
//  AppDelegate.m
//  multiLayout
//
//  Created by Felix Jankowski on 18.11.11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "AppDelegate.h"

#import "DDHidLib.h"
#include <IOKit/hid/IOHIDUsageTables.h>


@implementation AppDelegate


#pragma mark - Event Tap

//The Tap is necessary for the first character to be displayed in the correct keyboard layout and to disable keyboard inputs

CGEventRef myCGEventCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
    /* if (CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode) == 0x0B) {
     CGEventSetIntegerValueField(event, kCGKeyboardEventKeycode, 0x09);
     } */
    
    //NSLog(@"Event Tap: %d", (int) CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode));

    return event;
}


void tap_keyboard(void) {
    CFRunLoopSourceRef runLoopSource;
    
    //CGEventMask mask = kCGEventMaskForAllEvents;
    //CGEventMask mask = CGEventMaskBit(kCGEventKeyUp) | CGEventMaskBit(kCGEventKeyDown);
    CGEventMask mask = CGEventMaskBit(kCGEventKeyDown);
    
    CFMachPortRef eventTap = CGEventTapCreate(kCGHIDEventTap, kCGHeadInsertEventTap, kCGEventTapOptionDefault, mask, myCGEventCallback, NULL);
    
    if (!eventTap) { 
        NSLog(@"Couldn't create event tap!");
        exit(1);
    }
    
    runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0);
    
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
    
    CGEventTapEnable(eventTap, true);
    
    CFRelease(eventTap);
    CFRelease(runLoopSource);
    
}

#pragma mark - Keyboard Layout API


- (void) selectLayout:(TISInputSourceRef) layout {
    
    NSLog(@"Switching to Layout %@",TISGetInputSourceProperty(layout,kTISPropertyInputSourceID));
    TISSelectInputSource(layout);
    currentLayout = layout;
}


- (IBAction) setAutomaticSwitching:(id)sender {
    automaticSwitching = true;
    [self updateMenu];
}

#pragma mark - Menu Stuff


- (void) itemClicked: (NSMenuItem *)sender
{
    
    NSLog(@"Layout %@ selected for Keyboard: %@",TISGetInputSourceProperty((TISInputSourceRef) [keyboardLayouts objectAtIndex:[sender tag]],kTISPropertyInputSourceID),[[sender menu] title]);
    
    if([[[sender menu] title] intValue] == 0) {
        automaticSwitching = false;
        [self selectLayout:(TISInputSourceRef) [keyboardLayouts objectAtIndex:[sender tag]]];
    }
    
    [self updateMenu];
    
}

- (void) disabledClicked: (NSMenuItem *)sender
{
    NSLog(@"Disabled clicked for Keyboard %@!\n",[[sender menu] title]);
    [self updateMenu];

}

- (void) quitApplication:(id)sender {
    exit(0);
}


- (NSMenu *) getSubmenuForKeyboard:(DDHidKeyboard *) current_keyboard {
    
    NSMenu * submenu = [[NSMenu alloc] initWithTitle:[NSString stringWithFormat:@"%ld",[current_keyboard locationId]]];
    if (current_keyboard != nil) {
        [submenu addItemWithTitle:@"Disabled" action:@selector(disabledClicked:)  keyEquivalent:@""];
        [submenu addItem:[NSMenuItem separatorItem]];
    }
    int j = 0;
    for (id cur_Layout in keyboardLayouts) {
        [[submenu addItemWithTitle:TISGetInputSourceProperty((TISInputSourceRef) cur_Layout,kTISPropertyLocalizedName) action:@selector(itemClicked:) keyEquivalent:@""] setTag:j++];
        //TODO: Enable current
    }
    
    return submenu;
}


- (void) updateMenu {
    
    //Automatic Item checked?
    if (automaticSwitching == true)
        [[statusMenu itemAtIndex:2] setState:NSOnState];
    else
        [[statusMenu itemAtIndex:2] setState:NSOffState];

    //Item for Manual Selection:
    if ([[statusMenu itemAtIndex:3] hasSubmenu]) {
        [[[statusMenu itemAtIndex:3] submenu] release];
    }
    
    [[statusMenu itemAtIndex:3] setSubmenu:[self getSubmenuForKeyboard:nil]];
    
    
    //Remove Keyboards from Menu   
    NSInteger numberOfMenuItems = [statusMenu numberOfItems];
    for (int i = MENU_INDEX_FOR_FIRST_KEYBOARD; i < numberOfMenuItems - 3; i++) {
        [statusMenu removeItemAtIndex:MENU_INDEX_FOR_FIRST_KEYBOARD];
    }

    //Add new Keyboards
    int i = MENU_INDEX_FOR_FIRST_KEYBOARD; 
    for (id current_keyboard in keyboards) { 
        //Create MenuItem
        NSMenuItem * keyboard_item = [[NSMenuItem alloc] initWithTitle:[current_keyboard productName] action:nil keyEquivalent:@""];
        
        //With Submenu
        [keyboard_item setSubmenu:[self getSubmenuForKeyboard:current_keyboard]];
        
        //Add the Keyboard Menu
        [statusMenu insertItem:keyboard_item atIndex:i++];
    }
    
    //Select Proper Icon:
    NSImage* image = [[NSImage alloc] initWithIconRef:TISGetInputSourceProperty(currentLayout, kTISPropertyIconRef)];
    
    if(image) {
        [image setSize:NSMakeSize (16, 16)];

        if (automaticSwitching == true) {
            NSFont *thickFont = [NSFont fontWithName:@"Verdana-Bold" size:11];

            NSDictionary *attrs = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:thickFont,
                                                                       [NSColor blueColor],
                                                                       nil]
                                                              forKeys:[NSArray arrayWithObjects:NSFontAttributeName,
                                                                       NSForegroundColorAttributeName,
                                                                       nil]];
            [image lockFocus];
            [[NSString stringWithString:@"A"] drawAtPoint: NSMakePoint(8, 0) withAttributes: attrs];
            [image unlockFocus];
        }
        
        [statusItem setImage:image];
        [statusItem setTitle:@""];

    } else {
        [statusItem setTitle:@"MultiLayout"];
    }

}


#pragma mark - DDHIDLib Keyboard and Init methods

- (void) loadKeyboards {
    
    NSArray * new_keyboards = [DDHidKeyboard allKeyboards];
    [new_keyboards makeObjectsPerformSelector: @selector(setDelegate:) withObject: self];

    if ([keyboards count] == [new_keyboards count]) {
        for(int i = 0; i < [keyboards count]; i++)
            if([[keyboards objectAtIndex:i] locationId] != [[new_keyboards objectAtIndex:i] locationId])
                [self loadNewKeyboards: new_keyboards];
    } else {
        [self loadNewKeyboards: new_keyboards];
    }
    
}

- (void) loadNewKeyboards: (NSArray *) new_keyboards {
    
    //Stop Listening to old Keyboards
    for (id current_keyboard in keyboards) {
        @try {
            [current_keyboard stopListening];
        }
        @catch (NSException *exception) {
            continue;
        }
    }
    [keyboards release];
    
    //Load new Keyboards
    keyboards = [new_keyboards retain];

    //Start Listening and update Menu
    NSLog(@"New Keyboards loaded:");
    for (id current_keyboard in keyboards) {
        [current_keyboard startListening];
        NSLog(@"  %@ (%lX)", [current_keyboard productName],[current_keyboard locationId]);
    }
    
    [self updateMenu];
}


#pragma mark - Application and Menu Stuff

- (void)dealloc
{
    [keyboards release];
    
    keyboards = nil;

    [super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
}

-(void)awakeFromNib 
{
    //Setup variables
    automaticSwitching = true;
    
    //Install Status Item in Menu Bae
    statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength] retain];
    [statusItem setMenu:statusMenu];
    [statusItem setTitle:@"MultiLayout"];
    [statusItem setHighlightMode:YES];
    
    
    //Load Layouts:
    CFDictionaryRef properties = (CFDictionaryRef) [NSDictionary dictionaryWithObject:@"TISTypeKeyboardLayout" forKey:(id)kTISPropertyInputSourceType];
    
    keyboardLayouts = (NSArray *) TISCreateInputSourceList(properties,false);
    NSLog(@"Keyboard Layputs available:");
    for (id cur_Layout in keyboardLayouts) {
        NSLog(@"  %@ (%@)",TISGetInputSourceProperty((TISInputSourceRef) cur_Layout,kTISPropertyLocalizedName),TISGetInputSourceProperty((TISInputSourceRef) cur_Layout,kTISPropertyInputSourceID));
        if (TISGetInputSourceProperty((TISInputSourceRef) cur_Layout,kTISPropertyInputSourceIsSelected)) {
            currentLayout = (TISInputSourceRef) cur_Layout;
        }
    }

    //Setup DDHidLib
    [self loadKeyboards];
    
    timer = [NSTimer scheduledTimerWithTimeInterval: 2.0 //7.5 
                                             target: self 
                                           selector:@selector(loadKeyboards) 
                                           userInfo: nil 
                                            repeats: YES];
    //Install EventTap
    tap_keyboard();
}


@end


#pragma mark - DDHIDLib Caller KEYBOARD SWITCHING IS DONE HERE

@implementation AppDelegate (DDHidKeyboardDelegate)

- (void) ddhidKeyboard: (DDHidKeyboard *) keyboard
keyDown: (unsigned) usageId;
{
    static DDHidKeyboard * lastUsedKeyboard;
    
    if (automaticSwitching == true && keyboard != lastUsedKeyboard) {
        lastUsedKeyboard = keyboard;
        switch ([keyboard locationId]) {
            case 0xFFFFFFFFFA120000:
                [self selectLayout: (TISInputSourceRef) [keyboardLayouts objectAtIndex:1]];
                break;
            
            case 0x40132000:
                [self selectLayout: (TISInputSourceRef) [keyboardLayouts objectAtIndex:2]];
                break;
            
            default:
                break;
        }
        [self updateMenu];
    } else if (automaticSwitching == false ){
        lastUsedKeyboard = nil;
    }
    
    
    /* DDHidUsageTables * usageTables = [DDHidUsageTables standardUsageTables];
    NSString * description = [NSString stringWithFormat: @"%@ (0x%04X)",
                              [usageTables descriptionForUsagePage: kHIDPage_KeyboardOrKeypad
                                                             usage: usageId],
                              usageId];
    
    NSLog(@"Key Down on %@(%lX): %@", [keyboard productName],[keyboard locationId], description);
    NSLog(@"DDHIDLib: %d", usageId); */

}

- (void) ddhidKeyboard: (DDHidKeyboard *) keyboard
keyUp: (unsigned) usageId;
{
    //[self addEvent: @"Key Up" forKeyboard: keyboard usageId: usageId];
}

@end

/*
    
@implementation AppDelegate (Private)

- (void) addEvent: (NSString *) event forKeyboard: (DDHidKeyboard *) keyboard usageId: (unsigned) usageId;
{
    DDHidUsageTables * usageTables = [DDHidUsageTables standardUsageTables];
    NSString * description = [NSString stringWithFormat: @"%@ (0x%04X)",
                              [usageTables descriptionForUsagePage: kHIDPage_KeyboardOrKeypad
                                                             usage: usageId],
                              usageId];
    
 
     NSMutableDictionary * row = [mKeyboardEventsController newObject];
     [row setObject: event forKey: @"event"];
     [row setObject: description forKey: @"description"];
     [mKeyboardEventsController addObject: row];test

        
    //NSLog(@"%@ : %@ %@",keyboard, event, description);
}

@end
*/
