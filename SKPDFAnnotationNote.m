//
//  SKPDFAnnotationNote.m
//  Skim
//
//  Created by Christiaan Hofman on 2/6/07.
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

#import "SKPDFAnnotationNote.h"
#import "PDFAnnotation_SKExtensions.h"
#import "PDFBorder_SKExtensions.h"
#import "SKStringConstants.h"
#import "SKFDFParser.h"
#import "NSUserDefaults_SKExtensions.h"
#import "NSGeometry_SKExtensions.h"
#import "NSString_SKExtensions.h"


unsigned long SKScriptingIconTypeFromIconType(int iconType) {
    switch (iconType) {
        case kPDFTextAnnotationIconComment: return SKScriptingTextAnnotationIconComment;
        case kPDFTextAnnotationIconKey: return SKScriptingTextAnnotationIconKey;
        case kPDFTextAnnotationIconNote: return SKScriptingTextAnnotationIconNote;
        case kPDFTextAnnotationIconHelp: return SKScriptingTextAnnotationIconHelp;
        case kPDFTextAnnotationIconNewParagraph: return SKScriptingTextAnnotationIconNewParagraph;
        case kPDFTextAnnotationIconParagraph: return SKScriptingTextAnnotationIconParagraph;
        case kPDFTextAnnotationIconInsert: return SKScriptingTextAnnotationIconInsert;
        default: return kPDFTextAnnotationIconNote;
    }
}

int SKIconTypeFromScriptingIconType(unsigned long iconType) {
    switch (iconType) {
        case SKScriptingTextAnnotationIconComment: return kPDFTextAnnotationIconComment;
        case SKScriptingTextAnnotationIconKey: return kPDFTextAnnotationIconKey;
        case SKScriptingTextAnnotationIconNote: return kPDFTextAnnotationIconNote;
        case SKScriptingTextAnnotationIconHelp: return kPDFTextAnnotationIconHelp;
        case SKScriptingTextAnnotationIconNewParagraph: return kPDFTextAnnotationIconNewParagraph;
        case SKScriptingTextAnnotationIconParagraph: return kPDFTextAnnotationIconParagraph;
        case SKScriptingTextAnnotationIconInsert: return kPDFTextAnnotationIconInsert;
        default: return kPDFTextAnnotationIconNote;
    }
}


NSString *SKPDFAnnotationIconTypeKey = @"iconType";
NSString *SKPDFAnnotationTextKey = @"text";
NSString *SKPDFAnnotationImageKey = @"image";

NSString *SKPDFAnnotationScriptingIconTypeKey = @"scriptingIconType";
NSString *SKPDFAnnotationRichTextKey = @"richText";

NSSize SKPDFAnnotationNoteSize = {16.0, 16.0};

@implementation SKPDFAnnotationNote

- (id)initNoteWithBounds:(NSRect)bounds {
    if (self = [super initNoteWithBounds:bounds]) {
        [self setShouldPrint:YES];
        [self setColor:[[NSUserDefaults standardUserDefaults] colorForKey:SKAnchoredNoteColorKey]];
        [self setIconType:[[NSUserDefaults standardUserDefaults] integerForKey:SKAnchoredNoteIconTypeKey]];
        texts = [[NSArray alloc] initWithObjects:[[[SKNoteText alloc] initWithAnnotation:self] autorelease], nil];
        textStorage = [[NSTextStorage allocWithZone:[self zone]] init];
        [textStorage setDelegate:self];
        text = [[NSAttributedString alloc] init];
    }
    return self;
}

- (void)updateContents {
    NSMutableString *contents = [NSMutableString string];
    if ([string length])
        [contents appendString:string];
    if ([text length]) {
        [contents appendString:@"  "];
        [contents appendString:[text string]];
    }
    [self setContents:contents];
}

