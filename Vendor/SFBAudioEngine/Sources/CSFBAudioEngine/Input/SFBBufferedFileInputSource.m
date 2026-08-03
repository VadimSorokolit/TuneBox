//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/SFBAudioEngine
//

#import "SFBBufferedFileInputSource.h"

#import "SFBInputSource+Internal.h"

#import <pthread.h>
#import <stdio.h>
#import <sys/stat.h>

static void *SFBBufferedFileInputSourceReaderMain(void *context);

@interface SFBBufferedFileInputSource () {
  @private
    struct stat _filestats;
    FILE *_file;

    uint8_t *_buffer;
    NSUInteger _bufferCapacity;
    NSUInteger _readChunkSize;
    NSUInteger _lowWaterMark;
    NSUInteger _highWaterMark;
    NSUInteger _readIndex;
    NSUInteger _bufferedLength;
    NSInteger _bufferStartOffset;
    NSInteger _readOffset;

    pthread_mutex_t _mutex;
    pthread_cond_t _condition;
    pthread_t _readerThread;
    BOOL _hasReaderThread;
    BOOL _stopReader;
    BOOL _readerAtEOF;
    NSError *_readerError;
}
@end

@implementation SFBBufferedFileInputSource

- (instancetype)initWithURL:(NSURL *)url bufferCapacity:(NSUInteger)bufferCapacity readChunkSize:(NSUInteger)readChunkSize {
    NSParameterAssert(url != nil);
    NSParameterAssert(url.isFileURL);
    NSParameterAssert(bufferCapacity > 0);
    NSParameterAssert(readChunkSize > 0);

    if ((self = [super initWithURL:url])) {
        _bufferCapacity = bufferCapacity;
        _readChunkSize = readChunkSize;
        _highWaterMark = MIN(readChunkSize, bufferCapacity);
        _lowWaterMark = MAX((NSUInteger)1, _highWaterMark / 2);
        pthread_mutex_init(&_mutex, NULL);
        pthread_cond_init(&_condition, NULL);
    }
    return self;
}

- (void)dealloc {
    [self closeReturningError:nil];
    pthread_cond_destroy(&_condition);
    pthread_mutex_destroy(&_mutex);
}

- (BOOL)openReturningError:(NSError **)error {
    if (_file) {
        return YES;
    }

    _file = fopen(_url.fileSystemRepresentation, "r");
    if (!_file) {
        int err = errno;
        os_log_error(gSFBInputSourceLog, "fopen failed: %{public}s (%d)", strerror(err), err);
        if (error) {
            *error = [self posixErrorWithCode:err];
        }
        return NO;
    }

    if (fstat(fileno(_file), &_filestats) == -1) {
        int err = errno;
        os_log_error(gSFBInputSourceLog, "fstat failed: %{public}s (%d)", strerror(err), err);
        if (error) {
            *error = [self posixErrorWithCode:err];
        }
        fclose(_file);
        _file = NULL;
        return NO;
    }

    _buffer = calloc(_bufferCapacity, 1);
    if (!_buffer) {
        if (error) {
            *error = [self posixErrorWithCode:ENOMEM];
        }
        fclose(_file);
        _file = NULL;
        return NO;
    }

    _readIndex = 0;
    _bufferedLength = 0;
    _bufferStartOffset = 0;
    _readOffset = 0;
    _stopReader = NO;
    _readerAtEOF = NO;
    _readerError = nil;

    int result = pthread_create(&_readerThread, NULL, SFBBufferedFileInputSourceReaderMain, (__bridge void *)self);
    if (result) {
        if (error) {
            *error = [self posixErrorWithCode:result];
        }
        free(_buffer);
        _buffer = NULL;
        fclose(_file);
        _file = NULL;
        return NO;
    }
    _hasReaderThread = YES;
    os_log_debug(gSFBInputSourceLog,
                 "buffered input source opened length: %lld buffer capacity: %llu read chunk size: %llu low watermark: %llu high watermark: %llu",
                 (long long)_filestats.st_size, (unsigned long long)_bufferCapacity,
                 (unsigned long long)_readChunkSize, (unsigned long long)_lowWaterMark,
                 (unsigned long long)_highWaterMark);

    return YES;
}

