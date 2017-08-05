//
//  TrackController.swift
//  iNear
//
//  Created by Сергей Сейтов on 27.01.17.
//  Copyright © 2017 Сергей Сейтов. All rights reserved.
//

import UIKit
import GoogleMaps
import Photos
import SVProgressHUD

class PhotoMarker : GMSMarker {
    var photo:Photo?
}

class TrackController: UIViewController {

    @IBOutlet weak var map: GMSMapView!
    
    var track:Track?
    var fromRoot = false
    
    private var photoMarkers:[PhotoMarker] = []
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.refreshPhotos),
                                               name: syncNotification,
                                               object: nil)
        if IS_PAD() {
            navigationItem.leftBarButtonItem = nil
            navigationItem.hidesBackButton = true
        } else {
            setupBackButton()
        }
        
        map.delegate = self
        
        var path:GMSMutablePath?
        
        if track == nil {            
            if let date = Model.shared.lastLocationDate(),
                let all = Model.shared.lastTrack(), all.count > 1
            {
                setupTitle("\(NSLocalizedString("Current track", comment: ""))\n\(textDateFormatter().string(from: date))")
                
                path = GMSMutablePath()
                for pt in all {
                    path!.add(CLLocationCoordinate2D(latitude: pt.latitude, longitude: pt.longitude))
                }
            } else {
                setupTitle("v-Space")
                map.isHidden = true
                return
            }
        } else {
            refreshPhotos()
            Cloud.shared.syncTrackPhotos(track!)
            setupTitle("\(track!.place!)\n\(textDateFormatter().string(from: (track!.finishDate! as Date)))")
            path = GMSMutablePath(fromEncodedPath: track!.path!)
        }
        
        let userTrack = GMSPolyline(path: path)
        userTrack.strokeColor = UIColor.traceColor()
        userTrack.strokeWidth = 4
        userTrack.map = map
        
        let finish = path!.coordinate(at:0)
        let finishMarker = GMSMarker(position: CLLocationCoordinate2D(latitude: finish.latitude, longitude: finish.longitude))
        finishMarker.icon = UIImage(named: "finishPoint")
        finishMarker.groundAnchor = CGPoint(x: 0.5, y: 0.5)
        finishMarker.map = map
        
        let start = path!.coordinate(at: path!.count() - 1)
        let startMarker = GMSMarker(position: CLLocationCoordinate2D(latitude: start.latitude, longitude: start.longitude))
        startMarker.icon = UIImage(named: "startPoint")
        startMarker.groundAnchor = CGPoint(x: 0.5, y: 0.5)
        startMarker.map = map
        
        var bounds = GMSCoordinateBounds()
        for i in 0..<path!.count() {
            let pt = path!.coordinate(at: i)
            bounds = bounds.includingCoordinate(CLLocationCoordinate2D(latitude: pt.latitude, longitude: pt.longitude))
        }
        let update = GMSCameraUpdate.fit(bounds, withPadding: 20)
        map.moveCamera(update)
    }
    
    override func goBack() {
        if fromRoot {
            dismiss(animated: true, completion: nil)
        } else {
            navigationItem.prompt = nil
            super.goBack()
        }
    }
    
    func refreshPhotos() {
        
        for marker in photoMarkers {
            marker.map = nil
        }
        photoMarkers.removeAll()
        
        if let photos = track?.photos?.allObjects as? [Photo] {
            for photo in photos {
                let marker = PhotoMarker(position: CLLocationCoordinate2D(latitude: photo.latitude, longitude: photo.longitude))
                marker.photo = photo
                marker.icon = UIImage(named: "photo")
                marker.groundAnchor = CGPoint(x: 0.5, y: 0.5)
                marker.map = map
                photoMarkers.append(marker)
            }
            if photoMarkers.count > 0 {
                let btn1 = UIBarButtonItem(image: UIImage(named: "cameraRoll"),
                                          style: .plain,
                                          target: self,
                                          action: #selector(self.showPhotos))
                btn1.tintColor = UIColor.white
                let btn2 = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(self.publish))
                btn2.tintColor = UIColor.white
                navigationItem.setRightBarButtonItems([btn2, btn1], animated: true)
            } else {
                let btn = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(self.publish))
                btn.tintColor = UIColor.white
                navigationItem.setRightBarButton(btn, animated: true)
            }
        } else {
            navigationItem.setRightBarButton(nil, animated: true)
        }
    }
    
    // MARK: - Navigation
    
    func showPhotos() {
        performSegue(withIdentifier: "allPhotos", sender: nil)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showPhoto" {
            let next = segue.destination as! PhotoController
            next.photo = sender as? Photo
        } else if segue.identifier == "allPhotos" {
            let next = segue.destination as! PhotoCollectionController
            next.track = track
        }
    }
    
    // MARK: - Publishing
    
    private func selectedImages(_ result: @escaping([Data]) -> ()) {
        var uids:[String] = []
        for photo in track!.allPhotos() {
            uids.append(photo.uid!)
        }
        var assets:[PHAsset] = []
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: uids, options: nil)
        fetchResult.enumerateObjects({ asset, index, _ in
            assets.append(asset)
        })
        if assets.count > 0 {
            let next = NSCondition()
            DispatchQueue.global().async {
                var images:[Data] = []
                let options = PHImageRequestOptions()
                options.isSynchronous = false
                options.version = .current
                options.deliveryMode = .opportunistic
                options.resizeMode = .none
                for asset in assets {
                    PHImageManager.default().requestImageData(for: asset, options: options, resultHandler: { data, _, _, _ in
                        print(Thread.current)
                        if data != nil {
                            images.append(data!)
                        }
                        next.lock()
                        next.signal()
                        next.unlock()
                    })
                    next.lock()
                    next.wait()
                    next.unlock()
                }
                DispatchQueue.main.async {
                    result(images)
                }
            }
        } else {
            result([])
        }
    }
    
    func publish() {
        SVProgressHUD.show()
        selectedImages({ images in
            SVProgressHUD.dismiss()
            if images.count > 0 {
                let activity = UIActivityViewController(activityItems: images, applicationActivities: nil)
                if IS_PAD() {
                    activity.modalPresentationStyle = .popover
                    activity.popoverPresentationController?.sourceView = self.view
                    activity.popoverPresentationController?.sourceRect = self.view.frame
                }
                self.present(activity, animated: true, completion: nil)
            }
        })
    }

}

extension TrackController : GMSMapViewDelegate {
    func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
        if let photoMarker = marker as? PhotoMarker {
            performSegue(withIdentifier: "showPhoto", sender: photoMarker.photo)
            return true
        } else {
            return false
        }
    }
}