- (id)initWithProperties:(NSDictionary *)dict{
    if (self = [super initWithProperties:dict]) {
        Class attrStringClass = [NSAttributedString class];
        Class stringClass = [NSString class];
        Class imageClass = [NSImage class];
        NSAttributedString *aText = [dict objectForKey:SKPDFAnnotationTextKey];
        NSImage *anImage = [dict objectForKey:SKPDFAnnotationImageKey];
        NSNumber *iconType = [dict objectForKey:SKPDFAnnotationIconTypeKey];
        if ([anImage isKindOfClass:imageClass])
            image = [anImage retain];
        if ([aText isKindOfClass:attrStringClass])
            [textStorage replaceCharactersInRange:NSMakeRange(0, [textStorage length]) withAttributedString:aText];
        else if ([aText isKindOfClass:stringClass])
            [textStorage replaceCharactersInRange:NSMakeRange(0, [textStorage length]) withString:(NSString *)aText];
        if ([iconType respondsToSelector:@selector(intValue)])
            [self setIconType:[iconType intValue]];
        [self updateContents];
    }
    return self;
}

- (void)dealloc {
    [textStorage release];
    [text release];
    [image release];
    [texts release];
    [super dealloc];
}

- (NSDictionary *)properties{
    NSMutableDictionary *dict = [[[super properties] mutableCopy] autorelease];
    [dict setValue:[NSNumber numberWithInt:[self iconType]] forKey:SKPDFAnnotationIconTypeKey];
    [dict setValue:[self text] forKey:SKPDFAnnotationTextKey];
    [dict setValue:[self image] forKey:SKPDFAnnotationImageKey];
    return dict;
}

- (NSString *)fdfString {
    NSMutableString *fdfString = [[[super fdfString] mutableCopy] autorelease];
    [fdfString appendFDFName:SKFDFAnnotationIconTypeKey];
    [fdfString appendFDFName:SKFDFTextAnnotationIconTypeFromPDFTextAnnotationIconType([self iconType])];
    return fdfString;
}

- (BOOL)isNote { return YES; }

- (BOOL)isMovable { return YES; }

- (BOOL)isEditable { return YES; }

- (NSString *)type {
    return SKNoteString;
}

- (NSString *)string {
    return string;
}

- (void)setString:(NSString *)newString {
    if (string != newString) {
        [string release];
        string = [newString retain];
        [self updateContents];
    }
}

- (NSImage *)image;
{
    return image;
}

- (void)setImage:(NSImage *)newImage;
{
    if (image != newImage) {
        [image release];
        image = [newImage retain];
    }
}

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key
{
    if ([key isEqualToString:SKPDFAnnotationTextKey])
        return NO;
    else
        return [super automaticallyNotifiesObserversForKey:key];
}

- (NSAttributedString *)text;
{
    return text;
}

- (void)setText:(NSAttributedString *)newText;
{
    if (textStorage != newText) {
        if (newText)
            [textStorage replaceCharactersInRange:NSMakeRange(0, [textStorage length]) withAttributedString:newText];
        else
            [textStorage deleteCharactersInRange:NSMakeRange(0, [textStorage length])];
    }
}

- (NSArray *)texts {
    return texts;
}

- (void)textStorageWillProcessEditing:(NSNotification *)notification;
{
}

- (void)textStorageDidProcessEditing:(NSNotification *)notification;
{
    [texts makeObjectsPerformSelector:@selector(willChangeValueForKey:) withObject:SKPDFAnnotationTextKey];
    [self willChangeValueForKey:SKPDFAnnotationTextKey];
    [text release];
    text = [[NSAttributedString allocWithZone:[self zone]] initWithAttributedString:textStorage];
    [self didChangeValueForKey:SKPDFAnnotationTextKey];
    [texts makeObjectsPerformSelector:@selector(didChangeValueForKey:) withObject:SKPDFAnnotationTextKey];
    [self updateContents];
}

// override these Leopard methods to avoid showing the standard tool tips over our own
- (NSString *)toolTip { return nil; }
- (NSString *)toolTipNoLabel { return nil; }

- (NSSet *)keysForValuesToObserveForUndo {
    static NSSet *noteKeys = nil;
    if (noteKeys == nil) {
        NSMutableSet *mutableKeys = [[super keysForValuesToObserveForUndo] mutableCopy];
        [mutableKeys addObject:SKPDFAnnotationIconTypeKey];
        [mutableKeys addObject:SKPDFAnnotationTextKey];
        [mutableKeys addObject:SKPDFAnnotationImageKey];
        noteKeys = [mutableKeys copy];
        [mutableKeys release];
    }
    return noteKeys;
}

