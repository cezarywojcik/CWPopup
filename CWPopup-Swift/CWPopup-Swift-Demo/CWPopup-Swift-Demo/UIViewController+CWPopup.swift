//
//  UIViewController+CWPopup.swift
//  DimPresentViewController
//
//  Created by admin on 3/8/16.
//  Copyright © 2016 __ASIAINFO__. All rights reserved.
//

import UIKit
import Accelerate

public extension UIImage {
	public func applyLightEffect() -> UIImage? {
		return applyBlurWithRadius(30, tintColor: UIColor(white: 1.0, alpha: 0.3), saturationDeltaFactor: 1.8)
	}
	
	public func applyExtraLightEffect() -> UIImage? {
		return applyBlurWithRadius(20, tintColor: UIColor(white: 0.97, alpha: 0.82), saturationDeltaFactor: 1.8)
	}
	
	public func applyDarkEffect() -> UIImage? {
		return applyBlurWithRadius(20, tintColor: UIColor(white: 0.11, alpha: 0.73), saturationDeltaFactor: 1.8)
	}
	
	public func applyTintEffectWithColor(tintColor: UIColor) -> UIImage? {
		let effectColorAlpha: CGFloat = 0.6
		var effectColor = tintColor
		
		let componentCount = CGColorGetNumberOfComponents(tintColor.CGColor)
		
		if componentCount == 2 {
			var b: CGFloat = 0
			if tintColor.getWhite(&b, alpha: nil) {
				effectColor = UIColor(white: b, alpha: effectColorAlpha)
			}
		} else {
			var red: CGFloat = 0
			var green: CGFloat = 0
			var blue: CGFloat = 0
			
			if tintColor.getRed(&red, green: &green, blue: &blue, alpha: nil) {
				effectColor = UIColor(red: red, green: green, blue: blue, alpha: effectColorAlpha)
			}
		}
		
		return applyBlurWithRadius(10, tintColor: effectColor, saturationDeltaFactor: -1.0, maskImage: nil)
	}
	
