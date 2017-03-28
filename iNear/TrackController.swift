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
    
    var user:User?
    var track:String?
    var fromRoot = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if user == nil {
            setupTitle("My Track")
        } else {
            setupTitle("\(user!.shortName) track for last day")
        }
        setupBackButton()
        
        var path:GMSPath?
        if track == nil {
            let all = LocationManager.shared.myTrack()
            let mutablePath = GMSMutablePath()
            for pt in all! {
                mutablePath.add(CLLocationCoordinate2D(latitude: pt.latitude, longitude: pt.longitude))
            }
            path = mutablePath
        } else {
            path = GMSPath(fromEncodedPath: track!)
        }
        
        let userTrack = GMSPolyline(path: path)
        userTrack.strokeColor = UIColor.traceColor()
        userTrack.strokeWidth = 4
        userTrack.map = map
        if let finish = path?.coordinate(at:0) {
            let finishMarker = GMSMarker(position: CLLocationCoordinate2D(latitude: finish.latitude, longitude: finish.longitude))
            finishMarker.icon = UIImage(named: "finishPoint")
            finishMarker.groundAnchor = CGPoint(x: 0.5, y: 0.5)
            finishMarker.map = map
        }
        if let start = path?.coordinate(at: path!.count() - 1) {
            let startMarker = GMSMarker(position: CLLocationCoordinate2D(latitude: start.latitude, longitude: start.longitude))
            startMarker.icon = UIImage(named: "startPoint")
            startMarker.groundAnchor = CGPoint(x: 0.5, y: 0.5)
            startMarker.map = map
        }
        
        var bounds = GMSCoordinateBounds()
        for i in 0..<path!.count() {
            if let pt = path?.coordinate(at: i) {
                bounds = bounds.includingCoordinate(CLLocationCoordinate2D(latitude: pt.latitude, longitude: pt.longitude))
            }
        }
        let update = GMSCameraUpdate.fit(bounds, withPadding: 20)
        map.moveCamera(update)
    }
    
    override func goBack() {
        if fromRoot {
            dismiss(animated: true, completion: nil)
        } else {
            super.goBack()
        }
    }

}
