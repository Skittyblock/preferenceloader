#import "PLHeap.h"
#import "PLRootList.h"
#import "PLSwiftMeta.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <ptrauth.h>

typedef struct {
    const void *state, *optionalSnapshot, *snapshot, *section, *item;
    const void *sectionID, *itemID, *viewType, *label, *iconType;
    const void *header, *footer, *secondary;
    int32_t cachedSnapshot, sections, sectionLookup, itemLookup;
    int32_t sectionIdentity, items, headerText, footerText;
    int32_t itemIdentity, itemType, labelText, secondaryText, badgeNumber;
    int32_t icon, iconTypeOffset;
    uint32_t some, sectionTag, itemTag, labelTag, noIcon, utIcon;
} PLSettings27Layout;

static PLSettings27Layout layout;
static id sidebarState;
static BOOL updating;

static const void *PLSettings27Type(NSString *module, NSString *name, char kind) {
    NSString *mangled = [NSString stringWithFormat:@"%lu%@%lu%@%c", (unsigned long)module.length,
                                                   module, (unsigned long)name.length, name, kind];
    return PLSwiftTypeByMangledName(mangled.UTF8String);
}

static BOOL PLSettings27SameType(const void *metadata, const char *name) {
    return metadata && metadata == PLSwiftTypeByMangledName(name);
}

static BOOL PLSettings27SameNominalType(const void *metadata, const char *example) {
    const void *other = PLSwiftTypeByMangledName(example);
    if (!metadata || !other || *(const uintptr_t *)metadata != *(const uintptr_t *)other) return NO;
    return ptrauth_strip(((const void *const *)metadata)[1],
                         ptrauth_key_process_independent_data) ==
           ptrauth_strip(((const void *const *)other)[1], ptrauth_key_process_independent_data);
}

static const void *PLSettings27ElementType(const void *metadata, const char *example) {
    return PLSettings27SameNominalType(metadata, example) ? ((const void *const *)metadata)[2]
                                                          : NULL;
}

static BOOL PLSettings27DictionaryMatches(const void *dictionary, const void *key,
                                          const void *value) {
    return PLSettings27SameNominalType(dictionary, "SDyS2iG") &&
           ((const void *const *)dictionary)[2] == key &&
           ((const void *const *)dictionary)[3] == value;
}

static const void *PLSettings27CasePayload(const void *metadata, const char *name) {
    const void *payload = PLSwiftTypeOfField(metadata, name);
    if (payload && *(const uintptr_t *)payload == 0x301) {
        const uintptr_t *tuple = payload;
        return tuple[1] == 1 && tuple[4] == 0 ? (const void *)tuple[3] : NULL;
    }
    return payload;
}