- (BOOL)closeReturningError:(NSError **)error {
    if (_hasReaderThread || _file) {
        os_log_debug(gSFBInputSourceLog, "buffered input source closing");
    }

    if (_hasReaderThread) {
        pthread_mutex_lock(&_mutex);
        _stopReader = YES;
        pthread_cond_broadcast(&_condition);
        pthread_mutex_unlock(&_mutex);

        pthread_join(_readerThread, NULL);
        _hasReaderThread = NO;
    }

    if (_buffer) {
        free(_buffer);
        _buffer = NULL;
    }

    if (_file) {
        int result = fclose(_file);
        _file = NULL;
        os_log_debug(gSFBInputSourceLog, "buffered input source closed");
        if (result) {
            int err = errno;
            os_log_error(gSFBInputSourceLog, "fclose failed: %{public}s (%d)", strerror(err), err);
            if (error) {
                *error = [self posixErrorWithCode:err];
            }
            return NO;
        }
    }

    return YES;
}

- (BOOL)isOpen {
    return _file != NULL;
}

- (NSInteger)bufferEndOffset {
    return _bufferStartOffset + (NSInteger)_bufferedLength;
}

- (BOOL)readOffsetIsCached {
    return _readOffset >= _bufferStartOffset && _readOffset < self.bufferEndOffset;
}

- (NSUInteger)cachedBytesAvailableAfterReadOffset {
    NSInteger bufferEndOffset = self.bufferEndOffset;
    if (_readOffset < _bufferStartOffset || _readOffset >= bufferEndOffset) {
        return 0;
    }
    return (NSUInteger)(bufferEndOffset - _readOffset);
}

- (void)evictCachedBytesBeforeReadOffsetIfNeeded {
    if (_readOffset <= _bufferStartOffset || _bufferedLength == 0) {
        return;
    }

    NSUInteger bytesBeforeReadOffset = MIN((NSUInteger)(_readOffset - _bufferStartOffset), _bufferedLength);
    if (bytesBeforeReadOffset == 0) {
        return;
    }

    _readIndex = (_readIndex + bytesBeforeReadOffset) % _bufferCapacity;
    _bufferStartOffset += (NSInteger)bytesBeforeReadOffset;
    _bufferedLength -= bytesBeforeReadOffset;
}

- (BOOL)readBytes:(void *)buffer length:(NSInteger)length bytesRead:(NSInteger *)bytesRead error:(NSError **)error {
    NSParameterAssert(buffer != NULL);
    NSParameterAssert(length >= 0);
    NSParameterAssert(bytesRead != NULL);

    uint8_t *destination = (uint8_t *)buffer;
    NSInteger totalBytesRead = 0;

    pthread_mutex_lock(&_mutex);
    while (totalBytesRead < length) {
        while (![self readOffsetIsCached] && !_readerAtEOF && !_readerError) {
            pthread_cond_wait(&_condition, &_mutex);
        }

        if (![self readOffsetIsCached]) {
            if (_readerError) {
                if (error) {
                    *error = _readerError;
                }
                pthread_mutex_unlock(&_mutex);
                *bytesRead = totalBytesRead;
                return totalBytesRead > 0;
            }
            break;
        }

        NSUInteger bytesAvailable = [self cachedBytesAvailableAfterReadOffset];
        NSUInteger bytesToCopy = MIN((NSUInteger)(length - totalBytesRead), bytesAvailable);
        NSUInteger readIndex = (_readIndex + (NSUInteger)(_readOffset - _bufferStartOffset)) % _bufferCapacity;
        NSUInteger firstCopy = MIN(bytesToCopy, _bufferCapacity - readIndex);
        memcpy(destination + totalBytesRead, _buffer + readIndex, firstCopy);

        NSUInteger secondCopy = bytesToCopy - firstCopy;
        if (secondCopy > 0) {
            memcpy(destination + totalBytesRead + firstCopy, _buffer, secondCopy);
        }

        _readOffset += (NSInteger)bytesToCopy;
        totalBytesRead += (NSInteger)bytesToCopy;

        pthread_cond_broadcast(&_condition);
    }
    pthread_mutex_unlock(&_mutex);

    *bytesRead = totalBytesRead;
    return YES;
}

- (BOOL)atEOF {
    pthread_mutex_lock(&_mutex);
    BOOL atEOF = _readerAtEOF && _readOffset >= self.bufferEndOffset;
    pthread_mutex_unlock(&_mutex);
    return atEOF;
}

