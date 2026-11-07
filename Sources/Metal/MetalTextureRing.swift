import Metal
import MetalKit

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

    /// The alignment comes from the device and must not be hard-coded (docs/05 section 2.1).
    static func alignedBytesPerRow(device: MTLDevice, width: Int, pixelFormat: MTLPixelFormat) -> Int {
        let bytesPerPixel = pixelFormat == .b5g6r5Unorm ? 2 : 4
        let alignment = device.minimumLinearTextureAlignment(for: pixelFormat)
        return ((width * bytesPerPixel + alignment - 1) / alignment) * alignment
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

    /// Acquires direct raw CPU pointer for the core interpreter to write into.
    /// Thread blocks if all 3 buffers are currently in flight on the GPU.
    public func acquireWritableBuffer() -> (pointer: UnsafeMutableRawPointer, texture: MTLTexture, index: Int) {
        inflightSemaphore.wait()

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
    public func writeFrame(pixelData: UnsafeRawPointer, width: Int, height: Int, pitch: Int, pixelFormat: MTLPixelFormat) -> MTLTexture {
        reconfigureIfNeeded(width: width, height: height, pixelFormat: pixelFormat)

        let (dstPtr, texture, _) = acquireWritableBuffer()
        let bytesToCopyPerRow = min(pitch, bytesPerRow)

        for row in 0..<height {
            let srcRow = pixelData.advanced(by: row * pitch)
            let dstRow = dstPtr.advanced(by: row * bytesPerRow)
            memcpy(dstRow, srcRow, bytesToCopyPerRow)
        }

        #if targetEnvironment(simulator)
        let region = MTLRegionMake2D(0, 0, width, height)
        texture.replace(region: region, mipmapLevel: 0, withBytes: dstPtr, bytesPerRow: bytesPerRow)
        #endif

        return texture
    }

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
