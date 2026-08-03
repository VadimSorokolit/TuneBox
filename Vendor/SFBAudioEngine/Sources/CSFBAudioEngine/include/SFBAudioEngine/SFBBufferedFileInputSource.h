//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/SFBAudioEngine
//

#import <SFBAudioEngine/SFBInputSource.h>

NS_ASSUME_NONNULL_BEGIN

/// A file input source that reads ahead into an in-memory circular buffer.
NS_SWIFT_NAME(BufferedFileInputSource)
@interface SFBBufferedFileInputSource : SFBInputSource

/// Returns an initialized input source for the given file URL.
/// - parameter url: The file URL
/// - parameter bufferCapacity: The maximum number of prefetched bytes to keep in memory
/// - parameter readChunkSize: The number of bytes requested from the filesystem per read-ahead operation
- (instancetype)initWithURL:(NSURL *)url
             bufferCapacity:(NSUInteger)bufferCapacity
              readChunkSize:(NSUInteger)readChunkSize NS_DESIGNATED_INITIALIZER;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