- (BOOL)getOffset:(NSInteger *)offset error:(NSError **)error {
    NSParameterAssert(offset != NULL);

    pthread_mutex_lock(&_mutex);
    *offset = _readOffset;
    pthread_mutex_unlock(&_mutex);
    return YES;
}

- (BOOL)getLength:(NSInteger *)length error:(NSError **)error {
    NSParameterAssert(length != NULL);
    *length = _filestats.st_size;
    return YES;
}

- (BOOL)supportsSeeking {
    return S_ISREG(_filestats.st_mode);
}

- (BOOL)seekToOffset:(NSInteger)offset error:(NSError **)error {
    NSParameterAssert(offset >= 0);

    pthread_mutex_lock(&_mutex);
    NSInteger bufferEndOffset = self.bufferEndOffset;
    BOOL seekOffsetIsCached = offset >= _bufferStartOffset && offset <= bufferEndOffset;

    if (seekOffsetIsCached) {
        _readOffset = offset;
        pthread_cond_broadcast(&_condition);
        pthread_mutex_unlock(&_mutex);
        return YES;
    }

    if (fseeko(_file, offset, SEEK_SET)) {
        int err = errno;
        os_log_error(gSFBInputSourceLog, "fseeko(%ld, SEEK_SET) error: %{public}s (%d)", (long)offset, strerror(err),
                     err);
        if (error) {
            *error = [self posixErrorWithCode:err];
        }
        pthread_mutex_unlock(&_mutex);
        return NO;
    }

    _readIndex = 0;
    _bufferedLength = 0;
    _bufferStartOffset = offset;
    _readOffset = offset;
    _readerAtEOF = NO;
    _readerError = nil;
    clearerr(_file);

    pthread_cond_broadcast(&_condition);
    pthread_mutex_unlock(&_mutex);
    return YES;
}

static void *SFBBufferedFileInputSourceReaderMain(void *context) {
    @autoreleasepool {
        SFBBufferedFileInputSource *inputSource = (__bridge SFBBufferedFileInputSource *)context;
        [inputSource readAheadLoop];
    }
    return NULL;
}

- (void)readAheadLoop {
    pthread_mutex_lock(&_mutex);

    while (!_stopReader) {
        while (!_stopReader && (_readerAtEOF || _readerError || [self cachedBytesAvailableAfterReadOffset] >= _lowWaterMark)) {
            pthread_cond_wait(&_condition, &_mutex);
        }

        if (_stopReader) {
            break;
        }

        if (_bufferedLength == _bufferCapacity) {
            [self evictCachedBytesBeforeReadOffsetIfNeeded];
        }

        NSUInteger freeSpace = _bufferCapacity - _bufferedLength;
        NSUInteger availableAfterReadOffset = [self cachedBytesAvailableAfterReadOffset];
        if (freeSpace == 0 || availableAfterReadOffset >= _highWaterMark) {
            pthread_cond_wait(&_condition, &_mutex);
            continue;
        }

        NSUInteger bytesToHighWaterMark = _highWaterMark - availableAfterReadOffset;
        NSUInteger bytesToRead = MIN(_readChunkSize, MIN(freeSpace, bytesToHighWaterMark));
        NSUInteger writeIndex = (_readIndex + _bufferedLength) % _bufferCapacity;
        NSUInteger firstRead = MIN(bytesToRead, _bufferCapacity - writeIndex);

        size_t bytesRead = fread(_buffer + writeIndex, 1, firstRead, _file);
        if (bytesRead == firstRead && bytesToRead > firstRead) {
            bytesRead += fread(_buffer, 1, bytesToRead - firstRead, _file);
        }
        if (bytesRead > 0) {
            _bufferedLength += bytesRead;
            pthread_cond_broadcast(&_condition);
        }

        if (bytesRead < bytesToRead) {
            if (ferror(_file)) {
                int err = errno;
                os_log_error(gSFBInputSourceLog, "fread error: %{public}s (%d)", strerror(err), err);
                _readerError = [self posixErrorWithCode:err];
            } else {
                _readerAtEOF = YES;
            }
            pthread_cond_broadcast(&_condition);
        }
    }

    pthread_mutex_unlock(&_mutex);
}

@end
