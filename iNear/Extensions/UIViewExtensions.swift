//
//  UIViewExtensions.swift
//  iNear
//
//  Created by Сергей Сейтов on 28.11.16.
//  Copyright © 2016 Сергей Сейтов. All rights reserved.
//

import UIKit

extension UIView {
    
    func setupBorder(_ color:UIColor, radius:CGFloat, width:CGFloat = 1) {
        self.layer.borderColor = color.cgColor
        self.layer.borderWidth = width
        self.layer.cornerRadius = radius
        self.clipsToBounds = true
    }
    
    func setupCircle() {
        self.layer.cornerRadius = self.bounds.size.width / 2
        self.clipsToBounds = true
    }
    
    func addDashedBorder() {
        let color = UIColor.black.cgColor
        
        let shapeLayer:CAShapeLayer = CAShapeLayer()
        let frameSize = self.frame.size
        let shapeRect = CGRect(x: 0, y: 0, width: frameSize.width, height: frameSize.height)
        
        shapeLayer.bounds = shapeRect
        shapeLayer.position = CGPoint(x: frameSize.width/2, y: frameSize.height/2)
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.strokeColor = color
        shapeLayer.lineWidth = 1
        shapeLayer.lineJoin = kCALineJoinRound
        shapeLayer.lineDashPattern = [10,5]
        shapeLayer.path = UIBezierPath(roundedRect: shapeRect, cornerRadius: 5).cgPath
        
        self.layer.addSublayer(shapeLayer)
        
    }
    
    func roundRectMask() {
        // Create a mask layer and the frame to determine what will be visible in the view.
        let maskLayer = CAShapeLayer()
        let maskRect = bounds
        
        // Create a path with the rectangle in it.
        let path = CGPath(roundedRect: maskRect, cornerWidth: 10, cornerHeight: 7, transform: nil)
            //CGPathCreateWithRect(maskRect, nil)
        
        // Set the path to the mask layer.
        maskLayer.path = path
        
        // Set the mask of the view.
        self.layer.mask = maskLayer
    }
    
    func shake(_ start:Bool) {
        let animationKey = "shake"
        layer.removeAnimation(forKey: animationKey)
        if (!start) {
            return
        }
        
        let kAnimation = CAKeyframeAnimation(keyPath: "transform")
        
        let wobbleAngle:CGFloat = 0.06
        let valLeft = NSValue(caTransform3D: CATransform3DMakeRotation(wobbleAngle, 0.0, 0.0, 1.0))
        let valRight = NSValue(caTransform3D: CATransform3DMakeRotation(-wobbleAngle, 0.0, 0.0, 1.0))
        kAnimation.values = [valLeft, valRight]
        
        kAnimation.duration = 0.125
        kAnimation.autoreverses = true
        kAnimation.repeatCount = Float.infinity
        
        layer.add(kAnimation, forKey: animationKey)
    }
    
    func screenShotImageWithBounds(_ selfBounds:CGRect) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(selfBounds.size, false, 0)
        let rect = CGRect(x: -selfBounds.origin.x, y: -selfBounds.origin.y, width: self.bounds.width, height: self.bounds.height)
        self.drawHierarchy(in: rect, afterScreenUpdates: true)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
    
    func toImageWithScale(_ scale:CGFloat) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(self.bounds.size, false, scale)
    
        if self.isKind(of: UIScrollView.self) {
            let ctx = UIGraphicsGetCurrentContext();
            let offset = (self as! UIScrollView).contentOffset
            ctx?.translateBy(x: -offset.x, y: -offset.y);
        }
    
        if self.responds(to: #selector(UIView.drawHierarchy(in:afterScreenUpdates:))) {
            self.drawHierarchy(in: self.bounds, afterScreenUpdates: true)
        } else {
            self.layer.render(in: UIGraphicsGetCurrentContext()!)
        }
    
        let snapshot = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext();
    
        return snapshot
    }

    func toImageInRect(_ rect:CGRect) -> UIImage? {
        return toImageInRect(rect, scale:0)
    }
    
    func toImageInRect(_ rect:CGRect, scale:CGFloat) -> UIImage? {
    
        if let wholeSnapshot = toImageWithScale(scale) {
            let imageRect = CGRect(x: rect.origin.x * wholeSnapshot.scale,
                                       y: rect.origin.y * wholeSnapshot.scale,
                                       width: rect.size.width * wholeSnapshot.scale,
                                       height: rect.size.height * wholeSnapshot.scale)
            let imageRef = wholeSnapshot.cgImage?.cropping(to: imageRect);
            let snapshot = UIImage.init(cgImage: imageRef!, scale: wholeSnapshot.scale, orientation: wholeSnapshot.imageOrientation)
            return snapshot;
        } else {
            return nil
        }
    }
}
