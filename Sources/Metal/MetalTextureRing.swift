import Metal
import MetalKit
import UIKit

/// Three-slot ring of shared MTLBuffers, each with a texture over the same storage, so the GPU
/// reads what the CPU wrote without a blit. `writeFrame` still copies once from the core's buffer.
public final class MetalTextureRing {
    public let device: MTLDevice
    public let bufferCount: Int = 3

    private var buffers: [MTLBuffer] = []
    private var textures: [MTLTexture] = []
    private var writeIndex: Int = 0
    private var inFlightCount: Int = 0
    private var unpairedAcquires: Int = 0
    private let inflightSemaphore: DispatchSemaphore

    public private(set) var width: Int
    public private(set) var height: Int
    public private(set) var pixelFormat: MTLPixelFormat
    public private(set) var bytesPerRow: Int
    public private(set) var bufferSize: Int

    private let lock = NSLock()
    private var framesWritten = 0
    private var framesDropped = 0

    public var stats: (written: Int, dropped: Int, width: Int, height: Int, pixelFormat: MTLPixelFormat) {
        lock.lock()
        defer { lock.unlock() }
        return (framesWritten, framesDropped, width, height, pixelFormat)
    }

    /// Counts a frame a layer-path core presented itself, so its stats show frames as a copy-path core's do.
    public func noteLayerFrame() {
        lock.lock()
        framesWritten += 1
        lock.unlock()
    }

    public init(device: MTLDevice, width: Int, height: Int, pixelFormat: MTLPixelFormat = .rgba8Unorm) {
        self.device = device
        self.width = max(width, 1)
        self.height = max(height, 1)
        self.pixelFormat = pixelFormat
        self.inflightSemaphore = DispatchSemaphore(value: bufferCount)

        self.bytesPerRow = Self.alignedBytesPerRow(device: device, width: self.width, pixelFormat: pixelFormat)
        self.bufferSize = self.bytesPerRow * self.height

        allocateBuffers()
    }

    deinit {
        lock.lock()
        for _ in 0..<inFlightCount {
            inflightSemaphore.signal()
        }
        inFlightCount = 0
        lock.unlock()
    }

    /// The table in docs/05 section 2.1. Nil means the format is not one the bridge defines.
    public static func metalFormat(for format: GagaPixelFormat) -> MTLPixelFormat? {
        switch format {
        case GAGA_PIXEL_FORMAT_RGB565: return .b5g6r5Unorm
        case GAGA_PIXEL_FORMAT_XRGB8888: return .bgra8Unorm
        case GAGA_PIXEL_FORMAT_RGBA8888: return .rgba8Unorm
        default: return nil
        }
    }

    static func bytesPerPixel(_ pixelFormat: MTLPixelFormat) -> Int {
        pixelFormat == .b5g6r5Unorm ? 2 : 4
    }

    /// The alignment comes from the device and must not be hard-coded (docs/05 section 2.1).
    static func alignedBytesPerRow(device: MTLDevice, width: Int, pixelFormat: MTLPixelFormat) -> Int {
        let alignment = device.minimumLinearTextureAlignment(for: pixelFormat)
        return ((width * bytesPerPixel(pixelFormat) + alignment - 1) / alignment) * alignment
    }

    private func allocateBuffers() {
        buffers.removeAll(keepingCapacity: true)
        textures.removeAll(keepingCapacity: true)

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.storageMode = .shared
        descriptor.usage = [.shaderRead]

        for _ in 0..<bufferCount {
            guard let buf = device.makeBuffer(length: bufferSize, options: .storageModeShared) else {
                fatalError("Failed to allocate shared Metal buffer")
            }

            #if targetEnvironment(simulator)
            // iOS Simulator's MTLSimBuffer limits buffer-backed linear textures to private storage.
            // In the simulator, instantiate an MTLDevice texture and mirror during submission.
            guard let tex = device.makeTexture(descriptor: descriptor) else {
                fatalError("Failed to allocate simulator Metal texture")
            }
            #else
            // Device: the texture shares the buffer's storage.
            guard let tex = buf.makeTexture(descriptor: descriptor, offset: 0, bytesPerRow: bytesPerRow) else {
                fatalError("Failed to allocate buffer-backed Metal texture")
            }
            #endif

            buffers.append(buf)
            textures.append(tex)
        }
    }

