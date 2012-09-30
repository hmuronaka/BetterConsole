#import "BCFilePathHighlighter.h"
#import "BCUtils.h"
#import <objc/runtime.h>
#import <regex.h>

@interface BCFilePathHighlighter ()
@property (strong, nonatomic) NSTextView *textView;
@end

@implementation BCFilePathHighlighter
@synthesize textView = _textView;

- (id)initWithTextView:(NSTextView *)textView {
    if (self = [super init]) {
        self.textView = textView;
    }
    return self;
}

- (void)dealloc {
    [_textView release];
    [super dealloc];
}

+ (regex_t)_filePathRegex {
    static regex_t *rx = NULL;
    if (!rx) {
        rx = malloc(sizeof(regex_t));
        regcomp(rx, "(/[^:\n\r]+:[[:digit:]]+)", REG_EXTENDED);
    }
    return *rx;
}

NSArray *BCFilePathHighlighter_findFilePathRanges(NSTextStorage *textStorage) {
    NSMutableArray *filePathRanges = [NSMutableArray array];
    const char *text = textStorage.string.UTF8String;

    regex_t rx = [BCFilePathHighlighter _filePathRegex];
    regmatch_t *matches = malloc((rx.re_nsub+1) * sizeof(regmatch_t));
    NSUInteger matchStartIndex = 0;

    while (regexec(&rx, text + matchStartIndex, rx.re_nsub+1, matches, 0) == 0) {
        NSRange range = NSMakeRange(
            (NSUInteger)(matches[1].rm_so + matchStartIndex),
            (NSUInteger)(matches[1].rm_eo - matches[1].rm_so));
        [filePathRanges addObject:[NSValue valueWithRange:range]];
        matchStartIndex += matches[1].rm_eo;
    }

    free(matches);
    return filePathRanges;
}

void BCFilePathHighlighter_highlightFilePathRanges(NSTextStorage *textStorage, NSArray *filePathRanges) {
    for (NSValue *rangeValue in filePathRanges) {
        NSRange range = rangeValue.rangeValue;
        NSString *filePath = [textStorage.string substringWithRange:range];

        [textStorage addAttributes:
            [NSDictionary dictionaryWithObjectsAndKeys:
                [NSCursor pointingHandCursor], NSCursorAttributeName,
                [NSColor darkGrayColor], NSForegroundColorAttributeName,
                [NSNumber numberWithInt:1], NSUnderlineStyleAttributeName,
                filePath, @"BetterConsoleFilePath", nil]
        range:range];
    }
}

void BCFilePathHighlighter_Handler(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    BCTimeLog(@"BetterConsole - FilePathHightlighter") {
        NSTextStorage *textStorage = (NSTextStorage *)object;
        NSArray *filePathRanges = BCFilePathHighlighter_findFilePathRanges(textStorage);
        BCFilePathHighlighter_highlightFilePathRanges(textStorage, filePathRanges);
    }
}

- (void)attach {
    static char Observer;

    if (!objc_getAssociatedObject(self.textView, &Observer)) {
        objc_setAssociatedObject(self.textView, &Observer, [NSNumber numberWithBool:YES], OBJC_ASSOCIATION_RETAIN);

        CFNotificationCenterAddObserver(
            CFNotificationCenterGetLocalCenter(),
            NULL, BCFilePathHighlighter_Handler,
            (CFStringRef)NSTextStorageDidProcessEditingNotification,
            self.textView.textStorage, CFNotificationSuspensionBehaviorDeliverImmediately);
    }
}
@end