static BOOL PLSettings27ResolveLayout(void) {
    layout.state = PLSettings27Type(@"SettingsApp", @"SettingsSidebarListState", 'C');
    if (!layout.state) return NO;
    layout.cachedSnapshot = PLSwiftClassOffsetOfField(layout.state, "_cachedSnapshot");
    layout.optionalSnapshot = PLSwiftTypeOfField(layout.state, "_cachedSnapshot");
    if (layout.cachedSnapshot < 0 || !layout.optionalSnapshot) return NO;
    layout.some = PLSwiftEnumTagNamed(layout.optionalSnapshot, "some");
    if (layout.some == UINT32_MAX) return NO;
    layout.snapshot = PLSettings27ElementType(layout.optionalSnapshot, "SiSg");
    if (!layout.snapshot) return NO;
    layout.sections = PLSwiftStructOffsetOfField(layout.snapshot, "sections");
    layout.sectionLookup = PLSwiftStructOffsetOfField(layout.snapshot, "sectionIdentifierLookup");
    layout.itemLookup = PLSwiftStructOffsetOfField(layout.snapshot, "itemIdentifierLookup");
    layout.section =
        PLSettings27ElementType(PLSwiftTypeOfField(layout.snapshot, "sections"), "SaySiG");
    if (!layout.section) return NO;
    layout.sectionID = PLSwiftTypeOfField(layout.section, "id");
    layout.sectionIdentity = PLSwiftStructOffsetOfField(layout.section, "id");
    layout.items = PLSwiftStructOffsetOfField(layout.section, "items");
    layout.headerText = PLSwiftStructOffsetOfField(layout.section, "headerText");
    layout.footerText = PLSwiftStructOffsetOfField(layout.section, "footerText");
    layout.header = PLSwiftTypeOfField(layout.section, "headerText");
    layout.footer = PLSwiftTypeOfField(layout.section, "footerText");
    layout.item = PLSettings27ElementType(PLSwiftTypeOfField(layout.section, "items"), "SaySiG");
    if (!layout.item || !layout.sectionID || !layout.header || !layout.footer) return NO;
    layout.itemID = PLSwiftTypeOfField(layout.item, "id");
    layout.viewType = PLSwiftTypeOfField(layout.item, "type");
    layout.itemIdentity = PLSwiftStructOffsetOfField(layout.item, "id");
    layout.itemType = PLSwiftStructOffsetOfField(layout.item, "type");
    layout.label = PLSettings27Type(@"SettingsHost", @"SettingsListLabelModel", 'V');
    if (!layout.itemID || !layout.viewType || !layout.label) return NO;
    layout.labelText = PLSwiftStructOffsetOfField(layout.label, "text");
    layout.secondaryText = PLSwiftStructOffsetOfField(layout.label, "secondaryText");
    layout.secondary = PLSwiftTypeOfField(layout.label, "secondaryText");
    layout.badgeNumber = PLSwiftStructOffsetOfField(layout.label, "badgeNumber");
    layout.icon = PLSwiftStructOffsetOfField(layout.label, "icon");
    const void *icon = PLSwiftTypeOfField(layout.label, "icon");
    layout.iconType = PLSwiftTypeOfField(icon, "iconType");
    layout.iconTypeOffset = PLSwiftStructOffsetOfField(icon, "iconType");
    if (!layout.secondary || !layout.iconType) return NO;
    layout.sectionTag = PLSwiftEnumTagNamed(layout.sectionID, "extensionSection");
    layout.itemTag = PLSwiftEnumTagNamed(layout.itemID, "connectedHeadphone");
    layout.labelTag = PLSwiftEnumTagNamed(layout.viewType, "label");
    layout.noIcon = PLSwiftEnumTagNamed(layout.iconType, "none");
    layout.utIcon = PLSwiftEnumTagNamed(layout.iconType, "utType");
    const int32_t offsets[] = {
        layout.sections, layout.sectionLookup, layout.itemLookup,    layout.sectionIdentity,
        layout.items,    layout.headerText,    layout.footerText,    layout.itemIdentity,
        layout.itemType, layout.labelText,     layout.secondaryText, layout.badgeNumber,
        layout.icon,     layout.iconTypeOffset};
    for (NSUInteger i = 0; i < sizeof(offsets) / sizeof(offsets[0]); i++)
        if (offsets[i] < 0) return NO;
    return PLSettings27DictionaryMatches(
               PLSwiftTypeOfField(layout.snapshot, "sectionIdentifierLookup"), layout.sectionID,
               layout.section) &&
           PLSettings27DictionaryMatches(
               PLSwiftTypeOfField(layout.snapshot, "itemIdentifierLookup"), layout.itemID,
               layout.item) &&
           PLSettings27SameType(PLSettings27CasePayload(layout.sectionID, "extensionSection"),
                                "Si") &&
           PLSettings27SameType(PLSettings27CasePayload(layout.itemID, "connectedHeadphone"),
                                "SS") &&
           PLSettings27CasePayload(layout.viewType, "label") == layout.label &&
           PLSettings27SameType(PLSwiftTypeOfField(layout.label, "text"), "SS") &&
           PLSettings27SameType(layout.secondary, "SSSg") &&
           PLSettings27SameType(PLSwiftTypeOfField(layout.label, "badgeNumber"), "Si") &&
           !PLSwiftEnumCaseHasPayload(layout.iconType, layout.noIcon) &&
           PLSwiftTypeStride(layout.optionalSnapshot) <= 4096 && layout.sectionTag != UINT32_MAX &&
           layout.itemTag != UINT32_MAX && layout.labelTag != UINT32_MAX &&
           layout.noIcon != UINT32_MAX &&
           PLSwiftEnumTagNamed(layout.header, "none") != UINT32_MAX &&
           PLSwiftEnumTagNamed(layout.footer, "none") != UINT32_MAX &&
           PLSwiftEnumTagNamed(layout.secondary, "none") != UINT32_MAX;
}

static void PLSettings27ClearOptional(void *value, const void *metadata) {
    PLSwiftValueDestroy(value, metadata);
    memset(value, 0, PLSwiftTypeSize(metadata));
    PLSwiftEnumInject(value, PLSwiftEnumTagNamed(metadata, "none"), metadata);
}

static void PLSettings27DestroySnapshotCopy(void *copy) {
    PLSwiftEnumInject(copy, layout.some, layout.optionalSnapshot);
    PLSwiftValueDestroy(copy, layout.optionalSnapshot);
    free(copy);
}