    /// Reconfigures dimensions or pixel format if emulator core resizes.
    public func reconfigureIfNeeded(width: Int, height: Int, pixelFormat: MTLPixelFormat) {
        lock.lock()
        defer { lock.unlock() }

        if self.width == width && self.height == height && self.pixelFormat == pixelFormat {
            return
        }

        self.width = max(width, 1)
        self.height = max(height, 1)
        self.pixelFormat = pixelFormat

        self.bytesPerRow = Self.alignedBytesPerRow(device: device, width: self.width, pixelFormat: pixelFormat)
        self.bufferSize = self.bytesPerRow * self.height

        allocateBuffers()
        writeIndex = 0
    }

    /// Acquires a slot's CPU pointer, or returns nil when all three are unreleased. It never blocks: a
    /// paused or slow view must not stall emulation or audio, and a pause or teardown waits for the
    /// frame in flight on the main thread, which is the thread whose draws release slots.
    /// shortcut: a repeat draw holds no token, so a GPU stall longer than two frames can tear one frame, pair tokens with slots if it shows.
    public func acquireWritableBuffer() -> (pointer: UnsafeMutableRawPointer, texture: MTLTexture, index: Int)? {
        guard inflightSemaphore.wait(timeout: .now()) == .success else { return nil }

        lock.lock()
        inFlightCount += 1
        unpairedAcquires += 1
        let idx = writeIndex
        writeIndex = (writeIndex + 1) % bufferCount
        let buf = buffers[idx]
        let tex = textures[idx]
        lock.unlock()

        return (buf.contents(), tex, idx)
    }

    /// Writes raw pixel data with pitch into the next available shared buffer.
    /// Returns nil, dropping the frame, when no slot is free. One writer thread only.
    public func writeFrame(pixelData: UnsafeRawPointer, width: Int, height: Int, pitch: Int, pixelFormat: MTLPixelFormat) -> MTLTexture? {
        #if targetEnvironment(simulator)
        // The simulator's GPU has no 16-bit formats, and asking for one aborts. Expand to BGRA there.
        let expand565 = pixelFormat == .b5g6r5Unorm
        reconfigureIfNeeded(width: width, height: height, pixelFormat: expand565 ? .bgra8Unorm : pixelFormat)
        #else
        reconfigureIfNeeded(width: width, height: height, pixelFormat: pixelFormat)
        #endif

        guard let (dstPtr, texture, _) = acquireWritableBuffer() else {
            lock.lock()
            framesDropped += 1
            lock.unlock()
            return nil
        }
        // A pitch wider than the row is padding in the core's buffer, which the slot has no room for.
        let bytesToCopyPerRow = min(pitch, width * Self.bytesPerPixel(pixelFormat))

        for row in 0..<height {
            let srcRow = pixelData.advanced(by: row * pitch)
            let dstRow = dstPtr.advanced(by: row * bytesPerRow)
            #if targetEnvironment(simulator)
            if expand565 {
                Self.expand565(srcRow, to: dstRow, pixels: bytesToCopyPerRow / 2)
                continue
            }
            #endif
            memcpy(dstRow, srcRow, bytesToCopyPerRow)
        }

        #if targetEnvironment(simulator)
        let region = MTLRegionMake2D(0, 0, width, height)
        texture.replace(region: region, mipmapLevel: 0, withBytes: dstPtr, bytesPerRow: bytesPerRow)
        #endif

        lock.lock()
        framesWritten += 1
        lock.unlock()
        return texture
    }

