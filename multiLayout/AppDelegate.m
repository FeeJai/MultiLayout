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

//TODO: Combine Name and LocationID in Preferences

@implementation AppDelegate

#pragma mark - Event Tap

//The Tap is necessary for the first character to be displayed in the correct keyboard layout and to disable keyboard inputs

bool dontForwardTap = false;

CGEventRef myCGEventCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
    
    /* if (CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode) == 0x0B) {
     CGEventSetIntegerValueField(event, kCGKeyboardEventKeycode, 0x09);
     } */
    
    //NSLog(@"Event Tap: %d", (int) CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode));

    if (dontForwardTap)
        return nil;
    else
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
    TISInputSourceRef layout = (TISInputSourceRef) [keyboardLayouts objectAtIndex:[sender tag]];

    //Manual Selection vs. Keyboard list
    
    if([[[sender menu] title] intValue] == 0) {
        
        automaticSwitching = false;
        [self selectLayout:(TISInputSourceRef) [keyboardLayouts objectAtIndex:[sender tag]]];
        NSLog(@"Layout %@ manually slected",TISGetInputSourceProperty(layout,kTISPropertyInputSourceID));

    } else {
        
        NSString * key = [NSString stringWithFormat:@"%@-layout",[[sender menu] title]];
        [preferences setInteger:[sender tag] forKey:key];

        [self selectLayout:(TISInputSourceRef) [keyboardLayouts objectAtIndex:[sender tag]]];

        NSLog(@"Layout %@ selected for Keyboard: %@",TISGetInputSourceProperty(layout,kTISPropertyInputSourceID),[[sender menu] title]);
        
    }
    
    [self updateMenu];
    
}

- (void) disabledClicked: (NSMenuItem *)sender
{
    dontForwardTap = false; //Is automatically set once button is pressed
    
    NSString * key = [NSString stringWithFormat:@"%@-disabled",[[sender menu] title]];
    
    if([preferences boolForKey:key])
        [preferences setBool:false forKey:key];
    else
        [preferences setBool:true forKey:key];

    [self updateMenu];

}

- (void) openKeyboardPrefs:(id)sender {
    [[NSWorkspace sharedWorkspace] openFile:@"/System/Library/PreferencePanes/Keyboard.prefPane"];
}


- (void) openLocalizationPrefs:(id)sender {
    [[NSWorkspace sharedWorkspace] openFile:@"/System/Library/PreferencePanes/Localization.prefPane"];
}


- (void) openCharacterViewer:(id)sender {
    [[NSWorkspace sharedWorkspace] openFile:@"/System/Library/Input Methods/CharacterPalette.app"];
}


- (void) openKeyboardViewer:(id)sender {
    
    NSArray* apps = [NSRunningApplication
                     runningApplicationsWithBundleIdentifier:@"com.apple.KeyboardViewer"];
    if([apps count])
        [apps makeObjectsPerformSelector:@selector(terminate)];
    else
    //[[NSWorkspace sharedWorkspace] openFile:@"/System/Library/Input Methods/KeyboardViewer.app"];
        [[NSWorkspace sharedWorkspace] launchAppWithBundleIdentifier:@"com.apple.KeyboardViewer" options:NSWorkspaceLaunchDefault additionalEventParamDescriptor:NULL launchIdentifier:NULL];

}

- (void) startOnLoginClicked:(id)sender {
    if ([self isAppLoginItem]) {
        [self deleteAppFromLoginItem];
    } else {
        [self addAppAsLoginItem];
    }
    
    [self updateMenu];
}

- (void) aboutClicked:(id)sender {
    [panel makeKeyAndOrderFront:sender];
    [NSApp activateIgnoringOtherApps:YES];
}


- (void) quitApplication:(id)sender {
    [NSApp terminate:self];
}


