import UIKit
import Vision
import CoreImage

enum ImageProcessingError: LocalizedError {
    case failedToCreateCIImage
    case subjectExtractionFailed
    case maskGenerationFailed
    case compositingFailed

    var errorDescription: String? {
        switch self {
        case .failedToCreateCIImage: return "无法创建图像"
        case .subjectExtractionFailed: return "主体提取失败"
        case .maskGenerationFailed: return "遮罩生成失败"
        case .compositingFailed: return "图像合成失败"
        }
    }
}

actor ImageProcessingService {

    private let context = CIContext()

    func removeBackground(from image: UIImage) async throws -> UIImage {
        guard let ciImage = CIImage(image: image) else {
            throw ImageProcessingError.failedToCreateCIImage
        }

        let mask = try await generateSubjectMask(from: ciImage)
        let result = try applyMask(mask, to: ciImage)
        return result
    }

    private func generateSubjectMask(from image: CIImage) async throws -> CIImage {
        guard #available(iOS 17.0, *) else {
            return try fallbackColorBasedMask(from: image)
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNGenerateForegroundInstanceMaskRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observation = request.results?.first as? VNInstanceMaskObservation else {
                    continuation.resume(throwing: ImageProcessingError.maskGenerationFailed)
                    return
                }

                do {
                    let maskPixelBuffer = try observation.generateScaledMaskForImage(
                        forInstances: observation.allInstances,
                        from: request
                    )
                    let maskImage = CIImage(cvPixelBuffer: maskPixelBuffer)
                    continuation.resume(returning: maskImage)
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            let handler = VNImageRequestHandler(ciImage: image)
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func fallbackColorBasedMask(from image: CIImage) throws -> CIImage {
        let filterName = "CIColorMatrix"
        guard let filter = CIFilter(name: filterName) else {
            throw ImageProcessingError.maskGenerationFailed
        }

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")

        guard let output = filter.outputImage else {
            throw ImageProcessingError.maskGenerationFailed
        }
        return output
    }

    private func applyMask(_ mask: CIImage, to image: CIImage) throws -> UIImage {
        let filterName = "CIBlendWithMask"
        guard let filter = CIFilter(name: filterName) else {
            throw ImageProcessingError.compositingFailed
        }

        let clearImage = CIImage.empty()

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(clearImage, forKey: kCIInputBackgroundImageKey)
        filter.setValue(mask, forKey: kCIInputMaskImageKey)

        guard let output = filter.outputImage,
              let cgImage = context.createCGImage(output, from: image.extent) else {
            throw ImageProcessingError.compositingFailed
        }

        return UIImage(cgImage: cgImage)
    }
}
