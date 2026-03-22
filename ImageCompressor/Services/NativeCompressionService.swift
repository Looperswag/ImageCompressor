import Foundation
import AppKit
import ImageIO
import UniformTypeIdentifiers

/// Native image compression service using ImageIO framework
/// This works within macOS sandbox without subprocess execution
actor NativeCompressionService {

    /// Compress an image using native ImageIO APIs
    static func compress(
        inputData: Data,
        outputURL: URL,
        format: ExportFormat,
        quality: Int,
        maxDimension: Int?,
        stripMetadata: Bool
    ) async throws {
        // Validate output directory is writable
        let outputDir = outputURL.deletingLastPathComponent()
        guard FileManager.default.isWritableFile(atPath: outputDir.path) else {
            throw CompressionError.outputDirectoryNotWritable
        }

        // Validate output path is safe
        guard FileService.isPathSafe(outputURL) else {
            throw CompressionError.invalidPath
        }

        // Create CGImageSource from input data
        guard let imageSource = CGImageSourceCreateWithData(inputData as CFData, nil) else {
            throw CompressionError.invalidImageData
        }

        // Get image properties
        guard let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] else {
            throw CompressionError.invalidImageData
        }

        // Get original dimensions
        let width = imageProperties[kCGImagePropertyPixelWidth] as! Int
        let height = imageProperties[kCGImagePropertyPixelHeight] as! Int

        // Calculate new dimensions if max dimension specified
        var finalWidth = width
        var finalHeight = height

        if let maxDim = maxDimension {
            let ratio = min(
                CGFloat(maxDim) / CGFloat(width),
                CGFloat(maxDim) / CGFloat(height)
            )
            finalWidth = Int(CGFloat(width) * ratio)
            finalHeight = Int(CGFloat(height) * ratio)
        }

        // Determine output UTType
        let utType: String
        let compressionQuality: Float = Float(quality) / 100.0

        switch format {
        case .jpeg:
            utType = UTType.jpeg.identifier
        case .png:
            utType = UTType.png.identifier
        case .heic:
            utType = UTType.jpeg.identifier  // Convert HEIC to JPEG
        case .auto:
            // Detect from input
            utType = detectInputType(from: imageSource) == .png ? UTType.png.identifier : UTType.jpeg.identifier
        }

        // Create destination options
        let destinationOptions: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: compressionQuality
        ]

        // Create CGImage from source
        guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw CompressionError.invalidImageData
        }

        // Resize if needed
        let finalCGImage: CGImage
        if finalWidth != width || finalHeight != height {
            finalCGImage = resizeImage(cgImage, to: CGSize(width: finalWidth, height: finalHeight)) ?? cgImage
        } else {
            finalCGImage = cgImage
        }

        // Create mutable data for output
        let outputData = NSMutableData()

        // Create image destination
        guard let destination = CGImageDestinationCreateWithData(
            outputData,
            utType as CFString,
            1,
            destinationOptions as CFDictionary
        ) else {
            throw CompressionError.conversionFailed
        }

        // Add image to destination
        CGImageDestinationAddImage(destination, finalCGImage, nil)

        // Finalize
        guard CGImageDestinationFinalize(destination) else {
            throw CompressionError.conversionFailed
        }

        // Strip metadata if requested (by creating fresh image data)
        var finalOutputData = outputData as Data
        if stripMetadata {
            finalOutputData = removeMetadata(from: outputData as Data, format: format)
        }

        // Write to output file
        try finalOutputData.write(to: outputURL)
    }

    /// Resize CGImage to new size
    private static func resizeImage(_ image: CGImage, to size: CGSize) -> CGImage? {
        let width = Int(size.width)
        let height = Int(size.height)

        // Create bitmap context
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }

        // Set high quality interpolation
        context.interpolationQuality = .high

        // Draw image in new size
        let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        context.draw(image, in: rect)

        // Create final image from context
        return context.makeImage()
    }

    /// Detect input image type from data
    private static func detectInputType(from source: CGImageSource) -> DetectedType {
        // Try to determine type from UTI
        if let uti = CGImageSourceGetType(source as CGImageSource) {
            let utiString = uti as String
            if utiString.contains("png") {
                return .png
            }
        }
        return .jpeg
    }

    /// Remove metadata from image data by re-encoding
    private static func removeMetadata(from data: Data, format: ExportFormat) -> Data {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            return data
        }

        let outputData = NSMutableData()
        let utType = format == .png ? UTType.png.identifier : UTType.jpeg.identifier

        guard let destination = CGImageDestinationCreateWithData(
            outputData,
            utType as CFString,
            1,
            nil
        ) else {
            return data
        }

        // Add image without metadata
        CGImageDestinationAddImage(destination, cgImage, nil)
        CGImageDestinationFinalize(destination)

        return outputData as Data
    }

    private enum DetectedType {
        case jpeg, png
    }
}

enum CompressionError: LocalizedError {
    case invalidImageData
    case outputDirectoryNotWritable
    case invalidPath
    case conversionFailed

    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "无效的图片数据"
        case .outputDirectoryNotWritable:
            return "输出目录不可写"
        case .invalidPath:
            return "无效的输出路径"
        case .conversionFailed:
            return "图片转换失败"
        }
    }
}
