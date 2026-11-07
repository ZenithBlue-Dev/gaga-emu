#if DEBUG
import Darwin
import os

/// Runtime half of the no-JIT gate (docs/04 section 8): finds code generation a symbol scan cannot see.
/// Debug and test builds only. Walks this process's memory map and reports, against a baseline:
/// - a new region that is both writable and executable
/// - a new executable region that no loaded image owns
/// A framework that loads lazily adds executable regions too, which is why the second rule asks dyld.
///
/// iOS is what denies JIT: W^X and no public entitlement, so RWX mappings silently come back without
/// execute on a device. This check exists to catch a core that tries, not to enforce anything.
enum CodeGenCheck {
    struct Region: Hashable, CustomStringConvertible {
        let start: UInt
        let size: UInt
        let protection: Int32
        let image: String?

        var writable: Bool { protection & VM_PROT_WRITE != 0 }

        var description: String {
            let flags = (protection & VM_PROT_READ != 0 ? "r" : "-") + (writable ? "w" : "-") + "x"
            return "\(String(start, radix: 16)) +\(size) \(flags) \(image ?? "no image")"
        }
    }

    private static let baselineLock = OSAllocatedUnfairLock<Set<Region>?>(initialState: nil)

    /// Every executable region now. Enters submaps, because the shared cache is one.
    static func executableRegions() -> [Region] {
        var regions: [Region] = []
        var address: vm_address_t = 0
        var depth: natural_t = 0
        while true {
            var size: vm_size_t = 0
            var info = vm_region_submap_info_64()
            var count = mach_msg_type_number_t(MemoryLayout<vm_region_submap_info_64>.size / MemoryLayout<natural_t>.size)
            let result = withUnsafeMutablePointer(to: &info) { pointer in
                pointer.withMemoryRebound(to: Int32.self, capacity: Int(count)) {
                    vm_region_recurse_64(mach_task_self_, &address, &size, &depth, $0, &count)
                }
            }
            guard result == KERN_SUCCESS else { break }
            if info.is_submap != 0 {
                depth += 1
                continue
            }
            if info.protection & VM_PROT_EXECUTE != 0 {
                regions.append(Region(start: address, size: size, protection: info.protection, image: imageName(address)))
            }
            address += size
        }
        return regions
    }

    private static func imageName(_ address: UInt) -> String? {
        var info = Dl_info()
        guard dladdr(UnsafeRawPointer(bitPattern: address), &info) != 0, let name = info.dli_fname else { return nil }
        return String(cString: name)
    }

    /// Call once early. Regions present then are taken as the app's own.
    static func captureBaseline() {
        let regions = Set(executableRegions())
        baselineLock.withLock { $0 = regions }
    }

    /// New regions that look like generated code. Empty means clean. Captures a baseline if none exists.
    static func violations() -> [Region] {
        guard let baseline = baselineLock.withLock({ $0 }) else {
            captureBaseline()
            return []
        }
        return executableRegions().filter { region in
            !baseline.contains(region) && (region.writable || region.image == nil)
        }
    }

    /// Debug builds report here and keep running, because a false positive must not stop play.
    static func report(_ context: String) {
        let found = violations()
        guard !found.isEmpty else { return }
        Logger(subsystem: "com.zenithblue.gagaemu", category: "nojit")
            .fault("code generation suspected, \(context, privacy: .public): \(found.description, privacy: .public)")
    }
}
#endif