	public func applyBlurWithRadius(blurRadius: CGFloat, tintColor: UIColor?, saturationDeltaFactor: CGFloat, maskImage: UIImage? = nil) -> UIImage? {
		// Check pre-conditions.
		if (size.width < 1 || size.height < 1) {
			print("*** error: invalid size: \(size.width) x \(size.height). Both dimensions must be >= 1: \(self)")
			return nil
		}
		if self.CGImage == nil {
			print("*** error: image must be backed by a CGImage: \(self)")
			return nil
		}
		if maskImage != nil && maskImage!.CGImage == nil {
			print("*** error: maskImage must be backed by a CGImage: \(maskImage)")
			return nil
		}
		
		let __FLT_EPSILON__ = CGFloat(FLT_EPSILON)
		let screenScale = UIScreen.mainScreen().scale
		let imageRect = CGRect(origin: CGPointZero, size: size)
		var effectImage = self
		
		let hasBlur = blurRadius > __FLT_EPSILON__
		let hasSaturationChange = fabs(saturationDeltaFactor - 1.0) > __FLT_EPSILON__
		
		if hasBlur || hasSaturationChange {
			func createEffectBuffer(context: CGContext) -> vImage_Buffer {
				let data = CGBitmapContextGetData(context)
				let width = vImagePixelCount(CGBitmapContextGetWidth(context))
				let height = vImagePixelCount(CGBitmapContextGetHeight(context))
				let rowBytes = CGBitmapContextGetBytesPerRow(context)
				
				return vImage_Buffer(data: data, height: height, width: width, rowBytes: rowBytes)
			}
			
			UIGraphicsBeginImageContextWithOptions(size, false, screenScale)
			let effectInContext = UIGraphicsGetCurrentContext()
			
			CGContextScaleCTM(effectInContext, 1.0, -1.0)
			CGContextTranslateCTM(effectInContext, 0, -size.height)
			CGContextDrawImage(effectInContext, imageRect, self.CGImage)
			
			var effectInBuffer = createEffectBuffer(effectInContext!)
			
			UIGraphicsBeginImageContextWithOptions(size, false, screenScale)
			let effectOutContext = UIGraphicsGetCurrentContext()
			
			var effectOutBuffer = createEffectBuffer(effectOutContext!)
			
			if hasBlur {
				// A description of how to compute the box kernel width from the Gaussian
				// radius (aka standard deviation) appears in the SVG spec:
				// http://www.w3.org/TR/SVG/filters.html#feGaussianBlurElement
				//
				// For larger values of 's' (s >= 2.0), an approximation can be used: Three
				// successive box-blurs build a piece-wise quadratic convolution kernel, which
				// approximates the Gaussian kernel to within roughly 3%.
				//
				// let d = floor(s * 3*sqrt(2*pi)/4 + 0.5)
				//
				// ... if d is odd, use three box-blurs of size 'd', centered on the output pixel.
				//
				
				let inputRadius = blurRadius * screenScale
				var radius = UInt32(floor(inputRadius * 3.0 * CGFloat(sqrt(2 * M_PI)) / 4 + 0.5))
				if radius % 2 != 1 {
					radius += 1 // force radius to be odd so that the three box-blur methodology works.
				}
				
				let imageEdgeExtendFlags = vImage_Flags(kvImageEdgeExtend)
				
				vImageBoxConvolve_ARGB8888(&effectInBuffer, &effectOutBuffer, nil, 0, 0, radius, radius, nil, imageEdgeExtendFlags)
				vImageBoxConvolve_ARGB8888(&effectOutBuffer, &effectInBuffer, nil, 0, 0, radius, radius, nil, imageEdgeExtendFlags)
				vImageBoxConvolve_ARGB8888(&effectInBuffer, &effectOutBuffer, nil, 0, 0, radius, radius, nil, imageEdgeExtendFlags)
			}
			
			var effectImageBuffersAreSwapped = false
			
			if hasSaturationChange {
				let s: CGFloat = saturationDeltaFactor
				let floatingPointSaturationMatrix: [CGFloat] = [
					0.0722 + 0.9278 * s, 0.0722 - 0.0722 * s, 0.0722 - 0.0722 * s, 0,
					0.7152 - 0.7152 * s, 0.7152 + 0.2848 * s, 0.7152 - 0.7152 * s, 0,
					0.2126 - 0.2126 * s, 0.2126 - 0.2126 * s, 0.2126 + 0.7873 * s, 0,
					0, 0, 0, 1
				]
				
				let divisor: CGFloat = 256
				let matrixSize = floatingPointSaturationMatrix.count
				var saturationMatrix = [Int16](count: matrixSize, repeatedValue: 0)
				
				for var i: Int = 0; i < matrixSize; ++i {
					saturationMatrix[i] = Int16(round(floatingPointSaturationMatrix[i] * divisor))
				}
				
				if hasBlur {
					vImageMatrixMultiply_ARGB8888(&effectOutBuffer, &effectInBuffer, saturationMatrix, Int32(divisor), nil, nil, vImage_Flags(kvImageNoFlags))
					effectImageBuffersAreSwapped = true
				} else {
					vImageMatrixMultiply_ARGB8888(&effectInBuffer, &effectOutBuffer, saturationMatrix, Int32(divisor), nil, nil, vImage_Flags(kvImageNoFlags))
				}
			}
			
			if !effectImageBuffersAreSwapped {
				effectImage = UIGraphicsGetImageFromCurrentImageContext()
			}
			
			UIGraphicsEndImageContext()
			
			if effectImageBuffersAreSwapped {
				effectImage = UIGraphicsGetImageFromCurrentImageContext()
			}
			
			UIGraphicsEndImageContext()
		}
		
		// Set up output context.
		UIGraphicsBeginImageContextWithOptions(size, false, screenScale)
		let outputContext = UIGraphicsGetCurrentContext()
		CGContextScaleCTM(outputContext, 1.0, -1.0)
		CGContextTranslateCTM(outputContext, 0, -size.height)
		
		// Draw base image.
		CGContextDrawImage(outputContext, imageRect, self.CGImage)
		
		// Draw effect image.
		if hasBlur {
			CGContextSaveGState(outputContext)
			if let image = maskImage {
				CGContextClipToMask(outputContext, imageRect, image.CGImage);
			}
			CGContextDrawImage(outputContext, imageRect, effectImage.CGImage)
			CGContextRestoreGState(outputContext)
		}
		
		// Add in color tint.
		if let color = tintColor {
			CGContextSaveGState(outputContext)
			CGContextSetFillColorWithColor(outputContext, color.CGColor)
			CGContextFillRect(outputContext, imageRect)
			CGContextRestoreGState(outputContext)
		}
		
		// Output image is ready.
		let outputImage = UIGraphicsGetImageFromCurrentImageContext()
		UIGraphicsEndImageContext()
		
		return outputImage
	}
}

