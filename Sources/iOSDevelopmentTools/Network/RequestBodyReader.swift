import Foundation
import os

/// Reads a request's body stream without holding an unbounded amount of it in memory.
///
/// Inside a `URLProtocol` a request body arrives as `httpBodyStream`, even when the app set
/// `httpBody`. The stream can be read only once, so the bytes that are read for the log also have
/// to be sent on. Bodies up to `bufferLimit` are read into memory and sent as `Data`; longer ones
/// are sent through a ``RequestBodyPump`` that writes the bytes already read and then copies the
/// rest of the stream, so memory use stays at `bufferLimit` whatever the body size.
enum RequestBodyReader {
    enum Outcome {
        /// The whole body, read into memory.
        case complete(Data)
        /// The body is longer than the buffer limit: the bytes read so far and the unread stream.
        case partial(prefix: Data, remainder: InputStream)
        /// The stream reported an error before the limit.
        case failed(any Error)
    }

    static let chunkSize = 64 * 1024

    static func read(_ stream: InputStream, bufferLimit: Int) -> Outcome {
        if stream.streamStatus == .notOpen { stream.open() }
        var buffer = Data()
        var chunk = [UInt8](repeating: 0, count: chunkSize)
        while true {
            let count = stream.read(&chunk, maxLength: chunkSize)
            if count < 0 {
                stream.close()
                return .failed(stream.streamError ?? URLError(.cannotDecodeRawData))
            }
            if count == 0 {
                stream.close()
                return .complete(buffer)
            }
            buffer.append(chunk, count: count)
            if buffer.count > bufferLimit {
                return .partial(prefix: buffer, remainder: stream)
            }
        }
    }
}

/// Sends already-read bytes followed by the rest of a stream through a bound stream pair.
///
/// The copy runs on its own thread. It never blocks on a full buffer: it waits in short steps
/// and stops as soon as ``cancel()`` is called, the reading side closes, the source fails, or
/// the reading side takes nothing for ``idleTimeout`` seconds, so a request that is cancelled
/// or never sent cannot leave the thread behind.
final class RequestBodyPump: @unchecked Sendable {
    /// The stream to set as the forwarded request's `httpBodyStream`.
    let inputStream: InputStream

    private let output: OutputStream
    private let prefix: Data
    private let source: InputStream
    private let onFailure: @Sendable (any Error) -> Void
    private let progress = OSAllocatedUnfairLock(initialState: (bytes: 0, isCancelled: false))

    /// Seconds without progress after which the copy gives up.
    static let idleTimeout: TimeInterval = 120

    init?(prefix: Data, remainder source: InputStream, onFailure: @escaping @Sendable (any Error) -> Void) {
        var input: InputStream?
        var output: OutputStream?
        Stream.getBoundStreams(withBufferSize: RequestBodyReader.chunkSize, inputStream: &input, outputStream: &output)
        guard let input, let output else { return nil }
        self.inputStream = input
        self.output = output
        self.prefix = prefix
        self.source = source
        self.onFailure = onFailure
    }

    /// How many bytes have been passed on so far.
    var bytesWritten: Int { progress.withLock { $0.bytes } }

    func start() {
        let thread = Thread { [self] in run() }
        thread.name = "iOSDevelopmentTools.RequestBodyPump"
        thread.start()
    }

    func cancel() {
        progress.withLock { $0.isCancelled = true }
    }

    private var isCancelled: Bool { progress.withLock { $0.isCancelled } }

    private func run() {
        output.open()
        defer {
            output.close()
            source.close()
        }
        guard write(prefix) else { return }
        var chunk = [UInt8](repeating: 0, count: RequestBodyReader.chunkSize)
        while !isCancelled {
            let count = source.read(&chunk, maxLength: chunk.count)
            if count == 0 { return }
            if count < 0 {
                cancel()
                onFailure(source.streamError ?? URLError(.cannotDecodeRawData))
                return
            }
            guard write(Data(chunk[0..<count])) else { return }
        }
    }

    /// Writes all bytes; `false` when cancelled or the reading side went away.
    private func write(_ data: Data) -> Bool {
        var offset = 0
        var lastProgress = Date()
        while offset < data.count {
            if isCancelled { return false }
            if Date().timeIntervalSince(lastProgress) > Self.idleTimeout { return false }
            switch output.streamStatus {
            case .error, .closed, .atEnd: return false
            default: break
            }
            guard output.hasSpaceAvailable else {
                Thread.sleep(forTimeInterval: 0.002)
                continue
            }
            let written = data[offset...].withUnsafeBytes { bytes in
                output.write(bytes.bindMemory(to: UInt8.self).baseAddress!, maxLength: bytes.count)
            }
            guard written > 0 else { return false }
            offset += written
            lastProgress = Date()
            progress.withLock { $0.bytes += written }
        }
        return true
    }
}
