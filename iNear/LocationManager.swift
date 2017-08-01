//
//  LocationManager.swift
//  v-Space
//
//  Created by Sergey Seitov on 01.08.17.
//  Copyright © 2017 Сергей Сейтов. All rights reserved.
//

import Foundation
import CoreLocation

class LocationManager: NSObject {
    
    static let shared = Model()
    
    let locationManager = CLLocationManager()
    
    var locationCondition:NSCondition?
    var currentLocation:CLLocation?
    var isPaused:Bool = true
    
    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10.0
        locationManager.headingFilter = 5.0
        locationManager.pausesLocationUpdatesAutomatically = false
    }
    
    func getCurrentLocation(_ location: @escaping(CLLocation?) -> ()) {
        if CLLocationManager.locationServicesEnabled() {
            if CLLocationManager.authorizationStatus() != .authorizedAlways {
                self.locationManager.requestWhenInUseAuthorization()
                location(nil)
            } else {
                currentLocation = nil
                locationCondition = NSCondition()
                self.locationManager.startUpdatingLocation()
                DispatchQueue.global().async {
                    self.locationCondition?.lock()
                    self.locationCondition?.wait()
                    self.locationCondition?.unlock()
                    DispatchQueue.main.async {
                        self.locationCondition = nil
                        location(self.currentLocation)
                    }
                }
            }
        } else {
            location(nil)
        }
    }
    
    func register() {
        if CLLocationManager.locationServicesEnabled() {
            if CLLocationManager.authorizationStatus() != .authorizedAlways {
                locationManager.requestAlwaysAuthorization()
            }
        }
    }
    
    func startInBackground() {
        if CLLocationManager.authorizationStatus() == .authorizedAlways {
            locationManager.startUpdatingLocation()
            locationManager.allowsBackgroundLocationUpdates = true
            isPaused = false
        }
    }
    
    func stop() {
        locationManager.stopUpdatingLocation()
        isPaused = true
    }

}

extension LocationManager : CLLocationManagerDelegate {
    
    private func checkAccurancy(_ location:CLLocation) -> Bool {
        if IS_PAD() {
            return true
        } else {
            return location.horizontalAccuracy <= 10.0
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last, checkAccurancy(location) {
            if self.locationCondition != nil {
                locationManager.stopUpdatingLocation()
                self.locationCondition?.lock()
                self.currentLocation = location
                self.locationCondition?.signal()
                self.locationCondition?.unlock()
            } else {
                Model.shared.addCoordinate(location.coordinate, at:NSDate().timeIntervalSince1970)
            }
        }
    }
}
