//
//  TrackController.swift
//  iNear
//
//  Created by Сергей Сейтов on 27.01.17.
//  Copyright © 2017 Сергей Сейтов. All rights reserved.
//

import UIKit
import GoogleMaps

class TrackController: UIViewController {

    @IBOutlet weak var map: GMSMapView!
    
    var track:Track?
    var fromRoot = false

    override func viewDidLoad() {
        super.viewDidLoad()
        setupBackButton()
        
        let all = track == nil ? LocationManager.shared.lastTrack() : track!.trackPoints()
        let path = GMSMutablePath()
        for pt in all! {
            path.add(CLLocationCoordinate2D(latitude: pt.latitude, longitude: pt.longitude))
        }
        if track == nil {
            setupTitle("Current track", promptText: textDateFormatter().string(from: LocationManager.shared.lastLocationDate()!))
        } else {
            setupTitle(track!.place!, promptText: textDateFormatter().string(from: track!.trackDate()))
        }
        
        let userTrack = GMSPolyline(path: path)
        userTrack.strokeColor = UIColor.traceColor()
        userTrack.strokeWidth = 4
        userTrack.map = map
        
        let finish = path.coordinate(at:0)
        let finishMarker = GMSMarker(position: CLLocationCoordinate2D(latitude: finish.latitude, longitude: finish.longitude))
        finishMarker.icon = UIImage(named: "finishPoint")
        finishMarker.groundAnchor = CGPoint(x: 0.5, y: 0.5)
        finishMarker.map = map
        
        let start = path.coordinate(at: path.count() - 1)
        let startMarker = GMSMarker(position: CLLocationCoordinate2D(latitude: start.latitude, longitude: start.longitude))
        startMarker.icon = UIImage(named: "startPoint")
        startMarker.groundAnchor = CGPoint(x: 0.5, y: 0.5)
        startMarker.map = map
        
        var bounds = GMSCoordinateBounds()
        for i in 0..<path.count() {
            let pt = path.coordinate(at: i)
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

}
