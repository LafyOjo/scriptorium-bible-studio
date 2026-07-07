import CoreText
import Foundation
import UIKit

enum ExportKind: String, CaseIterable, Identifiable {
    case text
    case html
    case rtf
    case pdf
    case json

    var id: String { rawValue }

    var label: String {
        switch self {
        case .text: return "TXT"
        case .html: return "HTML"
        case .rtf: return "RTF"
        case .pdf: return "PDF"
        case .json: return "JSON"
        }
    }

    var systemImage: String {
        switch self {
        case .text: return "doc.plaintext"
        case .html: return "chevron.left.forwardslash.chevron.right"
        case .rtf: return "textformat"
        case .pdf: return "doc.richtext"
        case .json: return "archivebox"
        }
    }
}

enum ExportService {
    static func chapterURL(chapter: SBChapter, book: SBBook?, kind: ExportKind) throws -> URL {
        let base = safeFilename("\(book?.name ?? "chapter")-\(chapter.number)-\(chapter.title)")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(base).\(fileExtension(for: kind))")
        let attributed = AttributedContent.fromRTFData(chapter.contentData)

        switch kind {
        case .text:
            try chapter.plainText.write(to: url, atomically: true, encoding: .utf8)
        case .html:
            let data = AttributedContent.htmlData(from: attributed) ?? Data()
            try data.write(to: url, options: .atomic)
        case .rtf:
            let data = AttributedContent.rtfData(from: attributed) ?? Data()
            try data.write(to: url, options: .atomic)
        case .pdf:
            try writePDF(url: url, title: "\(book?.name ?? "") \(chapter.number): \(chapter.title)", attributed: attributed)
        case .json:
            let payload = ChapterExport(
                book: book?.name,
                chapterNumber: chapter.number,
                title: chapter.title,
                status: chapter.status,
                tags: chapter.tagArray,
                plainText: chapter.plainText,
                rtfBase64: chapter.contentData?.base64EncodedString(),
                updatedAt: chapter.updatedAt
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(payload).write(to: url, options: .atomic)
        }

        return url
    }

    static func backupURL(data: Data) throws -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("scriptorium-backup-\(formatter.string(from: Date())).json")
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func fileExtension(for kind: ExportKind) -> String {
        switch kind {
        case .text: return "txt"
        case .html: return "html"
        case .rtf: return "rtf"
        case .pdf: return "pdf"
        case .json: return "json"
        }
    }

    private static func safeFilename(_ string: String) -> String {
        string
            .replacingOccurrences(of: "[^A-Za-z0-9_-]+", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
            .lowercased()
    }

    private static func writePDF(url: URL, title: String, attributed: NSAttributedString) throws {
        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let margin: CGFloat = 56
        let textFrame = CGRect(
            x: margin,
            y: margin + 44,
            width: pageBounds.width - margin * 2,
            height: pageBounds.height - margin * 2 - 44
        )

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: AttributedContent.displayFont(size: 19, weight: .semibold),
            .foregroundColor: UIColor.label,
        ]
        let titleString = NSAttributedString(string: title, attributes: titleAttributes)

        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)
        try renderer.writePDF(to: url) { context in
            var currentRange = CFRange(location: 0, length: 0)
            let framesetter = CTFramesetterCreateWithAttributedString(attributed)

            repeat {
                context.beginPage()
                titleString.draw(in: CGRect(x: margin, y: margin, width: pageBounds.width - margin * 2, height: 28))

                guard let graphicsContext = UIGraphicsGetCurrentContext() else { break }
                graphicsContext.saveGState()
                graphicsContext.textMatrix = .identity
                graphicsContext.translateBy(x: 0, y: pageBounds.height)
                graphicsContext.scaleBy(x: 1, y: -1)

                let path = CGMutablePath()
                let flippedFrame = CGRect(
                    x: textFrame.minX,
                    y: pageBounds.height - textFrame.maxY,
                    width: textFrame.width,
                    height: textFrame.height
                )
                path.addRect(flippedFrame)
                let frame = CTFramesetterCreateFrame(framesetter, currentRange, path, nil)
                CTFrameDraw(frame, graphicsContext)
                graphicsContext.restoreGState()

                let visibleRange = CTFrameGetVisibleStringRange(frame)
                guard visibleRange.length > 0 else { break }
                currentRange.location += visibleRange.length
            } while currentRange.location < attributed.length
        }
    }
}

private struct ChapterExport: Codable {
    var book: String?
    var chapterNumber: Int64
    var title: String
    var status: String
    var tags: [String]
    var plainText: String
    var rtfBase64: String?
    var updatedAt: Date
}
