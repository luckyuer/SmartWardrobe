import Foundation
import UIKit

actor ImageStorageService {

    private let fileManager = FileManager.default

    private var appSupportDirectory: URL {
        let urls = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appDir = urls[0].appendingPathComponent("SmartWardrobe", isDirectory: true)

        if !fileManager.fileExists(atPath: appDir.path) {
            try? fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)
        }

        return appDir
    }

    private var imagesDirectory: URL {
        let dir = appSupportDirectory.appendingPathComponent("Images", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private var thumbnailsDirectory: URL {
        let dir = appSupportDirectory.appendingPathComponent("Thumbnails", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    func saveImage(_ image: UIImage, withID id: UUID) throws -> String {
        guard let jpegData = image.jpegData(compressionQuality: 0.8) else {
            throw StorageError.imageCompressionFailed
        }

        let filename = "\(id.uuidString).jpg"
        let fileURL = imagesDirectory.appendingPathComponent(filename)
        try jpegData.write(to: fileURL)

        return filename
    }

    func saveThumbnail(_ image: UIImage, withID id: UUID) throws -> String {
        let targetSize = CGSize(width: 200, height: 200)
        let scaled = image.preparingForDisplay()?.preparingThumbnail(
            of: targetSize,
            using: .none
        ) ?? scaleImage(image, to: targetSize)

        guard let jpegData = scaled.jpegData(compressionQuality: 0.6) else {
            throw StorageError.imageCompressionFailed
        }

        let filename = "\(id.uuidString)_thumb.jpg"
        let fileURL = thumbnailsDirectory.appendingPathComponent(filename)
        try jpegData.write(to: fileURL)

        return filename
    }

    func loadImage(filename: String) -> UIImage? {
        let fileURL = imagesDirectory.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    func loadThumbnail(filename: String) -> UIImage? {
        let fileURL = thumbnailsDirectory.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    func deleteImage(filename: String) {
        let fileURL = imagesDirectory.appendingPathComponent(filename)
        try? fileManager.removeItem(at: fileURL)
    }

    func deleteThumbnail(filename: String) {
        let fileURL = thumbnailsDirectory.appendingPathComponent(filename)
        try? fileManager.removeItem(at: fileURL)
    }

    private func scaleImage(_ image: UIImage, to size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

enum StorageError: LocalizedError {
    case imageCompressionFailed
    case fileWriteFailed

    var errorDescription: String? {
        switch self {
        case .imageCompressionFailed: return "图片压缩失败"
        case .fileWriteFailed: return "文件写入失败"
        }
    }
}
