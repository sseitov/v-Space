//
//  TrackController.swift
//  iNear
//
//  Created by Сергей Сейтов on 27.01.17.
//  Copyright © 2017 Сергей Сейтов. All rights reserved.
//

import UIKit
import GoogleMaps

class PhotoMarker : GMSMarker {
    var photo:Photo?
}

class TrackController: UIViewController {

    @IBOutlet weak var map: GMSMapView!
    
    var track:Track?
    var fromRoot = false

    override func viewDidLoad() {
        super.viewDidLoad()
        setupBackButton()
        
        map.delegate = self
        
        if track == nil {
            if let date = LocationManager.shared.lastLocationDate() {
                setupTitle(textDateFormatter().string(from: date))
                map.animate(toLocation: LocationManager.shared.lastLocation())
            } else {
                setupTitle("v-Space")
            }
        } else {
//            Cloud.shared.putTrack(track!)
            setupTitle("\(track!.place!)\n\(textDateFormatter().string(from: track!.trackDate()))")
            
            var path:GMSMutablePath?
            if track!.path != nil {
                path = GMSMutablePath(fromEncodedPath: track!.path!)
            } else {
                path = GMSMutablePath()
                let all = track!.trackPoints()
                for pt in all {
                    path?.add(CLLocationCoordinate2D(latitude: pt.latitude, longitude: pt.longitude))
                }
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
            
            if let photos = track?.photos?.allObjects as? [Photo] {
                for photo in photos {
                    let marker = PhotoMarker(position: CLLocationCoordinate2D(latitude: photo.latitude, longitude: photo.longitude))
                    marker.photo = photo
                    marker.icon = UIImage(named: "photo")
                    marker.groundAnchor = CGPoint(x: 0.5, y: 0.5)
                    marker.map = map
                }
            }
            
            var bounds = GMSCoordinateBounds()
            for i in 0..<path!.count() {
                let pt = path!.coordinate(at: i)
                bounds = bounds.includingCoordinate(CLLocationCoordinate2D(latitude: pt.latitude, longitude: pt.longitude))
            }
            let update = GMSCameraUpdate.fit(bounds, withPadding: 20)
            map.moveCamera(update)
        }
        
    }
    
    override func goBack() {
        if fromRoot {
            dismiss(animated: true, completion: nil)
        } else {
            navigationItem.prompt = nil
            super.goBack()
        }
    }
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showPhoto" {
            let next = segue.destination as! PhotoController
            next.photo = sender as? Photo
        }
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
