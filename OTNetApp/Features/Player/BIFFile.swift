import Foundation
import UIKit

/// Lightweight BIF (Base Index File) parser. BIF holds one JPEG per N seconds
/// of video; we use it for the Netflix-style scrub thumbnail.
///
/// Format reference: https://developer.roku.com/docs/developer-program/media-playback/trick-mode/bif-file-creation.md
struct BIFFile {
    /// Seconds between consecutive thumbnails.
    let interval: TimeInterval
    /// Total thumbnail count.
    let count: Int

    private let data: Data
    private let entries: [(timestamp: UInt32, offset: UInt32, size: Int)]

    init?(data: Data) {
        guard data.count > 64 else { return nil }
        // Magic: 0x89 'B' 'I' 'F' 0x0D 0x0A 0x1A 0x0A
        let magic: [UInt8] = [0x89, 0x42, 0x49, 0x46, 0x0D, 0x0A, 0x1A, 0x0A]
        for (i, b) in magic.enumerated() where data[i] != b { return nil }

        // _ = data.readUInt32LE(at: 8)              // version
        let imageCount = data.readUInt32LE(at: 12)
        let multiplier = data.readUInt32LE(at: 16)  // ms between thumbs
        guard imageCount > 0, multiplier > 0 else { return nil }

        var entries: [(UInt32, UInt32, Int)] = []
        // Index starts after 64-byte header. Each entry is 8 bytes.
        // There are imageCount + 1 entries (last is a sentinel with EOF offset).
        var offset = 64
        for _ in 0..<imageCount {
            let ts = data.readUInt32LE(at: offset)
            let off = data.readUInt32LE(at: offset + 4)
            entries.append((ts, off, 0))
            offset += 8
        }
        let endTs = data.readUInt32LE(at: offset)        // 0xFFFFFFFF
        let endOff = data.readUInt32LE(at: offset + 4)
        _ = endTs

        // Compute each entry's size from the difference between consecutive offsets.
        var sized: [(UInt32, UInt32, Int)] = []
        for i in 0..<entries.count {
            let cur = entries[i]
            let nextOff = (i + 1 < entries.count) ? entries[i + 1].1 : endOff
            let size = Int(nextOff) - Int(cur.1)
            guard size > 0, Int(cur.1) + size <= data.count else { return nil }
            sized.append((cur.0, cur.1, size))
        }

        self.data = data
        self.entries = sized
        self.count = sized.count
        self.interval = TimeInterval(multiplier) / 1000.0
    }

    /// Returns the JPEG-decoded thumbnail closest to the given playback second.
    func image(at seconds: Double) -> UIImage? {
        guard !entries.isEmpty else { return nil }
        let approxIndex = Int((seconds / interval).rounded(.down))
        let clamped = max(0, min(entries.count - 1, approxIndex))
        let entry = entries[clamped]
        let jpegRange = Int(entry.offset)..<(Int(entry.offset) + entry.size)
        guard jpegRange.upperBound <= data.count else { return nil }
        return UIImage(data: data.subdata(in: jpegRange))
    }
}

actor BIFLoader {
    static let shared = BIFLoader()
    private var cache: [URL: BIFFile] = [:]
    private var inflight: [URL: Task<BIFFile?, Never>] = [:]

    func load(_ url: URL) async -> BIFFile? {
        if let cached = cache[url] { return cached }
        if let existing = inflight[url] { return await existing.value }
        let task = Task<BIFFile?, Never> {
            do {
                var req = URLRequest(url: url)
                req.cachePolicy = .returnCacheDataElseLoad
                let (data, _) = try await URLSession.shared.data(for: req)
                return BIFFile(data: data)
            } catch {
                return nil
            }
        }
        inflight[url] = task
        let result = await task.value
        inflight[url] = nil
        if let result { cache[url] = result }
        return result
    }
}

private extension Data {
    func readUInt32LE(at offset: Int) -> UInt32 {
        guard offset + 4 <= count else { return 0 }
        return withUnsafeBytes { buf in
            let p = buf.baseAddress!.advanced(by: offset).assumingMemoryBound(to: UInt8.self)
            return UInt32(p[0]) | (UInt32(p[1]) << 8) | (UInt32(p[2]) << 16) | (UInt32(p[3]) << 24)
        }
    }
}
