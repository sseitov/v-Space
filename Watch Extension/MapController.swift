//
//  MapController.swift
//  iNear
//
//  Created by Сергей Сейтов on 12.12.16.
//  Copyright © 2016 Сергей Сейтов. All rights reserved.
//

import WatchKit

class MapController: WKInterfaceController {

    @IBOutlet var map: WKInterfaceMap!
    
    var myLocation:CLLocationCoordinate2D?
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
//        myLocation = CLLocationCoordinate2D(latitude: 55.764637, longitude:37.604888)

        if let point = context as? [String:Any], let lat = point["latitude"] as? Double, let lon = point["longitude"] as? Double {
            myLocation = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            let span = MKCoordinateSpanMake(0.1, 0.1)
            let region = MKCoordinateRegionMake(myLocation!, span)
            map.setRegion(region)
            map.addAnnotation(myLocation!, with: .red)
        }

    }
    
    @IBAction func changeZoom(_ value: Float) {
        if myLocation != nil {
            let degrees:CLLocationDegrees = CLLocationDegrees(value) / 10.0
            let span = MKCoordinateSpanMake(degrees, degrees)
            let region = MKCoordinateRegionMake(myLocation!, span)
            map.setRegion(region)
        }
    }

}
