//
//  SKPreferenceController.m
//  Skim
//
//  Created by Christiaan Hofman on 2/10/07.
/*
 This software is Copyright (c) 2007-2008
 Christiaan Hofman. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Christiaan Hofman nor the names of any
    contributors may be used to endorse or promote products derived
    from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SKPreferenceController.h"
#import "SKStringConstants.h"
#import "NSUserDefaultsController_SKExtensions.h"
#import "SKApplicationController.h"
#import "SKLineWell.h"
#import "NSView_SKExtensions.h"
#import <Sparkle/Sparkle.h>

#define INITIAL_USER_DEFAULTS_FILENAME  @"InitialUserDefaults"
#define RESETTABLE_KEYS_KEY             @"ResettableKeys"

static float SKDefaultFontSizes[] = {8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 16.0, 18.0, 20.0, 24.0, 28.0, 32.0, 48.0, 64.0};
static NSString *SKTeXEditors[] = {@"TextMate", @"BBEdit", @"TextWrangler", @"Emacs", @"Aquamacs Emacs", @"LyX"};
static NSString *SKTeXEditorCommands[] = {@"mate", @"bbedit", @"edit", @"emacsclient", @"emacsclient", @"lyxeditor"};
static NSString *SKTeXEditorArguments[] = {@"-l %line \"%file\"", @"+%line \"%file\"", @"+%line \"%file\"", @"--no-wait +%line \"%file\"", @"--no-wait +%line \"%file\"", @"\"%file\" %line"};

static NSString *SKPreferenceWindowFrameAutosaveName = @"SKPreferenceWindow";

@implementation SKPreferenceController

+ (id)sharedPrefenceController {
    static SKPreferenceController *sharedPrefenceController = nil;
    if (sharedPrefenceController == nil)
        sharedPrefenceController = [[self alloc] init];
    return sharedPrefenceController;
}

- (id)init {
    if (self = [super init]) {
        NSString *initialUserDefaultsPath = [[NSBundle mainBundle] pathForResource:INITIAL_USER_DEFAULTS_FILENAME ofType:@"plist"];
        resettableKeys = [[[NSDictionary dictionaryWithContentsOfFile:initialUserDefaultsPath] valueForKey:RESETTABLE_KEYS_KEY] retain];
        
        NSMutableArray *tmpFonts = [NSMutableArray array];
        NSMutableArray *fontNames = [[[[NSFontManager sharedFontManager] availableFontFamilies] mutableCopy] autorelease];
        NSEnumerator *fontEnum;
        NSString *fontName;
        
        [fontNames sortUsingSelector:@selector(caseInsensitiveCompare:)];
        fontEnum = [fontNames objectEnumerator];
        while (fontName = [fontEnum nextObject]) {
            NSFont *font = [NSFont fontWithName:fontName size:0.0];
            [tmpFonts addObject:[NSDictionary dictionaryWithObjectsAndKeys:[font fontName], @"fontName", [font displayName], @"displayName", nil]];
        }
        fonts = [tmpFonts copy];
        
        sud = [NSUserDefaults standardUserDefaults];
        sudc = [NSUserDefaultsController sharedUserDefaultsController];
        [sudc addObserver:self forKey:SKDefaultPDFDisplaySettingsKey];
        [sudc addObserver:self forKey:SKDefaultFullScreenPDFDisplaySettingsKey];
    }
    return self;
}

- (void)dealloc {
    [sudc removeObserver:self forKey:SKDefaultPDFDisplaySettingsKey];
    [sudc removeObserver:self forKey:SKDefaultFullScreenPDFDisplaySettingsKey];
    [resettableKeys release];
    [fonts release];
    [super dealloc];
}

- (NSString *)windowNibName {
    return @"PreferenceWindow";
}

- (void)updateRevertButtons {
    NSDictionary *initialValues = [sudc initialValues];
    [revertPDFSettingsButton setEnabled:[[initialValues objectForKey:SKDefaultPDFDisplaySettingsKey] isEqual:[sud dictionaryForKey:SKDefaultPDFDisplaySettingsKey]] == NO];
    [revertFullScreenPDFSettingsButton setEnabled:[[initialValues objectForKey:SKDefaultFullScreenPDFDisplaySettingsKey] isEqual:[sud dictionaryForKey:SKDefaultFullScreenPDFDisplaySettingsKey]] == NO];
}

#define VALUES_KEY_PATH(key) [@"values." stringByAppendingString:key]

- (void)windowDidLoad {
    [self setWindowFrameAutosaveName:SKPreferenceWindowFrameAutosaveName];
    
    NSString *editorPreset = [sud stringForKey:SKTeXEditorPresetKey];
    int i = sizeof(SKTeXEditors) / sizeof(NSString *);
    int index = -1;
    
    while (i--) {
        [texEditorPopUpButton insertItemWithTitle:SKTeXEditors[i] atIndex:0];
        if ([SKTeXEditors[i] isEqualToString:editorPreset])
            index = i;
    }
    
    [self setCustomTeXEditor:index == -1];
    
    if (isCustomTeXEditor)
        [texEditorPopUpButton selectItem:[texEditorPopUpButton lastItem]];
    else
        [texEditorPopUpButton selectItemAtIndex:index];
    
    [self updateRevertButtons];
    
    [textLineWell bind:@"lineWidth" toObject:sudc withKeyPath:VALUES_KEY_PATH(SKFreeTextNoteLineWidthKey) options:nil];
    [textLineWell bind:@"style" toObject:sudc withKeyPath:VALUES_KEY_PATH(SKFreeTextNoteLineStyleKey) options:nil];
    [textLineWell bind:@"dashPattern" toObject:sudc withKeyPath:VALUES_KEY_PATH(SKFreeTextNoteDashPatternKey) options:nil];
    [textLineWell setDisplayStyle:SKLineWellDisplayStyleRectangle];
    
    [circleLineWell bind:@"lineWidth" toObject:sudc withKeyPath:VALUES_KEY_PATH(SKCircleNoteLineWidthKey) options:nil];
    [circleLineWell bind:@"style" toObject:sudc withKeyPath:VALUES_KEY_PATH(SKCircleNoteLineStyleKey) options:nil];
    [circleLineWell bind:@"dashPattern" toObject:sudc withKeyPath:VALUES_KEY_PATH(SKCircleNoteDashPatternKey) options:nil];
    [circleLineWell setDisplayStyle:SKLineWellDisplayStyleOval];
    
    [boxLineWell bind:@"lineWidth" toObject:sudc withKeyPath:VALUES_KEY_PATH(SKSquareNoteLineWidthKey) options:nil];
    [boxLineWell bind:@"style" toObject:sudc withKeyPath:VALUES_KEY_PATH(SKSquareNoteLineStyleKey) options:nil];
    [boxLineWell bind:@"dashPattern" toObject:sudc withKeyPath:VALUES_KEY_PATH(SKSquareNoteDashPatternKey) options:nil];
    [boxLineWell setDisplayStyle:SKLineWellDisplayStyleRectangle];
    
    [lineLineWell bind:@"lineWidth" toObject:sudc withKeyPath:VALUES_KEY_PATH(SKLineNoteLineWidthKey) options:nil];
    [lineLineWell bind:@"style" toObject:sudc withKeyPath:VALUES_KEY_PATH(SKLineNoteLineStyleKey) options:nil];
    [lineLineWell bind:@"dashPattern" toObject:sudc withKeyPath:VALUES_KEY_PATH(SKLineNoteDashPatternKey) options:nil];
    [lineLineWell bind:@"startLineStyle" toObject:sudc withKeyPath:VALUES_KEY_PATH(SKLineNoteStartLineStyleKey) options:nil];
    [lineLineWell bind:@"endLineStyle" toObject:sudc withKeyPath:VALUES_KEY_PATH(SKLineNoteEndLineStyleKey) options:nil];
}

- (void)windowDidResignMain:(NSNotification *)notification {
    [[[self window] contentView] deactivateColorAndLineWells];
}

- (void)windowWillClose:(NSNotification *)notification {
    // make sure edits are committed
    if ([[[self window] firstResponder] isKindOfClass:[NSText class]] && [[self window] makeFirstResponder:[self window]] == NO)
        [[self window] endEditingFor:nil];
}

- (void)tabView:(NSTabView *)tabView willSelectTabViewItem:(NSTabViewItem *)tabViewItem {
    // make sure edits are committed
    if ([[[self window] firstResponder] isKindOfClass:[NSText class]] && [[self window] makeFirstResponder:[self window]] == NO)
        [[self window] endEditingFor:nil];
}

- (NSArray *)fonts {
    return fonts;
}

- (unsigned)countOfSizes {
    return sizeof(SKDefaultFontSizes) / sizeof(float);
}

- (id)objectInSizesAtIndex:(unsigned)index {
    return [NSNumber numberWithFloat:SKDefaultFontSizes[index]];
}

- (BOOL)isCustomTeXEditor {
    return isCustomTeXEditor;
}

- (void)setCustomTeXEditor:(BOOL)flag {
    isCustomTeXEditor = flag;
}

- (IBAction)changeDiscreteThumbnailSizes:(id)sender {
    if ([sender state] == NSOnState) {
        [thumbnailSizeSlider setNumberOfTickMarks:8];
        [snapshotSizeSlider setNumberOfTickMarks:8];
        [thumbnailSizeSlider setAllowsTickMarkValuesOnly:YES];
        [snapshotSizeSlider setAllowsTickMarkValuesOnly:YES];
    } else {
        [[thumbnailSizeSlider superview] setNeedsDisplayInRect:[thumbnailSizeSlider frame]];
        [[snapshotSizeSlider superview] setNeedsDisplayInRect:[snapshotSizeSlider frame]];
        [thumbnailSizeSlider setNumberOfTickMarks:0];
        [snapshotSizeSlider setNumberOfTickMarks:0];
        [thumbnailSizeSlider setAllowsTickMarkValuesOnly:NO];
        [snapshotSizeSlider setAllowsTickMarkValuesOnly:NO];
    }
    [thumbnailSizeSlider sizeToFit];
    [snapshotSizeSlider sizeToFit];
}

- (IBAction)changeUpdateInterval:(id)sender {
    int checkInterval = [[sender selectedItem] tag];
    if (checkInterval)
       [[SUUpdater sharedUpdater] scheduleCheckWithInterval:checkInterval];
}

- (IBAction)changeTeXEditorPreset:(id)sender {
    int index = [sender indexOfSelectedItem];
    if (index < [sender numberOfItems] - 1) {
        [sud setObject:[sender titleOfSelectedItem] forKey:SKTeXEditorPresetKey];
        [sud setObject:SKTeXEditorCommands[index] forKey:SKTeXEditorCommandKey];
        [sud setObject:SKTeXEditorArguments[index] forKey:SKTeXEditorArgumentsKey];
        [self setCustomTeXEditor:NO];
    } else {
        [sud setObject:@"" forKey:SKTeXEditorPresetKey];
        [self setCustomTeXEditor:YES];
    }
}

- (IBAction)revertPDFViewSettings:(id)sender {
    [sudc revertToInitialValueForKey:SKDefaultPDFDisplaySettingsKey];
}

- (IBAction)revertFullScreenPDFViewSettings:(id)sender {
    [sudc revertToInitialValueForKey:SKDefaultFullScreenPDFDisplaySettingsKey];
}

- (void)resetSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
    if (returnCode == NSAlertDefaultReturn) {
        NSString *tabID = (NSString *)contextInfo;
        NSArray *keys = tabID ? [resettableKeys objectForKey:tabID] : nil;
        if (tabID)
            [sudc revertToInitialValuesForKeys:keys];
        else
            [sudc revertToInitialValues:nil];
        if (tabID == nil || [keys containsObject:SUScheduledCheckIntervalKey]) {
            int checkInterval = [sud integerForKey:SUScheduledCheckIntervalKey];
            if (checkInterval)
               [[SUUpdater sharedUpdater] scheduleCheckWithInterval:checkInterval];
        }
    }
}

- (IBAction)resetAll:(id)sender {
    NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Reset all preferences to their original values?", @"Message in alert dialog when pressing Reset All button") 
                                     defaultButton:NSLocalizedString(@"Reset", @"Button title")
                                   alternateButton:NSLocalizedString(@"Cancel", @"Button title")
                                       otherButton:nil
                         informativeTextWithFormat:NSLocalizedString(@"Choosing Reset will restore all settings to the state they were in when Skim was first installed.", @"Informative text in alert dialog when pressing Reset All button")];
    [alert beginSheetModalForWindow:[self window]
                      modalDelegate:self
                     didEndSelector:@selector(resetSheetDidEnd:returnCode:contextInfo:)
                        contextInfo:NULL];
}

- (IBAction)resetCurrent:(id)sender {
    NSString *label = [[tabView selectedTabViewItem] label];
    NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Reset %@ preferences to their original values?", @"Message in alert dialog when pressing Reset All button"), label]
                                     defaultButton:NSLocalizedString(@"Reset", @"Button title")
                                   alternateButton:NSLocalizedString(@"Cancel", @"Button title")
                                       otherButton:nil
                         informativeTextWithFormat:NSLocalizedString(@"Choosing Reset will restore all settings in this pane to the state they were in when Skim was first installed.", @"Informative text in alert dialog when pressing Reset All button"), label];
    [alert beginSheetModalForWindow:[self window]
                      modalDelegate:self
                     didEndSelector:@selector(resetSheetDidEnd:returnCode:contextInfo:)
                        contextInfo:[[tabView selectedTabViewItem] identifier]];
}

#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (object == sudc && [keyPath hasPrefix:@"values."]) {
        NSString *key = [keyPath substringFromIndex:7];
        if ([key isEqualToString:SKDefaultPDFDisplaySettingsKey] || [key isEqualToString:SKDefaultFullScreenPDFDisplaySettingsKey]) {
            [self updateRevertButtons];
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end
