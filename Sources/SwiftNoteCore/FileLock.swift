import Darwin
import Foundation

public struct FileLock {
    public static func withExclusiveLock<T>(at url: URL, body: () throws -> T) throws -> T {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let descriptor = open(url.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else {
            throw SwiftNoteError.fileLockFailed(String(cString: strerror(errno)))
        }

        defer {
            close(descriptor)
        }

        guard flock(descriptor, LOCK_EX) == 0 else {
            throw SwiftNoteError.fileLockFailed(String(cString: strerror(errno)))
        }

        defer {
            flock(descriptor, LOCK_UN)
        }

        return try body()
    }
}

