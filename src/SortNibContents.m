#import "SortNibContents.h"
#import "MMMacros.h"

@interface MMNibArchiveObjectPair : NSObject
@property (unsafe_unretained, nonatomic) MMNibArchiveObject *o1;
@property (unsafe_unretained, nonatomic) MMNibArchiveObject *o2;

- (instancetype)initWithObject:(MMNibArchiveObject *)o1 andObject:(MMNibArchiveObject *)o2;
@end
@implementation MMNibArchiveObjectPair
@synthesize o1 = _o1;
@synthesize o2 = _o2;
- (instancetype)initWithObject:(MMNibArchiveObject *)o1 andObject:(MMNibArchiveObject *)o2
{
    self = [super init];
    self->_o1 = o1;
    self->_o2 = o2;
    return self;
}
- (BOOL)isEqual:(id)other { return self.o1 == [other o1] && self.o2 == [other o2]; }
@end

#define compret(ret) { if (ret != NSOrderedSame) return ret; }
#define comp(a, b) { NSComparisonResult ret = [(a) compare:(b)]; compret(ret); }

static NSComparisonResult compareObjects(MMNibArchive *archive, NSMutableArray *trail, MMNibArchiveObject *lhs, MMNibArchiveObject *rhs);

static NSArray *sortedObjectValues(MMNibArchive *archive, MMNibArchiveObject *object) {
    NSArray *values = [archive.values subarrayWithRange:object.valuesRange];
    if ([NSSet setWithArray:values].count != values.count) return values;
    NSArray *sorted;
    if ([[archive.classNames[object.classNameIndex] nameString] isEqualToString:@"NSArray"]) {
        sorted = values;
    } else if ([[archive.classNames[object.classNameIndex] nameString] isEqualToString:@"NSMutableArray"]) {
        sorted = values;
    } else {
        sorted = [values sortedArrayUsingComparator:^NSComparisonResult(MMNibArchiveValue *lhs, MMNibArchiveValue *rhs){
            return [(NSString *)archive.keyStrings[lhs.keyIndex] compare:archive.keyStrings[rhs.keyIndex]];
        }];
    }

    return sorted;
}

static NSComparisonResult compareValues(MMNibArchive *archive, NSMutableArray *trail, MMNibArchiveValue *lhs, MMNibArchiveValue *rhs) {
    if (lhs == rhs) return 0;
    comp((NSString *)archive.keyStrings[lhs.keyIndex], (NSString *)archive.keyStrings[rhs.keyIndex]);
    comp(@(lhs.type), @(rhs.type));
    if (lhs.type == kMMNibArchiveValueTypeObjectReference) {
        compret(compareObjects(archive, trail, archive.objects[lhs.objectReference], archive.objects[rhs.objectReference]));
        return 0;
    } else if (lhs.type == kMMNibArchiveValueTypeData) {
        if ([archive.keyStrings[lhs.keyIndex] isEqualToString:@"NS.bytes"]) {
			NSString *ls = [[NSString alloc] initWithData: lhs.dataValue encoding: NSUTF8StringEncoding];
			NSString *rs = [[NSString alloc] initWithData: rhs.dataValue encoding: NSUTF8StringEncoding];
            return [ls compare:rs];
		}
    }

    comp(@(lhs.data.length), @(rhs.data.length));
    compret(memcmp(lhs.data.bytes, rhs.data.bytes, rhs.data.length));


    // NSLog(@"identical values: %@ %@" ,lhs.debugDescription, rhs.debugDescription);

    return 0;
}

static NSComparisonResult compareObjects(MMNibArchive *archive, NSMutableArray *trail, MMNibArchiveObject *lhs, MMNibArchiveObject *rhs) {
    if (lhs == rhs) return 0;
    comp(@(lhs.valuesRange.length), @(rhs.valuesRange.length));
    comp([archive.classNames[lhs.classNameIndex] nameString], [archive.classNames[rhs.classNameIndex] nameString]);

    MMNibArchiveObjectPair *pair = [[MMNibArchiveObjectPair alloc] initWithObject:lhs andObject: rhs];
    if ([trail containsObject:pair]) {
        NSLog(@"Cycle in %@ %@", lhs.debugDescription, rhs.debugDescription);
        return -1;
    } else {
        [trail addObject:pair];
    }

    NSArray *lhsValues = sortedObjectValues(archive, lhs);
    NSArray *rhsValues = sortedObjectValues(archive, rhs);
    for (NSUInteger i = 0; i < lhs.valuesRange.length; ++i) {
        compret(compareValues(archive, trail, lhsValues[i], rhsValues[i]));
    }

    return 0;
}

