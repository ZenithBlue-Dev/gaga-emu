import Metal
import XCTest
@testable import GagaEmu

/// The catalogue's table, its fragments, and what each filter costs on this device.
final class ShaderLibraryTests: GagaTestCase {
    private func device() throws -> MTLDevice { try XCTUnwrap(MTLCreateSystemDefaultDevice()) }

    func testEveryEntryHasACaseAndFragment() throws {
        let library = try XCTUnwrap(device().makeDefaultLibrary())
        XCTAssertGreaterThanOrEqual(ShaderLibrary.entries.count, 50)
        for entry in ShaderLibrary.entries {
            let preset = try XCTUnwrap(ShaderPreset(rawValue: entry.id), entry.id)
            XCTAssertEqual(preset.displayName, entry.name)
            XCTAssertNotNil(library.makeFunction(name: ShaderLibrary.fragment(entry.id)), entry.id)
            XCTAssertTrue(preset.parameters.contains(.colorTemp), entry.id)
        }
        XCTAssertEqual(Set(ShaderLibrary.entries.map(\.id)).count, ShaderLibrary.entries.count, "duplicate id")
        let cases = ShaderPreset.allCases.filter { $0.rawValue.hasPrefix("cat-") }
        XCTAssertEqual(cases.count, ShaderLibrary.entries.count)
        XCTAssertTrue(ShaderLibrary.entries.contains { $0.category == .colour })
        XCTAssertEqual(Set(ShaderCatalog.all.map(\.id)).count, ShaderCatalog.all.count)
    }

    private func source(_ device: MTLDevice, width: Int, height: Int) throws -> MTLTexture {
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
        desc.usage = .shaderRead
        let texture = try XCTUnwrap(device.makeTexture(descriptor: desc))
        var pixels = [UInt32](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                // A checker, a colour ramp and a disc, so edge-directed filters have diagonals to work on.
                let (dx, dy) = (x - width / 2, y - height / 2)
                if dx * dx + dy * dy < (height / 3) * (height / 3) {
                    pixels[y * width + x] = 0xFFE0_4020
                } else if (x / 16 + y / 16) % 2 == 0 {
                    pixels[y * width + x] = 0xFF00_0000 | UInt32(x & 0xFF) << 16 | UInt32(y & 0xFF) << 8 | 0x40
                }
            }
        }
        texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: pixels, bytesPerRow: width * 4)
        return texture
    }

    private func target(_ device: MTLDevice, width: Int, height: Int) throws -> MTLTexture {
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
        desc.usage = [.renderTarget, .shaderRead]
        return try XCTUnwrap(device.makeTexture(descriptor: desc))
    }

    /// Every filter draws a picture that is not all one colour and does not hang the GPU.
    func testEveryFilterRenders() throws {
        let device = try device()
        let renderer = try XCTUnwrap(MetalRenderer(device: device))
        renderer.setTexture(try source(device, width: 256, height: 224))
        var pictures: [String: [UInt32]] = [:]
        for shader in ShaderCatalog.all {
            renderer.activePreset = ShaderPreset.from(id: shader.id)
            renderer.apply(ShaderParameterValues())
            var pixels = [UInt32](repeating: 0, count: 320 * 240)
            let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 320, height: 240, mipmapped: false)
            desc.usage = [.renderTarget, .shaderRead]
            desc.storageMode = .shared
            let readable = try XCTUnwrap(device.makeTexture(descriptor: desc))
            renderer.render(into: readable)
            readable.getBytes(&pixels, bytesPerRow: 320 * 4, from: MTLRegionMake2D(0, 0, 320, 240), mipmapLevel: 0)
            XCTAssertGreaterThan(Set(pixels.map { $0 & 0x00FF_FFFF }).count, 2, shader.id)
            pictures[shader.id] = pixels.map { $0 & 0x00FF_FFFF }
        }
        // Distinct effects: no filter may draw exactly what another draws.
        let ids = pictures.keys.sorted()
        for (index, first) in ids.enumerated() {
            for second in ids[(index + 1)...] where pictures[first] == pictures[second] {
                XCTFail("\(first) and \(second) draw the same picture")
            }
        }
    }

    /// GPU cost per frame at a real N64 and PSP picture size on a phone-sized target. Logged, not gated.
    func testFrameCostOfHeaviestFilters() throws {
        let device = try device()
        let renderer = try XCTUnwrap(MetalRenderer(device: device))
        let heavy = ["original", "crt-deluxe", "anime4k", "lottes-crt", "cat-crt-arcade", "cat-xbr", "cat-kuwahara", "cat-bilateral", "cat-lanczos2", "cat-ntsc"]
        let output = try target(device, width: 2622, height: 1206)
        for (label, width, height) in [("N64 640x480", 640, 480), ("PSP 960x544", 960, 544)] {
            renderer.setTexture(try source(device, width: width, height: height))
            for id in heavy {
                renderer.activePreset = ShaderPreset.from(id: id)
                renderer.apply(ShaderParameterValues())
                renderer.render(into: output) // Pipelines compile on the first frame.
                let start = CACurrentMediaTime()
                for _ in 0..<60 { renderer.render(into: output) }
                print("FRAMECOST \(label) \(id) \(String(format: "%.2f", (CACurrentMediaTime() - start) / 60 * 1000)) ms")
            }
        }
    }
}
