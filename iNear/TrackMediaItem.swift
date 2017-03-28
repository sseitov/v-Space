//
//  TrackMediaItem.swift
//  iNear
//
//  Created by Сергей Сейтов on 04.03.17.
//  Copyright © 2017 Сергей Сейтов. All rights reserved.
//

import UIKit
import JSQMessagesViewController

class TrackMediaItem : JSQLocationMediaItem {
    
    var track:String?
    var cashedImageView:UIImageView?
    
    override func setLocation(_ location: CLLocation!, withCompletionHandler completion: JSQLocationMediaItemCompletionBlock!) {
        if location != nil {
            let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 200, height: 120))
            trackShapshot(size: imageView.frame.size, points: Model.shared.trackPoints(track!), result: { image in
                imageView.image = image
                JSQMessagesMediaViewBubbleImageMasker.applyBubbleImageMask(toMediaView: imageView,
                                                                           isOutgoing: self.appliesMediaViewMaskAsOutgoing)
                self.cashedImageView = imageView
                completion()
            })
        }
    }
    
    override func mediaView() -> UIView! {
        return cashedImageView
    }
    
    override func mediaViewDisplaySize() -> CGSize {
        return CGSize(width: 200, height: 120)
    }
    
    private func locationShapshot(size:CGSize, center:CLLocationCoordinate2D, result:@escaping (UIImage?) -> ()) {
        let startMarker = UIImage(named: "startPoint")
        
        let options = MKMapSnapshotOptions()
        options.mapType = .standard
        options.scale = 1.0
        options.size = size
        let span = MKCoordinateSpanMake(0.1, 0.1)
        options.region = MKCoordinateRegionMake(center, span)
        
        let snapshotter = MKMapSnapshotter(options: options)
        snapshotter.start(with: DispatchQueue.main, completionHandler: { snap, error in
            if error != nil {
                print(error!)
                result(nil)
                return
            }
            if let image = snap?.image {
                UIGraphicsBeginImageContext(image.size)
                image.draw(at: CGPoint())
                
                var startPt = snap!.point(for: center)
                startPt = CGPoint(x: startPt.x - startMarker!.size.width/2.0, y: startPt.y - startMarker!.size.height/2.0)
                startMarker!.draw(at: startPt)
                
                let image = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                result(image)
            } else {
                result(nil)
            }
        })
    }
    
    private func trackShapshot(size:CGSize, points:[CLLocationCoordinate2D], result:@escaping (UIImage?) -> ()) {
        let startMarker = UIImage(named: "startPoint")
        let finishMarker = UIImage(named: "finishPoint")
        
        let options = MKMapSnapshotOptions()
        let rect = MKMapRect(coordinates: points)
        let inset = -rect.size.width*0.1
        options.mapRect = MKMapRectInset(rect, inset, inset)
        options.mapType = .standard
        options.scale = 1.0
        options.size = size
        
        let snapshotter = MKMapSnapshotter(options: options)
        snapshotter.start(with: DispatchQueue.main, completionHandler: { snap, error in
            if error != nil {
                print(error!)
                result(nil)
                return
            }
            if let image = snap?.image {
                UIGraphicsBeginImageContext(image.size)
                image.draw(at: CGPoint())
                let context = UIGraphicsGetCurrentContext()
                context?.setLineWidth(4.0)
                context?.setStrokeColor(UIColor.traceColor().cgColor)
                context?.beginPath()
                
                var startPt:CGPoint = CGPoint()
                var drawPt:CGPoint = CGPoint()
                for i in 0..<points.count {
                    drawPt = snap!.point(for: points[i])
                    if i == 0 {
                        startPt = drawPt
                        context?.move(to: drawPt)
                    } else {
                        context?.addLine(to: drawPt)
                    }
                }
                
                startPt = CGPoint(x: startPt.x - startMarker!.size.width/2.0, y: startPt.y - startMarker!.size.height/2.0)
                startMarker!.draw(at: startPt)
                if points.count > 1 {
                    context?.strokePath()
                    drawPt = CGPoint(x: drawPt.x - finishMarker!.size.width/2.0, y: drawPt.y - finishMarker!.size.height/2.0)
                    finishMarker!.draw(at: startPt)
                    startMarker!.draw(at: drawPt)
                }
                
                let image = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                result(image)
            } else {
                result(nil)
            }
        })
    }

}