- (NSMenu *) getSubmenuForKeyboard:(DDHidKeyboard *) current_keyboard {
    
    NSMenu * submenu = [[NSMenu alloc] initWithTitle:[NSString stringWithFormat:@"%ld",[current_keyboard locationId]]];
    
    //Nil for Manual Settings
    if (current_keyboard != nil) {
        NSMenuItem * disableditem = [submenu addItemWithTitle:@"Disabled" action:@selector(disabledClicked:)  keyEquivalent:@""];
        [submenu addItem:[NSMenuItem separatorItem]];
        
        if([preferences boolForKey:[NSString stringWithFormat:@"%ld-disabled",[current_keyboard locationId]]])
            [disableditem setState:NSOnState];
        else
            [disableditem setState:NSOffState];
    }
    
    int j = 0;
    for (id cur_Layout in keyboardLayouts) {

        NSMenuItem * submenuitem = [submenu addItemWithTitle:TISGetInputSourceProperty((TISInputSourceRef) cur_Layout,kTISPropertyLocalizedName) action:@selector(itemClicked:) keyEquivalent:@""];
        [submenuitem setTag:j++];
        
        //Get the correct flag in front of the Keyboard Layout
        NSImage* image = [[NSImage alloc] initWithIconRef:TISGetInputSourceProperty((TISInputSourceRef)cur_Layout, kTISPropertyIconRef)];
        
        if(image) {
            [image setSize:NSMakeSize (16, 16)];
            [submenuitem setImage:image];
        }
        
        //Checkmark the current Keyboard
        if(automaticSwitching == false && current_keyboard == nil) { //Manual Switching
            
            if(currentLayout == (TISInputSourceRef) cur_Layout)
                [submenuitem setState:NSOnState];
            else
                [submenuitem setState:NSOffState];
            
        } else if(current_keyboard != nil) {
            
            NSString * key = [NSString stringWithFormat:@"%d-layout",[current_keyboard locationId]];
            NSInteger index = [preferences integerForKey:key];

            if ([submenuitem tag] == index) 
                [submenuitem setState:NSOnState];
            else
                [submenuitem setState:NSOffState];

        }
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
    
    
    //Show Checkmark if App starts on Login
    if ([self isAppLoginItem])
        [startOnLoginItem setState:NSOnState];
    else
        [startOnLoginItem setState:NSOffState];
    
    //Select Proper Icon:
    NSImage* image = [[NSImage alloc] initWithIconRef:TISGetInputSourceProperty(currentLayout, kTISPropertyIconRef)];
    
    if(image) {
        [image setSize:NSMakeSize (16, 16)];

        if (dontForwardTap == true) {
            NSFont *thickFont = [NSFont fontWithName:@"Verdana-Bold" size:11];
            
            NSDictionary *attrs = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:thickFont,
                                                                       [NSColor greenColor],
                                                                       nil]
                                                              forKeys:[NSArray arrayWithObjects:NSFontAttributeName,
                                                                       NSForegroundColorAttributeName,
                                                                       nil]];
            [image lockFocus];
            [[NSString stringWithString:@"X"] drawAtPoint: NSMakePoint(8, 0) withAttributes: attrs];
            [image unlockFocus];
        } else if (automaticSwitching == true) {
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


#pragma mark - Application and Cocoa Stuff


-(void) addAppAsLoginItem{
	NSString * appPath = [[NSBundle mainBundle] bundlePath];
    
	// This will retrieve the path for the application
	// For example, /Applications/test.app
	CFURLRef url = (CFURLRef)[NSURL fileURLWithPath:appPath]; 
    
	// Create a reference to the shared file list.
    // We are adding it to the current user only.
    // If we want to add it all users, use
    // kLSSharedFileListGlobalLoginItems instead of
    //kLSSharedFileListSessionLoginItems
	LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL,
                                                            kLSSharedFileListSessionLoginItems, NULL);
	if (loginItems) {
		//Insert an item to the list.
		LSSharedFileListItemRef item = LSSharedFileListInsertItemURL(loginItems,
                                                                     kLSSharedFileListItemLast, NULL, NULL,
                                                                     url, NULL, NULL);
		if (item){
			CFRelease(item);
        }
	}	
    
	CFRelease(loginItems);
}

-(void) deleteAppFromLoginItem {
	NSString * appPath = [[NSBundle mainBundle] bundlePath];
    
	// This will retrieve the path for the application
	// For example, /Applications/test.app
	CFURLRef url = (CFURLRef)[NSURL fileURLWithPath:appPath]; 
    
	// Create a reference to the shared file list.
	LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL,
                                                            kLSSharedFileListSessionLoginItems, NULL);
    
	if (loginItems) {
		UInt32 seedValue;
		//Retrieve the list of Login Items and cast them to
		// a NSArray so that it will be easier to iterate.
		NSArray  *loginItemsArray = (NSArray *)LSSharedFileListCopySnapshot(loginItems, &seedValue);
        
		for(int i = 0; i< [loginItemsArray count]; i++){
			LSSharedFileListItemRef itemRef = (LSSharedFileListItemRef)[loginItemsArray
                                                                        objectAtIndex:i];
			//Resolve the item with URL
			if (LSSharedFileListItemResolve(itemRef, 0, (CFURLRef*) &url, NULL) == noErr) {
				NSString * urlPath = [(NSURL*)url path];
				if ([urlPath compare:appPath] == NSOrderedSame){
					LSSharedFileListItemRemove(loginItems,itemRef);
				}
			}
		}
		[loginItemsArray release];
	}
}

