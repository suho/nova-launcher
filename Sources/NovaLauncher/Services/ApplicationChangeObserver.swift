import CoreServices
import Foundation

final class ApplicationChangeObserver {
    private final class CallbackBox {
        let onChange: @Sendable () -> Void

        init(onChange: @escaping @Sendable () -> Void) {
            self.onChange = onChange
        }
    }

    private let watchedURLs: [URL]
    private let queue = DispatchQueue(label: "app.novalauncher.application-change-observer")
    private let callbackBox: CallbackBox
    private var stream: FSEventStreamRef?

    init(watchedURLs: [URL], onChange: @escaping @Sendable () -> Void) {
        self.watchedURLs = watchedURLs
        self.callbackBox = CallbackBox(onChange: onChange)
    }

    deinit {
        stop()
    }

    func start() {
        guard stream == nil else {
            return
        }

        let existingPaths = watchedURLs
            .filter { FileManager.default.fileExists(atPath: $0.path) }
            .map(\.path) as CFArray

        guard CFArrayGetCount(existingPaths) > 0 else {
            return
        }

        var context = FSEventStreamContext(
            version: 0,
            info: UnsafeMutableRawPointer(Unmanaged.passUnretained(callbackBox).toOpaque()),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagUseCFTypes
                | kFSEventStreamCreateFlagFileEvents
                | kFSEventStreamCreateFlagNoDefer
                | kFSEventStreamCreateFlagWatchRoot
        )

        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            Self.handleEvents,
            &context,
            existingPaths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0,
            flags
        ) else {
            return
        }

        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
    }

    func stop() {
        guard let stream else {
            return
        }

        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    private static let handleEvents: FSEventStreamCallback = { _, contextInfo, eventCount, eventPaths, eventFlags, _ in
        guard let contextInfo else {
            return
        }

        let callbackBox = Unmanaged<CallbackBox>.fromOpaque(contextInfo).takeUnretainedValue()
        let paths = unsafeBitCast(eventPaths, to: CFArray.self)

        for index in 0..<eventCount {
            let pathValue = CFArrayGetValueAtIndex(paths, index)
            let path = unsafeBitCast(pathValue, to: CFString.self) as String
            let flags = eventFlags[index]

            guard eventLikelyTouchesApplication(path: path, flags: flags) else {
                continue
            }

            callbackBox.onChange()
            return
        }
    }

    private static func eventLikelyTouchesApplication(path: String, flags: FSEventStreamEventFlags) -> Bool {
        if hasFlag(kFSEventStreamEventFlagRootChanged, in: flags)
            || hasFlag(kFSEventStreamEventFlagMount, in: flags)
            || hasFlag(kFSEventStreamEventFlagUnmount, in: flags) {
            return true
        }

        guard path.contains(".app") else {
            return false
        }

        return hasFlag(kFSEventStreamEventFlagItemCreated, in: flags)
            || hasFlag(kFSEventStreamEventFlagItemRemoved, in: flags)
            || hasFlag(kFSEventStreamEventFlagItemRenamed, in: flags)
            || hasFlag(kFSEventStreamEventFlagItemModified, in: flags)
            || hasFlag(kFSEventStreamEventFlagItemInodeMetaMod, in: flags)
            || hasFlag(kFSEventStreamEventFlagItemXattrMod, in: flags)
            || hasFlag(kFSEventStreamEventFlagItemChangeOwner, in: flags)
    }

    private static func hasFlag(
        _ flag: Int,
        in flags: FSEventStreamEventFlags
    ) -> Bool {
        flags & FSEventStreamEventFlags(flag) != 0
    }
}