#pragma mark Scripting support

+ (NSSet *)customScriptingKeys {
    static NSSet *customNoteScriptingKeys = nil;
    if (customNoteScriptingKeys == nil) {
        NSMutableSet *customKeys = [[super customScriptingKeys] mutableCopy];
        [customKeys addObject:SKPDFAnnotationScriptingIconTypeKey];
        [customKeys addObject:SKPDFAnnotationRichTextKey];
        [customKeys removeObject:SKPDFAnnotationLineWidthKey];
        [customKeys removeObject:SKPDFAnnotationScriptingBorderStyleKey];
        [customKeys removeObject:SKPDFAnnotationDashPatternKey];
        customNoteScriptingKeys = [customKeys copy];
        [customKeys release];
    }
    return customNoteScriptingKeys;
}

- (unsigned long)scriptingIconType {
    return SKScriptingIconTypeFromIconType([self iconType]);
}

- (void)setScriptingIconType:(unsigned long)type {
    [self setIconType:SKIconTypeFromScriptingIconType(type)];
}

- (id)richText;
{
    return textStorage;
}

- (void)setRichText:(id)newText;
{
    if (newText != textStorage) {
        // We are willing to accept either a string or an attributed string.
        if ([newText isKindOfClass:[NSAttributedString class]])
            [textStorage replaceCharactersInRange:NSMakeRange(0, [textStorage length]) withAttributedString:newText];
        else
            [textStorage replaceCharactersInRange:NSMakeRange(0, [textStorage length]) withString:newText];
    }
}

- (id)coerceValueForRichText:(id)value;
{
    // We want to just get Strings unchanged.  We will detect this and do the right thing in setRichText.  We do this because, this way, we will do more reasonable things about attributes when we are receiving plain text.
    if ([value isKindOfClass:[NSString class]])
        return value;
    else
        return [[NSScriptCoercionHandler sharedCoercionHandler] coerceValue:value toClass:[NSTextStorage class]];
}

#pragma mark Accessibility

- (NSArray *)accessibilityAttributeNames {
    static NSArray *attributes = nil;
    if (attributes == nil) {
        attributes = [[[super accessibilityAttributeNames] arrayByAddingObject:NSAccessibilityDescriptionAttribute] retain];
    }
    return attributes;
}

- (id)accessibilityRoleAttribute {
    return NSAccessibilityButtonRole;
}

- (id)accessibilityTitleAttribute {
    return [self string];
}

- (id)accessibilityValueAttribute {
    return [self contents];
}

- (id)accessibilityDescriptionAttribute {
    return [[self type] typeName];
}

- (id)accessibilityEnabledAttribute {
    return [NSNumber numberWithBool:YES];
}

- (NSArray *)accessibilityActionNames {
    return [NSArray arrayWithObject:NSAccessibilityPressAction];
}

@end

#pragma mark -

@interface PDFAnnotationText (SKExtensions)
@end

@implementation PDFAnnotationText (SKExtensions)

- (BOOL)isConvertibleAnnotation { return YES; }

- (id)copyNoteAnnotation {
    NSRect bounds = [self bounds];
    bounds.size = SKPDFAnnotationNoteSize;
    SKPDFAnnotationNote *annotation = [[SKPDFAnnotationNote alloc] initNoteWithBounds:bounds];
    [annotation setString:[self string]];
    [annotation setColor:[self color]];
    [annotation setBorder:[[[self border] copy] autorelease]];
    [annotation setIconType:[self iconType]];
    return annotation;
}

@end

#pragma mark -

@implementation SKNoteText

- (id)initWithAnnotation:(PDFAnnotation *)anAnnotation {
    if (self = [super init]) {
        annotation = anAnnotation;
    }
    return self;
}

- (PDFAnnotation *)annotation {
    return annotation;
}

- (NSArray *)texts { return nil; }

- (NSString *)type { return nil; }

- (PDFPage *)page { return nil; }

- (NSString *)string { return [[self text] string]; }

- (unsigned int)pageIndex { return [annotation pageIndex]; }

- (NSAttributedString *)text { return [annotation text]; }

@end