static void PLSettings27Update(void) {
    if (!sidebarState) {
        __unsafe_unretained id instances[1];
        if (!PLHeapFindInstances((Class)layout.state, instances, 1)) return;
        // keep the state alive while the observer retains its address
        sidebarState = [instances[0] retain];
    }
    uint8_t *snapshot = (uint8_t *)(void *)sidebarState + layout.cachedSnapshot;
    if (PLSwiftEnumTag(snapshot, layout.optionalSnapshot) != layout.some) return;
    uint8_t *copy = calloc(1, PLSwiftTypeStride(layout.optionalSnapshot));
    if (!copy) return;
    PLSwiftValueInitializeWithCopy(copy, snapshot, layout.optionalSnapshot);
    PLSwiftEnumProject(copy, layout.optionalSnapshot);
    const void *array = copy + layout.sections;
    NSInteger count = PLSwiftArrayCount(array);
    if (count <= 0) {
        PLSettings27DestroySnapshotCopy(copy);
        return;
    }

    const NSInteger sectionIndex = NSIntegerMin;
    const void *templateSection = NULL, *templateItem = NULL;
    for (NSInteger i = 0; i < count; i++) {
        const uint8_t *section = PLSwiftArrayElement(array, i, PLSwiftTypeStride(layout.section));
        const void *identity = section + layout.sectionIdentity;
        if (PLSwiftEnumTag(identity, layout.sectionID) == layout.sectionTag &&
            *(const NSInteger *)identity == sectionIndex) {
            PLSettings27DestroySnapshotCopy(copy);
            return;
        }
        const void *items = section + layout.items;
        for (NSInteger j = 0; j < PLSwiftArrayCount(items); j++) {
            const uint8_t *item = PLSwiftArrayElement(items, j, PLSwiftTypeStride(layout.item));
            if (PLSwiftEnumTag(item + layout.itemType, layout.viewType) == layout.labelTag) {
                templateSection = section;
                templateItem = item;
                break;
            }
        }
    }
    NSArray<NSDictionary *> *entries = PLRootListPreferenceEntries();
    if (!templateSection || !templateItem || !entries.count) {
        PLSettings27DestroySnapshotCopy(copy);
        return;
    }

    uint8_t *section = calloc(1, PLSwiftTypeStride(layout.section));
    uint8_t *item = calloc(1, PLSwiftTypeStride(layout.item));
    if (!section || !item) {
        PLSettings27DestroySnapshotCopy(copy);
        free(section);
        free(item);
        return;
    }

    PLSwiftValueInitializeWithCopy(section, templateSection, layout.section);
    void *sectionID = section + layout.sectionIdentity;
    PLSwiftValueDestroy(sectionID, layout.sectionID);
    memset(sectionID, 0, PLSwiftTypeSize(layout.sectionID));
    *(NSInteger *)sectionID = sectionIndex;
    PLSwiftEnumInject(sectionID, layout.sectionTag, layout.sectionID);
    PLSettings27ClearOptional(section + layout.headerText, layout.header);
    PLSettings27ClearOptional(section + layout.footerText, layout.footer);

    PLSwiftArrayRemoveAll(section + layout.items, layout.item);

    const BOOL utIcons = layout.utIcon != UINT32_MAX;
    BOOL success = YES;
    for (NSDictionary *entry in entries) {
        NSString *title = entry[@"label"];
        PLSwiftValueInitializeWithCopy(item, templateItem, layout.item);
        void *identity = item + layout.itemIdentity;
        PLSwiftValueDestroy(identity, layout.itemID);
        memset(identity, 0, PLSwiftTypeSize(layout.itemID));
        NSString *key = [@"preferenceloader:" stringByAppendingString:entry[@"identifier"]];
        PLSwiftStringInitialize(key.UTF8String, identity);
        PLSwiftEnumInject(identity, layout.itemTag, layout.itemID);
        void *viewType = item + layout.itemType;
        PLSwiftEnumProject(viewType, layout.viewType);
        PLSwiftStringAssign((uint8_t *)viewType + layout.labelText, title.UTF8String);
        PLSettings27ClearOptional((uint8_t *)viewType + layout.secondaryText, layout.secondary);
        *(NSInteger *)((uint8_t *)viewType + layout.badgeNumber) = 0;
        void *icon = (uint8_t *)viewType + layout.icon + layout.iconTypeOffset;
        PLSwiftValueDestroy(icon, layout.iconType);
        memset(icon, 0, PLSwiftTypeSize(layout.iconType));
        if (utIcons) {
            PLSwiftEnumProject(icon, layout.iconType);
            PLSwiftStringInitialize(
                [kPLIconPrefix stringByAppendingString:entry[@"identifier"]].UTF8String, icon);
            PLSwiftEnumInject(icon, layout.utIcon, layout.iconType);
        } else {
            PLSwiftEnumInject(icon, layout.noIcon, layout.iconType);
        }
        PLSwiftEnumInject(viewType, layout.labelTag, layout.viewType);
        PLSwiftArrayAppendValue(section + layout.items, item, layout.item);
        success = PLSwiftDictionarySetValue(copy + layout.itemLookup, identity, layout.itemID, item,
                                            layout.item);
        PLSwiftValueDestroy(item, layout.item);
        if (!success) break;
    }
    if (success)
        success = PLSwiftDictionarySetValue(copy + layout.sectionLookup, sectionID,
                                            layout.sectionID, section, layout.section);
    if (success) {
        PLSwiftArrayAppendValue(copy + layout.sections, section, layout.section);
        PLSwiftEnumInject(copy, layout.some, layout.optionalSnapshot);
        PLSwiftValueDestroy(snapshot, layout.optionalSnapshot);
        PLSwiftValueInitializeWithCopy(snapshot, copy, layout.optionalSnapshot);
        PLSwiftEnumProject(copy, layout.optionalSnapshot);
    }
    PLSwiftValueDestroy(section, layout.section);
    free(item);
    free(section);
    PLSettings27DestroySnapshotCopy(copy);
}

