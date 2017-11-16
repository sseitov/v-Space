//
//  LocationController.swift
//  v-Space
//
//  Created by Сергей Сейтов on 23.10.2017.
//  Copyright © 2017 Сергей Сейтов. All rights reserved.
//

import UIKit
import Firebase
import GoogleMaps
import AFNetworking
import SVProgressHUD

class LocationController: UIViewController {

    var friendUid:String?
    var friendName:String?
    var friendImage:UIImage?

    @IBOutlet weak var map: GMSMapView!
    
    private var friendMarker:GMSMarker?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupBackButton()
        map.isMyLocationEnabled = true
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(LocationController.update(_:)),
                                               name: updateLocationNotification,
                                               object: nil)

        refresh()
    }

    @objc func update(_ notify:Notification) {
        if let uid = notify.object as? String, uid == friendUid!, notify.userInfo != nil {
            if let lat = notify.userInfo!["latitude"] as? Double,
                let lon = notify.userInfo!["longitude"] as? Double,
                let dateVal = notify.userInfo!["date"] as? Double
            {
                let date = Date(timeIntervalSince1970: dateVal)
                let dateStr = textDateFormatter().string(from: date)
                self.setupTitle("\(self.friendName!) \n\(dateStr)")
                
                if self.friendMarker != nil {
                    self.friendMarker?.map = nil
                }
                
                let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                self.friendMarker = GMSMarker(position: coord)
                self.friendMarker!.icon = self.friendImage!.withSize(CGSize(width: 30, height: 30)).inCircle()
                self.friendMarker!.groundAnchor = CGPoint(x: 0.5, y: 0.5)
                self.friendMarker!.map = self.map
                
                let bounds = GMSCoordinateBounds(coordinate: map.myLocation!.coordinate, coordinate: coord)
                let update = GMSCameraUpdate.fit(bounds, withPadding: 100)
                self.map.moveCamera(update)
            }
        }
    }
    
    @IBAction func refresh() {
        SVProgressHUD.show()
        PushManager.shared.pushCommand(friendUid!, command:"askLocaton", success: { result in
            SVProgressHUD.dismiss()
            if !result {
                self.showMessage(LOCALIZE("requestError"), messageType: .error)
            }
        })
    }
}
