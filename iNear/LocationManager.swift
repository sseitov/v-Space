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
    
    static let shared = LocationManager()
    
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
        registered({ enable in
            if enable {
                self.currentLocation = nil
                self.locationCondition = NSCondition()
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
            } else {
                location(nil)
            }
        })
    }
    
    func registered(_ isRegistered: @escaping(Bool) -> ()) {
        if CLLocationManager.locationServicesEnabled() {
            switch CLLocationManager.authorizationStatus() {
            case .authorizedAlways:
                isRegistered(true)
            case .notDetermined:
                locationCondition = NSCondition()
                self.locationManager.requestAlwaysAuthorization()
                DispatchQueue.global().async {
                    self.locationCondition?.lock()
                    self.locationCondition?.wait()
                    self.locationCondition?.unlock()
                    DispatchQueue.main.async {
                        isRegistered(CLLocationManager.authorizationStatus() == .authorizedAlways)
                    }
                }
            default:
                isRegistered(false)
            }
        } else {
            isRegistered(false)
        }
    }
    
    func startInBackground() {
        locationManager.startUpdatingLocation()
        locationManager.allowsBackgroundLocationUpdates = true
        isPaused = false
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
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedAlways {
            if self.locationCondition != nil {
                manager.startUpdatingLocation()
            } else {
                startInBackground()
            }
        } else if status != .notDetermined && self.locationCondition != nil {
            self.locationCondition?.lock()
            self.locationCondition?.signal()
            self.locationCondition?.unlock()
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