    /// A layer-path core's off-screen frame (docs/05 section 2.4): a GPU copy into the next slot, encoded on
    /// `blit`. Returns nil, dropping the frame, when no slot is free. One writer thread only.
    public func copyFrame(_ source: MTLTexture, with blit: MTLBlitCommandEncoder) -> MTLTexture? {
        reconfigureIfNeeded(width: source.width, height: source.height, pixelFormat: source.pixelFormat)
        guard let (_, texture, _) = acquireWritableBuffer() else {
            lock.lock()
            framesDropped += 1
            lock.unlock()
            return nil
        }
        blit.copy(from: source, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(),
                  sourceSize: MTLSize(width: source.width, height: source.height, depth: 1),
                  to: texture, destinationSlice: 0, destinationLevel: 0, destinationOrigin: MTLOrigin())
        lock.lock()
        framesWritten += 1
        lock.unlock()
        return texture
    }

    /// The newest frame as a PNG, for a save state's thumbnail. Reads shared memory, so it does no GPU
    /// work and is safe in the background. Call only between frames.
    public func latestFramePNG() -> Data? {
        lock.lock()
        defer { lock.unlock() }
        guard framesWritten > 0 else { return nil }
        let slot = (writeIndex + bufferCount - 1) % bufferCount
        let bytes = Data(bytes: buffers[slot].contents(), count: bufferSize)
        return Self.png(bytes, width: width, height: height, bytesPerRow: bytesPerRow, pixelFormat: pixelFormat)
    }

    /// Also encodes a layer-path core's read-back frame, which never passes through a ring.
    public static func png(_ bytes: Data, width: Int, height: Int, bytesPerRow: Int, pixelFormat: MTLPixelFormat) -> Data? {
        let bitmap: CGBitmapInfo
        switch pixelFormat {
        case .rgba8Unorm: bitmap = [.byteOrder32Big, CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)]
        case .bgra8Unorm: bitmap = [.byteOrder32Little, CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue)]
        case .b5g6r5Unorm: bitmap = [.byteOrder16Little, CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)]
        default: return nil
        }
        let wide = pixelFormat != .b5g6r5Unorm
        guard let provider = CGDataProvider(data: bytes as CFData),
              let image = CGImage(width: width, height: height, bitsPerComponent: wide ? 8 : 5,
                                  bitsPerPixel: wide ? 32 : 16, bytesPerRow: bytesPerRow,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: bitmap, provider: provider,
                                  decode: nil, shouldInterpolate: false, intent: .defaultIntent) else { return nil }
        return UIImage(cgImage: image).pngData()
    }

    #if targetEnvironment(simulator)
    static func expand565(_ source: UnsafeRawPointer, to destination: UnsafeMutableRawPointer, pixels: Int) {
        let input = source.assumingMemoryBound(to: UInt16.self)
        let output = destination.assumingMemoryBound(to: UInt32.self)
        for index in 0..<pixels {
            let pixel = UInt32(input[index])
            let r = pixel >> 11 & 0x1F, g = pixel >> 5 & 0x3F, b = pixel & 0x1F
            output[index] = 0xFF00_0000 | (r << 3 | r >> 2) << 16 | (g << 2 | g >> 4) << 8 | (b << 3 | b >> 2)
        }
    }
    #endif

    /// Called by the Metal render submitter. Each acquire pairs with exactly one completion signal,
    /// so redrawing the same frame attaches nothing and returns false.
    @discardableResult
    public func attachCompletion(to commandBuffer: MTLCommandBuffer) -> Bool {
        lock.lock()
        guard unpairedAcquires > 0 else {
            lock.unlock()
            return false
        }
        unpairedAcquires -= 1
        lock.unlock()

        commandBuffer.addCompletedHandler { [weak self] _ in
            guard let self = self else { return }
            self.lock.lock()
            if self.inFlightCount > 0 {
                self.inFlightCount -= 1
            }
            self.lock.unlock()
            self.inflightSemaphore.signal()
        }
        return true
    }
}