static NSMutableOrderedSet *sortedObjects(MMNibArchive *archive, NSMutableOrderedSet *trail, MMNibArchiveObject *object) {
    if ([trail containsObject:object]) return trail;
    [trail addObject:object];

    for (MMNibArchiveValue *value in sortedObjectValues(archive, object)) {
        if (value.type == kMMNibArchiveValueTypeObjectReference) {
            sortedObjects(archive, trail, archive.objects[value.objectReference]);
        }
    }
    return trail;
}

#undef compret
#undef comp

MMNibArchive * SortNibContents(MMNibArchive *archive) {
    MMNibArchive *result = archive;

    NSArray *newClassNames = [archive.classNames sortedArrayUsingComparator:^NSComparisonResult(MMNibArchiveClassName *lhs, MMNibArchiveClassName *rhs){
        return [lhs.nameString compare:rhs.nameString];
    }];
    NSArray *newKeys = [archive.keys sortedArrayUsingComparator:^NSComparisonResult(NSData *lhs, NSData *rhs){
        return [(NSString *)[[NSString alloc] initWithData:lhs encoding:NSUTF8StringEncoding] compare:(NSString *)[[NSString alloc] initWithData:rhs encoding:NSUTF8StringEncoding]];
    }];

    MMNibArchiveObject* rootObject = archive.objects.firstObject;
    // NSArray<MMNibArchiveObject*> *reorderedObjects = [@[rootObject] arrayByAddingObjectsFromArray:[[archive.objects subarrayWithRange:NSMakeRange(1, archive.objects.count-1)] sortedArrayUsingComparator:^NSComparisonResult(MMNibArchiveObject *lhs, MMNibArchiveObject *rhs){
    //     return compareObjects(archive, [NSMutableArray array], lhs, rhs);
    // }]];
    NSArray<MMNibArchiveObject*> *reorderedObjects = sortedObjects(archive, [NSMutableOrderedSet orderedSetWithCapacity:archive.objects.count], rootObject).array;

    // NSMutableArray *newKeys = [NSMutableArray array];
    NSMutableArray *newValues = [NSMutableArray array];
    NSMutableArray *newObjects = [NSMutableArray array];
    for (NSUInteger i = 0; i < reorderedObjects.count; ++i) {
        MMNibArchiveObject * const oldObject = reorderedObjects[i];
        NSRange newRange = NSMakeRange((NSUInteger)NSMaxRange([newObjects.lastObject valuesRange]), oldObject.valuesRange.length);
        // NSLog(@"{%lu, %lu} -> {%lu, %lu}", oldObject.valuesRange.location, oldObject.valuesRange.length, newRange.location, newRange.length);
        MMNibArchiveObject * const newObject = [[MMNibArchiveObject alloc] initWithClassNameIndex:[newClassNames indexOfObject:archive.classNames[oldObject.classNameIndex]] valuesRange:newRange];
        [newObjects addObject:newObject];

        for (MMNibArchiveValue *oldValue in sortedObjectValues(archive, oldObject)) {
            // NSLog(@"  %lu -> %lu", j, newValues.count);
            NSData *key = archive.keys[oldValue.keyIndex];

            NSUInteger newIndex = [newKeys indexOfObject:key];

            MMNibArchiveValue *newValue;

            if (oldValue.type == kMMNibArchiveValueTypeObjectReference) {
                MMNibArchiveObject *oldPointedObject = archive.objects[oldValue.objectReference];
                uint32_t objectReference = 0;
                for (uint32_t k = 0; k < reorderedObjects.count; ++k) {
                    MMNibArchiveObject *reo = reorderedObjects[k];
                    if (reo == oldPointedObject) {
                        objectReference = k;
                        break;
                    }
                }
                // NSLog(@" *%u -> %u", oldValue.objectReference, objectReference);
                newValue = [[MMNibArchiveValue alloc] initWithObjectReference:objectReference forKeyIndex:newIndex];
            } else {
                newValue = [[MMNibArchiveValue alloc] initWithData:oldValue.data ofType:oldValue.type forKeyIndex:newIndex];
            }
            
            [newValues addObject:newValue];
        }
    }

    NSError *error = nil;
    MMNibArchive *sortedArchive = MM_autorelease([[MMNibArchive alloc] initWithObjects:newObjects keys:newKeys values:newValues classNames:newClassNames error:&error]);
    if (sortedArchive) {
        result = sortedArchive;
    } else {
        NSLog(@"Error: %@", error);
    }
    return sortedArchive;
}
