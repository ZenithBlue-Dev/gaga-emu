import Metal
import MetalKit

/// Zero-copy Apple Silicon UMA texture ring buffer.
/// Maps shared CPU-accessible MTLBuffers directly to GPU textures without PCIe / blit copies.
public final class MetalTextureRing {
    public let device: MTLDevice
    public let bufferCount: Int = 3

    private var buffers: [MTLBuffer] = []
    private var textures: [MTLTexture] = []
    private var writeIndex: Int = 0
    private var inFlightCount: Int = 0
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

        let bytesPerPixel: Int
        switch pixelFormat {
        case .bgra8Unorm, .rgba8Unorm:
            bytesPerPixel = 4
        case .b5g6r5Unorm:
            bytesPerPixel = 2
        default:
            bytesPerPixel = 4
        }

        let rawBytesPerRow = self.width * bytesPerPixel
        // Metal requires 256-byte row alignment for buffer-backed textures
        self.bytesPerRow = (rawBytesPerRow + 255) & ~255
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
                fatalError("Failed to allocate zero-copy shared Metal buffer")
            }

            #if targetEnvironment(simulator)
            // iOS Simulator's MTLSimBuffer limits buffer-backed linear textures to private storage.
            // In the simulator, instantiate an MTLDevice texture and mirror during submission.
            guard let tex = device.makeTexture(descriptor: descriptor) else {
                fatalError("Failed to allocate simulator Metal texture")
            }
            #else
            // Real iOS Apple Silicon hardware: true zero-copy shared memory buffer-backed texture
            guard let tex = buf.makeTexture(descriptor: descriptor, offset: 0, bytesPerRow: bytesPerRow) else {
                fatalError("Failed to allocate zero-copy shared Metal buffer")
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

        let bytesPerPixel = (pixelFormat == .b5g6r5Unorm) ? 2 : 4
        let rawBytesPerRow = self.width * bytesPerPixel
        self.bytesPerRow = (rawBytesPerRow + 255) & ~255
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

    /// Called by the Metal render submitter to register completion signaling.
    public func attachCompletion(to commandBuffer: MTLCommandBuffer) {
        commandBuffer.addCompletedHandler { [weak self] _ in
            guard let self = self else { return }
            self.lock.lock()
            if self.inFlightCount > 0 {
                self.inFlightCount -= 1
            }
            self.lock.unlock()
            self.inflightSemaphore.signal()
        }
    }
}
