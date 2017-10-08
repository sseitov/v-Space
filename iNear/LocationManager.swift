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
    var authCondition:NSCondition?
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
        registeredInUse({ enable in
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
                        self.currentLocation = nil
                    }
                }
            } else {
                location(nil)
            }
        })
    }
    
    func registeredInUse(_  isRegistered: @escaping(Bool) -> ()) {
        if CLLocationManager.locationServicesEnabled() {
            switch CLLocationManager.authorizationStatus() {
            case .authorizedWhenInUse:
                isRegistered(true)
            case .authorizedAlways:
                isRegistered(true)
            case .notDetermined:
                authCondition = NSCondition()
                self.locationManager.requestAlwaysAuthorization()
                DispatchQueue.global().async {
                    self.authCondition?.lock()
                    self.authCondition?.wait()
                    self.authCondition?.unlock()
                    DispatchQueue.main.async {
                        self.authCondition = nil
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
    
    func registeredAlways(_  isRegistered: @escaping(Bool) -> ()) {
        if CLLocationManager.locationServicesEnabled() {
            switch CLLocationManager.authorizationStatus() {
            case .authorizedAlways:
                isRegistered(true)
            case .notDetermined:
                authCondition = NSCondition()
                self.locationManager.requestAlwaysAuthorization()
                DispatchQueue.global().async {
                    self.authCondition?.lock()
                    self.authCondition?.wait()
                    self.authCondition?.unlock()
                    DispatchQueue.main.async {
                        self.authCondition = nil
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
        if status != .notDetermined {
            self.authCondition?.lock()
            self.authCondition?.signal()
            self.authCondition?.unlock()
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
