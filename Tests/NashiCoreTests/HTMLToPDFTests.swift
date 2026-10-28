import XCTest
import AppKit
import PDFKit
@testable import NashiCore

final class HTMLToPDFTests: XCTestCase {
    private var root: URL!
    private var site: URL!
    override func setUpWithError() throws {
        root = try OutputFiles.temporaryDirectory().resolvingSymlinksInPath()
        site = root.appendingPathComponent("Site", isDirectory: true)
        try FileManager.default.createDirectory(at: site.appendingPathComponent("assets", isDirectory: true), withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { if let root { try? FileManager.default.removeItem(at: root) } }

    func testHTMLAndHTMInputsOfferPDF() {
        XCTAssertEqual(FeatureCatalog.formats(for: [URL(fileURLWithPath: "/tmp/page.html")]), ["pdf"])
        XCTAssertEqual(FeatureCatalog.formats(for: [URL(fileURLWithPath: "/tmp/page.HTM"), URL(fileURLWithPath: "/tmp/other.html")]), ["pdf"])
        XCTAssertEqual(FeatureCatalog.tools(for: [URL(fileURLWithPath: "/tmp/page.html")]), [])
    }

    func testHTMLPrintsBrowserLayoutLocalAssetsAndUndeclaredUTF8() throws {
        try Self.png(255, 128, 0).write(to: site.appendingPathComponent("assets/orange.png"))
        try "header { display: flex; justify-content: space-between } .box { width: 80px; height: 80px; background: #00C8C8 }".write(to: site.appendingPathComponent("site.css"), atomically: true, encoding: .utf8)
        // Without a charset declaration, WebKit alone would read these bytes as Windows-1252.
        let input = site.appendingPathComponent("Fatura.html")
        try Data("""
        <!doctype html><html><head><title>Fatura Şişli</title><link rel="stylesheet" href="site.css"><script>document.write('Script ran')</script></head>
        <body style="margin:32px"><header><span>Left column</span><span>Right column</span></header><p>Merhaba Şişli ğüşıöç İ</p>
        <img src="assets/orange.png"><div class="box"></div><table style="width:100%;border-collapse:collapse"><tr><td style="border:1px solid">Ürün</td><td style="border:1px solid">Adet</td></tr></table>
        <p><a href="next.html">Next page</a> <a href="https://example.com/terms">Terms</a></p><p style="page-break-before:always">Second page</p></body></html>
        """.utf8).write(to: input)
        let original = try Data(contentsOf: input)
        let output = try XCTUnwrap(ConversionEngine.run(.init(inputs: [input], operation: .convert("pdf"))).first)
        XCTAssertEqual(output, site.appendingPathComponent("Fatura.pdf"))
        let pdf = try XCTUnwrap(PDFDocument(url: output))
        XCTAssertEqual(pdf.pageCount, 2)
        let text = try XCTUnwrap(pdf.string)
        XCTAssertTrue(text.contains("Merhaba Şişli ğüşıöç İ"), text)
        XCTAssertTrue(text.contains("Ürün"))
        XCTAssertTrue(text.contains("Second page"))
        XCTAssertFalse(text.contains("Script ran"))
        XCTAssertEqual(pdf.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String, "Fatura Şişli")
        // Flex layout keeps both labels on one line, at opposite page edges.
        let page = try XCTUnwrap(pdf.page(at: 0)), width = page.bounds(for: .mediaBox).width
        let left = try XCTUnwrap(pdf.findString("Left column", withOptions: []).first).bounds(for: page)
        let right = try XCTUnwrap(pdf.findString("Right column", withOptions: []).first).bounds(for: page)
        XCTAssertLessThan(left.minX, width / 4)
        XCTAssertGreaterThan(right.maxX, width * 3 / 4)
        XCTAssertEqual(left.midY, right.midY, accuracy: 2)
        XCTAssertGreaterThan(try Self.pixels(near: (255, 128, 0), on: page), 1000)
        XCTAssertGreaterThan(try Self.pixels(near: (0, 200, 200), on: page), 1000)
        // A link to a file beside the page cannot open from a shared PDF; web links stay.
        XCTAssertEqual(page.annotations.compactMap { $0.url?.absoluteString }, ["https://example.com/terms"])
        XCTAssertEqual(try Data(contentsOf: input), original)
    }

    func testHTMLReadsOnlyItsFolderAndNeverContactsTheNetwork() throws {
        let probe = try ConnectionProbe()
        defer { probe.close() }
        let remote = "http://127.0.0.1:\(probe.port)"
        // The control request proves the listener sees loopback traffic. URLSession may retry it.
        URLSession.shared.dataTask(with: URL(string: remote + "/control")!).resume()
        XCTAssertTrue(wait { probe.connections > 0 })
        _ = wait(seconds: 0.5) { false }
        let control = probe.connections
        let outside = root.appendingPathComponent("outside.png")
        try Self.png(255, 0, 255).write(to: outside)
        try FileManager.default.createSymbolicLink(at: site.appendingPathComponent("assets/linked.png"), withDestinationURL: outside)
        try "@import url('\(remote)/nested.css'); p { background-image: url('\(remote)/nested.png') }".write(to: site.appendingPathComponent("local.css"), atomically: true, encoding: .utf8)
        let input = site.appendingPathComponent("Probe.html")
        try """
        <!doctype html><html><head><meta charset="utf-8"><meta http-equiv="refresh" content="0;url=\(remote)/refresh">
        <link rel="stylesheet" href="\(remote)/style.css"><link rel="stylesheet" href="local.css"><link rel="preconnect" href="\(remote)"><link rel="prefetch" href="\(remote)/prefetch">
        <style>@import url('\(remote)/import.css'); @font-face { font-family: Remote; src: url('\(remote)/font.woff2') } body { font-family: Remote; background: url('\(remote)/background.png') }</style></head>
        <body><p>Offline probe</p><img src="\(remote)/image.png"><img srcset="\(remote)/srcset.png 1x"><img loading="lazy" src="\(remote)/lazy.png">
        <video src="\(remote)/video.mp4" poster="\(remote)/poster.png" preload="auto" autoplay></video><iframe src="\(remote)/frame"></iframe><object data="\(remote)/object"></object>
        <svg width="20" height="20"><image href="\(remote)/svg.png" width="20" height="20"/></svg>
        <img src="../outside.png"><img src="\(outside.absoluteString)"><img src="assets/linked.png"><iframe src="../outside.png"></iframe></body></html>
        """.write(to: input, atomically: true, encoding: .utf8)
        let output = try XCTUnwrap(ConversionEngine.run(.init(inputs: [input], operation: .convert("pdf"))).first)
        _ = wait(seconds: 1) { false }
        XCTAssertEqual(probe.connections, control, "The conversion opened a network connection.")
        let pdf = try XCTUnwrap(PDFDocument(url: output))
        XCTAssertTrue(pdf.string?.contains("Offline probe") == true)
        for index in 0..<pdf.pageCount { XCTAssertEqual(try Self.pixels(near: (255, 0, 255), on: XCTUnwrap(pdf.page(at: index))), 0, "A file outside the page's folder was rendered.") }
        XCTAssertNil(try Data(contentsOf: output).range(of: Data("file:".utf8)))
    }

    func testCancellationAndPageLimitPublishNothing() throws {
        let long = site.appendingPathComponent("Long.html")
        try ("<!doctype html><meta charset=\"utf-8\">" + String(repeating: "<p>" + String(repeating: "Nashi cancellation fixture. ", count: 60) + "</p>", count: 600)).write(to: long, atomically: true, encoding: .utf8)
        let token = CancellationToken()
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) { token.cancel() }
        XCTAssertThrowsError(try ConversionEngine.run(.init(inputs: [long], operation: .convert("pdf")), token: token)) { error in
            guard case NashiError.cancelled = error else { return XCTFail("\(error)") }
        }
        let tall = site.appendingPathComponent("Tall.html")
        try "<!doctype html><p>Top</p><div style=\"height:10000000px\"></div>".write(to: tall, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try ConversionEngine.run(.init(inputs: [tall], operation: .convert("pdf")))) { error in
            XCTAssertEqual(error.localizedDescription, "This HTML file would need more than 1,000 PDF pages.")
        }
        _ = wait(seconds: 2) { false }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: site.path).sorted(), ["Long.html", "Tall.html", "assets"])
    }

    /// Keeps the main run loop turning, as WebKit and URLSession callbacks need it.
    private func wait(seconds: TimeInterval = 10, until condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while !condition() && Date() < deadline { _ = RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01)) }
        return condition()
    }

    private static func png(_ red: UInt8, _ green: UInt8, _ blue: UInt8) throws -> Data {
        let bitmap = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 80, pixelsHigh: 80, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        for y in 0..<80 { for x in 0..<80 { bitmap.setColor(NSColor(deviceRed: CGFloat(red) / 255, green: CGFloat(green) / 255, blue: CGFloat(blue) / 255, alpha: 1), atX: x, y: y) } }
        return try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
    }

    private static func pixels(near color: (Int, Int, Int), on page: PDFPage) throws -> Int {
        let bounds = page.bounds(for: .mediaBox), width = Int(bounds.width), height = Int(bounds.height)
        let context = try XCTUnwrap(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        page.draw(with: .mediaBox, to: context)
        let bytes = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
        return (0..<(width * height)).filter { abs(Int(bytes[$0 * 4]) - color.0) < 40 && abs(Int(bytes[$0 * 4 + 1]) - color.1) < 40 && abs(Int(bytes[$0 * 4 + 2]) - color.2) < 40 }.count
    }

    /// Counts TCP connections to a loopback port, including ones that never send a request.
    private final class ConnectionProbe: @unchecked Sendable {
        let port: Int
        private let descriptor: Int32
        private let lock = NSLock()
        private var accepted = 0
        init() throws {
            let descriptor = Darwin.socket(AF_INET, SOCK_STREAM, 0)
            var address = sockaddr_in()
            address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            address.sin_family = sa_family_t(AF_INET)
            address.sin_addr.s_addr = inet_addr("127.0.0.1")
            var length = socklen_t(MemoryLayout<sockaddr_in>.size)
            let listening = withUnsafeMutablePointer(to: &address) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.bind(descriptor, $0, length) == 0 && Darwin.listen(descriptor, 64) == 0 && Darwin.getsockname(descriptor, $0, &length) == 0 }
            }
            guard descriptor >= 0, listening else { throw NashiError.failed("The loopback listener could not start.") }
            self.descriptor = descriptor
            port = Int(UInt16(bigEndian: address.sin_port))
            Thread.detachNewThread { [self] in
                while true {
                    let client = Darwin.accept(descriptor, nil, nil)
                    guard client >= 0 else { return }
                    lock.lock(); accepted += 1; lock.unlock()
                    Darwin.close(client)
                }
            }
        }
        var connections: Int { lock.lock(); defer { lock.unlock() }; return accepted }
        func close() { Darwin.shutdown(descriptor, SHUT_RDWR); Darwin.close(descriptor) }
    }
}
