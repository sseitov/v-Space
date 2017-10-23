//
//  LocationController.swift
//  v-Space
//
//  Created by Сергей Сейтов on 23.10.2017.
//  Copyright © 2017 Сергей Сейтов. All rights reserved.
//

import UIKit
import Firebase
import SVProgressHUD
import GoogleMaps
import AFNetworking

class LocationController: UIViewController {

    var friendUid:String?
    var friendName:String?
    var friendImage:UIImage?
    var friendToken:String?

    @IBOutlet weak var map: GMSMapView!
    
    private var friendMarker:GMSMarker?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupBackButton()
        map.isMyLocationEnabled = true
        refresh()
    }

    @IBAction func refresh() {
        SVProgressHUD.show(withStatus: "Get location")
        PushManager.shared.askLocation(friendToken!)
        LocationManager.shared.getCurrentLocation({ location in
            if location == nil {
                SVProgressHUD.dismiss()
            } else {
                self.map.camera = GMSCameraPosition.camera(withTarget: location!.coordinate, zoom: 6)
                let ref = Database.database().reference()
                ref.child("locations").child(self.friendUid!).observeSingleEvent(of: .value, with: { snapshot in
                    SVProgressHUD.dismiss()
                    if let values = snapshot.value as? [String:Any] {
                        if let dateVal = values["date"] as? Double {
                            let date = Date(timeIntervalSince1970: dateVal)
                            let dateStr = textDateFormatter().string(from: date)
                            self.setupTitle("\(self.friendName!) \n\(dateStr)")
                        }
                        if self.friendMarker != nil {
                            self.friendMarker?.map = nil
                        }
                        if let lat = values["latitude"] as? Double, let lon = values["longitude"] as? Double {
                            let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                            self.friendMarker = GMSMarker(position: coord)
                            self.friendMarker!.icon = self.friendImage!.withSize(CGSize(width: 30, height: 30)).inCircle()
                            self.friendMarker!.groundAnchor = CGPoint(x: 0.5, y: 0.5)
                            self.friendMarker!.map = self.map
                            
                            let bounds = GMSCoordinateBounds(coordinate: location!.coordinate, coordinate: coord)
                            let update = GMSCameraUpdate.fit(bounds, withPadding: 100)
                            self.map.moveCamera(update)
                        }
                    }
                })
            }
        })

    }
}
