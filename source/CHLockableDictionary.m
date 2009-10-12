/*
 CHDataStructures.framework -- CHLockableDictionary.m
 
 Copyright (c) 2009, Quinn Taylor <http://homepage.mac.com/quinntaylor>
 
 Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted, provided that the above copyright notice and this permission notice appear in all copies.
 
 The software is  provided "as is", without warranty of any kind, including all implied warranties of merchantability and fitness. In no event shall the authors or copyright holders be liable for any claim, damages, or other liability, whether in an action of contract, tort, or otherwise, arising from, out of, or in connection with the software or the use or other dealings in the software.
 */

#import "CHLockableDictionary.h"

#pragma mark CHDictionary callbacks

const void* CHLockableDictionaryRetain(CFAllocatorRef allocator, const void *value) {
	return [(id)value retain];
}

void CHLockableDictionaryRelease(CFAllocatorRef allocator, const void *value) {
	[(id)value release];
}

CFStringRef CHLockableDictionaryDescription(const void *value) {
	return (CFStringRef)[(id)value description];
}

Boolean CHLockableDictionaryEqual(const void *value1, const void *value2) {
	return [(id)value1 isEqual:(id)value2];
}

CFHashCode CHLockableDictionaryHash(const void *value) {
	return (CFHashCode)[(id)value hash];
}

static const CFDictionaryKeyCallBacks kCHLockableDictionaryKeyCallBacks = {
	0, // default version
	CHLockableDictionaryRetain,
	CHLockableDictionaryRelease,
	CHLockableDictionaryDescription,
	CHLockableDictionaryEqual,
	CHLockableDictionaryHash
};

static const CFDictionaryValueCallBacks kCHLockableDictionaryValueCallBacks = {
	0, // default version
	CHLockableDictionaryRetain,
	CHLockableDictionaryRelease,
	CHLockableDictionaryDescription,
	CHLockableDictionaryEqual
};

#pragma mark -

@implementation CHLockableDictionary

// Private method used for creating a lock on-demand and naming it uniquely.
- (void) createLock {
	@synchronized (self) {
		if (lock == nil) {
			lock = [[NSLock alloc] init];
#if MAC_OS_X_VERSION_10_5_AND_LATER
			[lock setName:[NSString stringWithFormat:@"NSLock-%@-0x%x", [self class], self]];
#endif
		}
	}
}

- (BOOL) tryLock {
	if (lock == nil)
		[self createLock];
	return [lock tryLock];
}

- (void) lock {
	if (lock == nil)
		[self createLock];
	[lock lock];
}

- (BOOL) lockBeforeDate:(NSDate*)limit {
	if (lock == nil)
		[self createLock];
	return [lock lockBeforeDate:limit];
}

- (void) unlock {
	[lock unlock];
}

#pragma mark -

+ (void) initialize {
	initializeGCStatus();
}

- (void) dealloc {
	CFRelease(dictionary);
	[lock release];
	[super dealloc];
}

// Note: Defined here since -init is not implemented in NS(Mutable)Dictionary.
- (id) init {
	return [self initWithCapacity:0]; // The 0 means we provide no capacity hint
}

// Note: This is the designated initializer for NSMutableDictionary and this class.
// Subclasses may override this as necessary, but must call back here first.
- (id) initWithCapacity:(NSUInteger)numItems {
	if ((self = [super init]) == nil) return nil;
	dictionary = CFDictionaryCreateMutable(kCFAllocatorDefault,
	                                       numItems,
	                                       &kCHLockableDictionaryKeyCallBacks,
	                                       &kCHLockableDictionaryValueCallBacks);
	CFMakeCollectable(dictionary); // Works under GC, and is a no-op otherwise.
	return self;
}

#pragma mark <NSCoding>

// Overridden from NSObject to encode/decode as the proper class.
- (Class) classForKeyedArchiver {
	return [self class];
}

- (id) initWithCoder:(NSCoder*)decoder {
	return [self initWithDictionary:[decoder decodeObjectForKey:@"dictionary"]];
}

- (void) encodeWithCoder:(NSCoder*)encoder {
	[encoder encodeObject:(NSDictionary*)dictionary forKey:@"dictionary"];
}

#pragma mark <NSCopying>

- (id) copyWithZone:(NSZone*) zone {
	// We could use -initWithDictionary: here, but it would just use more memory.
	// (It marshals key-value pairs into two id* arrays, then inits from those.)
	CHLockableDictionary *copy = [[[self class] allocWithZone:zone] init];
	NSEnumerator *keys = [self keyEnumerator];
	id aKey;
	while (aKey = [keys nextObject]) {
		[copy setObject:[self objectForKey:aKey] forKey:aKey];
	}
	return copy;
}

#pragma mark <NSFastEnumeration>

#if MAC_OS_X_VERSION_10_5_AND_LATER
- (NSUInteger) countByEnumeratingWithState:(NSFastEnumerationState*)state
                                   objects:(id*)stackbuf
                                     count:(NSUInteger)len
{
	return [super countByEnumeratingWithState:state objects:stackbuf count:len];
}
#endif

#pragma mark Adding Objects

- (void) setObject:(id)anObject forKey:(id)aKey {
	CFDictionarySetValue(dictionary, [[aKey copy] autorelease], anObject);
}

#pragma mark Querying Contents

- (NSUInteger) count {
	return CFDictionaryGetCount(dictionary);
}

- (NSEnumerator*) keyEnumerator {
	NSUInteger count = CFDictionaryGetCount(dictionary);
	id *keyBuffer = NSAllocateCollectable(count * sizeof(void*), 0);
	CFDictionaryGetKeysAndValues(dictionary, (const void **)keyBuffer, NULL);
	NSArray *keys = [NSArray arrayWithObjects:keyBuffer count:count];
	if (kCHGarbageCollectionNotEnabled)
		free(keyBuffer);
	return [keys objectEnumerator];
}

- (id) objectForKey:(id)aKey {
	return (id)CFDictionaryGetValue(dictionary, aKey);
}

#pragma mark Removing Objects

- (void) removeAllObjects {
	CFDictionaryRemoveAllValues(dictionary);
}

- (void) removeObjectForKey:(id)aKey {
	CFDictionaryRemoveValue(dictionary, aKey);
}

@end
