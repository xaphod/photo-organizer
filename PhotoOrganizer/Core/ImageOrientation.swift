//
//  ImageOrientation.swift
//  PhotoOrganizer
//

import CoreGraphics

extension CGImage {
	/// The image as it should be displayed given an EXIF orientation (1–8); unknown values
	/// return the image unchanged.
	func applyingExifOrientation(_ orientation: Int) -> CGImage {
		guard (2...8).contains(orientation) else { return self }
		let width = CGFloat(self.width)
		let height = CGFloat(self.height)
		let swapsAxes = orientation >= 5
		let outputWidth = swapsAxes ? height : width
		let outputHeight = swapsAxes ? width : height

		// Core Graphics draws with the origin at the bottom-left; the transform maps the stored
		// pixels onto the output canvas.
		var transform = CGAffineTransform.identity
		switch orientation {
		case 3, 4: // stored upside down
			transform = transform.translatedBy(x: outputWidth, y: outputHeight).rotated(by: .pi)
		case 5, 8: // stored rotated 90° clockwise → rotate back counter-clockwise
			transform = transform.translatedBy(x: outputWidth, y: 0).rotated(by: .pi / 2)
		case 6, 7: // stored rotated 90° counter-clockwise → rotate back clockwise
			transform = transform.translatedBy(x: 0, y: outputHeight).rotated(by: -.pi / 2)
		default:
			break
		}
		switch orientation {
		case 2, 4:
			transform = transform.translatedBy(x: outputWidth, y: 0).scaledBy(x: -1, y: 1)
		case 5, 7:
			transform = transform.translatedBy(x: outputHeight, y: 0).scaledBy(x: -1, y: 1)
		default:
			break
		}

		guard let context = CGContext(
			data: nil, width: Int(outputWidth), height: Int(outputHeight), bitsPerComponent: 8,
			bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
			bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
		) else { return self }
		context.concatenate(transform)
		context.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))
		return context.makeImage() ?? self
	}
}