extension UIViewController {
	private struct AssociatedKeys {
		static var popupViewController = "popupViewController"
		static var useBlurForPopup = "useBlurForPopup"
		static var popupViewOffset = "popupViewOffset"
		static var blurViewKey = "blurViewKey"
	}
	private struct Constants {
		static let animationTime: Double = 0.5
		static let statusBarSize: CGFloat = 22
	}
	
	typealias Completion = () -> ()
	
	// MARK: - public
	var popupViewController: UIViewController? {
		
		set {
			objc_setAssociatedObject(self, &AssociatedKeys.popupViewController, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
		}
		
		get {
			return objc_getAssociatedObject(self, &AssociatedKeys.popupViewController) as? UIViewController
		}
	}
	
	var useBlurForPopup: Bool? {
		set {
			objc_setAssociatedObject(self, &AssociatedKeys.useBlurForPopup, newValue, .OBJC_ASSOCIATION_ASSIGN)
		}
		
		get {
			return objc_getAssociatedObject(self, &AssociatedKeys.useBlurForPopup) as? Bool
		}
	}
	
	var popupViewOffset: CGPoint? {
		set {
			objc_setAssociatedObject(self, &AssociatedKeys.popupViewOffset, NSValue(CGPoint: newValue!), .OBJC_ASSOCIATION_ASSIGN)
		}
		
		get {
			return (objc_getAssociatedObject(self, &AssociatedKeys.popupViewOffset) as? NSValue)?.CGPointValue()
		}
	}
	
	func presentPopupViewController(viewControllerToPresent: UIViewController, animated: Bool, completion: Completion?) {
		if popupViewController == nil {
			popupViewController = viewControllerToPresent
			popupViewController!.view.autoresizesSubviews = false
			popupViewController!.view.autoresizingMask = .None
			addChildViewController(viewControllerToPresent)
			let finalFrame = getPopupFrameForViewController(viewControllerToPresent)
			
			// parallax setup
			let interpolationHorizontal = UIInterpolatingMotionEffect(keyPath: "center.x", type: .TiltAlongHorizontalAxis)
			interpolationHorizontal.minimumRelativeValue = -10
			interpolationHorizontal.maximumRelativeValue = 10
			
			let interpolationVertical = UIInterpolatingMotionEffect(keyPath: "center.y", type: .TiltAlongVerticalAxis)
			interpolationHorizontal.minimumRelativeValue = -10
			interpolationHorizontal.maximumRelativeValue = 10
			
			popupViewController!.view.addMotionEffect(interpolationHorizontal)
			popupViewController!.view.addMotionEffect(interpolationVertical)
			
			// shadow setup
			viewControllerToPresent.view.layer.shadowOffset = .zero
			viewControllerToPresent.view.layer.shadowColor = UIColor.blackColor().CGColor
			viewControllerToPresent.view.layer.shadowPath = UIBezierPath(rect: viewControllerToPresent.view.layer.bounds).CGPath
			viewControllerToPresent.view.layer.cornerRadius = 5
			
			// blurView
			if useBlurForPopup == true {
				addBlurView()
			} else {
				let fadeView = UIImageView()
				if isPortraitOrientation {
					
					fadeView.frame = UIScreen.mainScreen().bounds
				} else {
					fadeView.frame = CGRect(x: 0, y: 0, width: UIScreen.mainScreen().bounds.size.height, height: UIScreen.mainScreen().bounds.size.width)
				}
				
				fadeView.backgroundColor = UIColor.blackColor()
				fadeView.alpha = 0
				view.addSubview(fadeView)
				objc_setAssociatedObject(self, &AssociatedKeys.blurViewKey, fadeView, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
			}
			
			let blurView = objc_getAssociatedObject(self, &AssociatedKeys.blurViewKey) as! UIView
			viewControllerToPresent.beginAppearanceTransition(true, animated: animated)
			
			if animated {
				var initialFrame = CGRect(x: finalFrame.origin.x, y: UIScreen.mainScreen().bounds.size.height + viewControllerToPresent.view.frame.size.height / 2, width: finalFrame.size.width, height: finalFrame.size.height)
				
				var initialAlpha: CGFloat = 1
				let finalAlpha: CGFloat = 1
				
				if modalTransitionStyle == .CrossDissolve {
					initialFrame = finalFrame
					initialAlpha = 0
				}
				
				viewControllerToPresent.view.frame = initialFrame
				viewControllerToPresent.view.alpha = initialAlpha
				
				view.addSubview(viewControllerToPresent.view)
				
				UIView.animateWithDuration(Constants.animationTime, delay: 0, options: .CurveEaseInOut, animations: { () -> Void in
					viewControllerToPresent.view.frame = finalFrame
					viewControllerToPresent.view.alpha = finalAlpha
					blurView.alpha = self.useBlurForPopup == true ? 1 : 0.4
					}, completion: { (success) -> Void in
					self.popupViewController?.didMoveToParentViewController(self)
					self.popupViewController?.endAppearanceTransition()
					if let completion = completion {
						completion()
					}
				})
				
				// if screen orientation changed
				NSNotificationCenter.defaultCenter().addObserver(self, selector: "screenOrientationChanged", name: UIApplicationDidChangeStatusBarOrientationNotification, object: nil)
			}
		}
	}
	
	func dismissPopupViewController(animated: Bool, completion: Completion?) {
		let blurView = objc_getAssociatedObject(self, &AssociatedKeys.blurViewKey) as! UIView
		popupViewController?.willMoveToParentViewController(nil)
		
		popupViewController?.beginAppearanceTransition(false, animated: animated)
		
		if animated {
			let initialFrame = popupViewController!.view.frame
			var finalFrame = CGRect(x: initialFrame.origin.x, y: UIScreen.mainScreen().bounds.size.height + initialFrame.size.height / 2, width: initialFrame.size.width, height: initialFrame.size.height)
			var finalAlpha: CGFloat = 1
			if modalTransitionStyle == .CrossDissolve {
				finalFrame = initialFrame
				finalAlpha = 0
			}
			
			UIView.animateWithDuration(Constants.animationTime, delay: 0, options: .CurveEaseInOut, animations: { () -> Void in
				self.popupViewController!.view.frame = finalFrame
				self.popupViewController!.view.alpha = finalAlpha
				blurView.alpha = 0
				}, completion: { (success) -> Void in
				self.popupViewController?.removeFromParentViewController()
				self.popupViewController?.endAppearanceTransition()
				self.popupViewController!.view.removeFromSuperview()
				blurView.removeFromSuperview()
				self.popupViewController = nil
				if let completion = completion {
					completion()
				}
			})
		}
		
		NSNotificationCenter.defaultCenter().removeObserver(self, name: UIApplicationDidChangeStatusBarOrientationNotification, object: nil)
	}
	
	// MARK: - private
	
	var isPortraitOrientation: Bool {
		return UIInterfaceOrientationIsPortrait(UIApplication.sharedApplication().statusBarOrientation)
	}
	
	func screenOrientationChanged() {
		// make blur view go away so that we can re-blur the original back
		let blurView = objc_getAssociatedObject(self, &AssociatedKeys.blurViewKey) as! UIView
		
		UIView.animateWithDuration(Constants.animationTime) { () -> Void in
			self.popupViewController!.view.frame = self.getPopupFrameForViewController(self.popupViewController!)
			
			if self.isPortraitOrientation {
				blurView.frame = UIScreen.mainScreen().bounds
			} else {
				blurView.frame = CGRect(x: 0, y: 0, width: UIScreen.mainScreen().bounds.size.height, height: UIScreen.mainScreen().bounds.size.width)
			}
			
			if self.useBlurForPopup == true {
				UIView.animateWithDuration(1.0, animations: { () -> Void in
					}, completion: { (completion) -> Void in
					blurView.removeFromSuperview()
					self.popupViewController!.view.alpha = 0
					self.addBlurView()
					self.popupViewController!.view.alpha = 1
					let blurViewNew = objc_getAssociatedObject(self, &AssociatedKeys.blurViewKey) as! UIView
					blurViewNew.alpha = 1
				})
			}
		}
	}
	
	func getPopupFrameForViewController(viewController: UIViewController) -> CGRect {
		let frame = viewController.view.frame
		var x: CGFloat = 0
		var y: CGFloat = 0
		
		if isPortraitOrientation {
			x = (UIScreen.mainScreen().bounds.size.width - frame.size.width) / 2
			y = (UIScreen.mainScreen().bounds.size.height - frame.size.height) / 2
		} else {
			x = (UIScreen.mainScreen().bounds.size.height - frame.size.height) / 2
			y = (UIScreen.mainScreen().bounds.size.width - frame.size.width) / 2
		}
		
		if let popupViewOffset = viewController.popupViewOffset {
			return CGRect(x: x + popupViewOffset.x, y: y + popupViewOffset.y, width: frame.size.width, height: frame.size.height)
		} else {
			return CGRect(x: x, y: y, width: frame.size.width, height: frame.size.height)
		}
	}
	
	func addBlurView() {
		let blurView = UIImageView()
		if isPortraitOrientation {
			blurView.frame = CGRect(x: 0, y: 0, width: UIScreen.mainScreen().bounds.size.width, height: UIScreen.mainScreen().bounds.size.height)
		} else {
			blurView.frame = CGRect(x: 0, y: 0, width: UIScreen.mainScreen().bounds.size.height, height: UIScreen.mainScreen().bounds.size.width)
		}
		
		blurView.alpha = 0
		blurView.image = getBlurredImage(getScreenImage())
		view.addSubview(blurView)
		view.bringSubviewToFront((popupViewController?.view)!)
		objc_setAssociatedObject(self, &AssociatedKeys.blurViewKey, blurView, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
	}
	
	func getBlurredImage(imageToBlur: UIImage) -> UIImage {
		return imageToBlur.applyBlurWithRadius(10.0, tintColor: UIColor.clearColor(), saturationDeltaFactor: 1.0, maskImage: nil)!
	}
	
	func getScreenImage() -> UIImage {
		var frame: CGRect?
		if isPortraitOrientation {
			frame = UIScreen.mainScreen().bounds
		} else {
			frame = CGRectMake(0, 0, UIScreen.mainScreen().bounds.size.height, UIScreen.mainScreen().bounds.size.width)
		}
		
		UIGraphicsBeginImageContext((frame?.size)!)
		
		let currentContext = UIGraphicsGetCurrentContext()
		
		view.layer.renderInContext(UIGraphicsGetCurrentContext()!)
		
		CGContextClipToRect(currentContext, frame!)
		
		let screenshot = UIGraphicsGetImageFromCurrentImageContext()
		
		UIGraphicsEndImageContext()
		return screenshot
	}
}