-(bool) isAppLoginItem {
	NSString * appPath = [[NSBundle mainBundle] bundlePath];
    
	// This will retrieve the path for the application
	// For example, /Applications/test.app
	CFURLRef url = (CFURLRef)[NSURL fileURLWithPath:appPath]; 
    
	// Create a reference to the shared file list.
	LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL,
                                                            kLSSharedFileListSessionLoginItems, NULL);
    bool value = false;
    
	if (loginItems) {
		UInt32 seedValue;
		//Retrieve the list of Login Items and cast them to
		// a NSArray so that it will be easier to iterate.
		NSArray  *loginItemsArray = (NSArray *)LSSharedFileListCopySnapshot(loginItems, &seedValue);
        
		for(int i = 0; i< [loginItemsArray count]; i++){
			LSSharedFileListItemRef itemRef = (LSSharedFileListItemRef)[loginItemsArray
                                                                        objectAtIndex:i];
			//Resolve the item with URL
			if (LSSharedFileListItemResolve(itemRef, 0, (CFURLRef*) &url, NULL) == noErr) {
				NSString * urlPath = [(NSURL*)url path];
				if ([urlPath compare:appPath] == NSOrderedSame){
					value = true;				}
			}
		}
		[loginItemsArray release];
	}
    return value;
}


- (void)dealloc
{
    [preferences synchronize];
    [preferences release];
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
    preferences = [[NSUserDefaults standardUserDefaults] retain];
    
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
    
    timer = [NSTimer scheduledTimerWithTimeInterval: 7.5 
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
    
    
    //If Keyboard disabled, tell CGEventTap not to forward the Keystroke and do not switch the Layout
    if([preferences boolForKey:[NSString stringWithFormat:@"%ld-disabled",[keyboard locationId]]]) {

        dontForwardTap = true;
        lastUsedKeyboard = nil;
        [self updateMenu];
        
    } else if (automaticSwitching == true && keyboard != lastUsedKeyboard) {
        
        dontForwardTap = false;
        lastUsedKeyboard = keyboard;
        
        
        NSString * key = [NSString stringWithFormat:@"%d-layout",[keyboard locationId]];
        NSInteger index = [preferences integerForKey:key];
        
        [self selectLayout:(TISInputSourceRef) [keyboardLayouts objectAtIndex:index]];

        [self updateMenu];

    } else if (automaticSwitching == false) {
        
        dontForwardTap = false;
        lastUsedKeyboard = nil;
        
    } else {
        dontForwardTap = false;
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
