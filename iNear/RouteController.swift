//
//  RouteController.swift
//  v-Space
//
//  Created by Сергей Сейтов on 27.04.17.
//  Copyright © 2017 Сергей Сейтов. All rights reserved.
//

import UIKit
import GooglePlaces
import GoogleMaps
import AFNetworking
import SVProgressHUD

class RouteController: UIViewController {

    @IBOutlet weak var map: GMSMapView!
    
    var myCoordinate:CLLocationCoordinate2D?
    var place:GMSPlace?
    private var placeMarker:GMSMarker?

    override func viewDidLoad() {
        super.viewDidLoad()
        super.viewDidLoad()
        setupTitle(place!.name)
        setupBackButton()
        
        map.camera = GMSCameraPosition.camera(withTarget: place!.coordinate, zoom: 6)
        map.isMyLocationEnabled = true
        placeMarker = GMSMarker(position: place!.coordinate)
        placeMarker!.icon = UIImage(named: "near")
        placeMarker!.title = place!.name
        placeMarker!.map = map
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let bounds = GMSCoordinateBounds(coordinate: myCoordinate!, coordinate: place!.coordinate)
        let update = GMSCameraUpdate.fit(bounds, withPadding: 100)
        map.moveCamera(update)
        
        SVProgressHUD.show(withStatus: "Create route...")
        
        createDirection(from: myCoordinate!, to: place!.coordinate, completion: { result in
            SVProgressHUD.dismiss()
            if result == -1 {
                self.showMessage("Can not create route to \(self.place!.name)", messageType: .error)
            } else if result == 0 {
                self.showMessage("You are in the same place.", messageType: .information)
            }
        })
    }
    
    func createDirection(from:CLLocationCoordinate2D, to:CLLocationCoordinate2D, completion: @escaping(Int) -> ()) {
        let urlStr = String(format: "https://maps.googleapis.com/maps/api/directions/json?origin=%f,%f&destination=%f,%f&key=%@", from.latitude, from.longitude, to.latitude, to.longitude, GoolgleMapAPIKey)
        let manager = AFHTTPSessionManager()
        manager.requestSerializer = AFHTTPRequestSerializer()
        manager.responseSerializer = AFJSONResponseSerializer()
        manager.get(urlStr, parameters: nil, progress: nil, success: { task, response in
            if let json = response as? [String:Any] {
                if let routes = json["routes"] as? [Any] {
                    if let route = routes.first as? [String:Any] {
                        if let line = route["overview_polyline"] as? [String:Any] {
                            if let points = line["points"] as? String {
                                if let path = GMSPath(fromEncodedPath: points) {
                                    if path.count() > 2 {
                                        let polyline = GMSPolyline(path: path)
                                        polyline.strokeColor = UIColor.color(28, 79, 130, 0.7)
                                        polyline.strokeWidth = 7
                                        polyline.map = self.map
                                        completion(1)
                                    } else {
                                        completion(0)
                                    }
                                } else {
                                    completion(-1)
                                }
                                return
                            }
                        }
                    }
                }
            }
            completion(-1)
        }, failure: { task, error in
            print("SEND PUSH ERROR: \(error)")
            completion(-1)
        })
        
    }

}
