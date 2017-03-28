//
//  UIImageExtensions.swift
//  iNear
//
//  Created by Сергей Сейтов on 10.12.16.
//  Copyright © 2016 Сергей Сейтов. All rights reserved.
//

import UIKit

func compositeTwoImages(left: UIImage, right: UIImage, newSize: CGSize) -> UIImage? {
    UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
    right.draw(in: CGRect(x: newSize.width - right.size.width, y: 0, width: right.size.width, height: right.size.height))
    left.draw(in: CGRect(x: 0, y: 0, width: left.size.width, height: left.size.height))
    let newImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return newImage
}

extension UIImage {
    class func imageWithColor(_ color: UIColor, size: CGSize) -> UIImage {
        UIGraphicsBeginImageContext(size)
        color.setFill()
        UIRectFill(CGRect(x: 0, y: 0, width: size.width, height: size.height))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image!
    }
    
    func withSize(_ newSize:CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0);
        self.draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
        let newImage:UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return newImage
    }
    
    func inCircle() -> UIImage {
        let newImage = self.copy() as! UIImage
        let cornerRadius = self.size.height/2
        UIGraphicsBeginImageContextWithOptions(self.size, false, 1.0)
        let bounds = CGRect(origin: CGPoint(), size: self.size)
        UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius).addClip()
        newImage.draw(in: bounds)
        let finalImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return finalImage!
    }
    
    func addImage(_ image:UIImage) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(self.size, false, 1.0)
        let bounds = CGRect(origin: CGPoint(), size: self.size)
        let pt = CGPoint(x: (self.size.width - image.size.width)/2.0, y: (self.size.height - image.size.height)/2.0)
        let imageBounds = CGRect(origin: pt, size: image.size)
        self.draw(in: bounds)
        image.draw(in: imageBounds)
        let finalImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return finalImage!
    }
}