static void PLSettings27Inject(CFRunLoopObserverRef observer, CFRunLoopActivity activity,
                               void *info) {
    if (updating) return;
    updating = YES;
    @try {
        PLSettings27Update();
    } @finally {
        updating = NO;
    }
}

static UICollectionView *PLFindCollectionView(UIView *view) {
    if ([view isKindOfClass:UICollectionView.class]) return (UICollectionView *)view;
    for (UIView *subview in view.subviews) {
        UICollectionView *found = PLFindCollectionView(subview);
        if (found) return found;
    }
    return nil;
}

UIViewController *PLSettings27PaneForPush(UINavigationController *navigation) {
    if (!layout.state || navigation.viewControllers.count != 1) return nil;
    UICollectionView *list = PLFindCollectionView(navigation.viewControllers.firstObject.view);
    NSArray<NSIndexPath *> *selected = list.indexPathsForSelectedItems;
    NSArray<NSDictionary *> *entries = PLRootListPreferenceEntries();
    NSInteger last = list.numberOfSections - 1;
    if (selected.count != 1 || selected.firstObject.section != last ||
        [list numberOfItemsInSection:last] != (NSInteger)entries.count)
        return nil;
    return PLRootListPaneForEntry(entries[selected.firstObject.item]);
}

static NSMutableDictionary *PLPreparedIcons(void) {
    static NSMutableDictionary *icons;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        icons = [[NSMutableDictionary alloc] init];
    });
    return icons;
}

UIImage *PLPreparedRootListIcon(NSString *identifier) {
    NSMutableDictionary *icons = PLPreparedIcons();
    @synchronized(icons) {
        id image = icons[identifier];
        return image == NSNull.null ? nil : image;
    }
}

void PLPrepareRootListIcons(void (^completion)(void)) {
    NSArray<NSDictionary *> *entries = PLRootListPreferenceEntries();
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        for (NSDictionary *entry in entries) {
            @autoreleasepool {
                UIImage *image = PLIconForEntry(entry);
                image = [image imageByPreparingForDisplay] ?: image;
                NSMutableDictionary *icons = PLPreparedIcons();
                @synchronized(icons) {
                    icons[entry[@"identifier"]] = image ?: (id)NSNull.null;
                }
            }
        }
        dispatch_async(dispatch_get_main_queue(), completion);
    });
}

void PLSettings27Start(void) {
    if (!PLSettings27ResolveLayout()) {
        return;
    }
    PLPrepareRootListIcons(^{
        static CFRunLoopObserverRef observer;
        if (!observer) {
            observer = CFRunLoopObserverCreate(kCFAllocatorDefault,
                                               kCFRunLoopBeforeTimers | kCFRunLoopBeforeWaiting,
                                               true, -2000000, PLSettings27Inject, NULL);
            if (!observer) return;
            CFRunLoopAddObserver(CFRunLoopGetMain(), observer, kCFRunLoopCommonModes);
        }
    });
}
