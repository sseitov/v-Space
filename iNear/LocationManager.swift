//
//  LocationManager.swift
//  v-Space
//
//  Created by Sergey Seitov on 01.08.17.
//  Copyright © 2017 Сергей Сейтов. All rights reserved.
//

import Foundation
import CoreLocation

fileprivate func checkAccurancy(_ location:CLLocation) -> Bool {
    if IS_PAD() {
        return true
    } else {
        return location.horizontalAccuracy <= 10.0
    }
}

class Tracker : NSObject, CLLocationManagerDelegate {
    
    static let shared = Tracker()
    
    var isPaused:Bool = true
    
    private let trackManager = CLLocationManager()
    private var authCondition:NSCondition?

    private override init() {
        super.init()
        trackManager.delegate = self
        trackManager.desiredAccuracy = kCLLocationAccuracyBest
        trackManager.distanceFilter = 10.0
        trackManager.headingFilter = 5.0
        trackManager.pausesLocationUpdatesAutomatically = false
    }
    
    func registeredAlways(_  isRegistered: @escaping(Bool) -> ()) {
        if CLLocationManager.locationServicesEnabled() {
            switch CLLocationManager.authorizationStatus() {
            case .authorizedAlways:
                isRegistered(true)
            case .notDetermined:
                authCondition = NSCondition()
                self.trackManager.requestAlwaysAuthorization()
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
        trackManager.startUpdatingLocation()
        trackManager.allowsBackgroundLocationUpdates = true
        isPaused = false
    }
    
    func stop() {
        trackManager.stopUpdatingLocation()
        isPaused = true
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
            if !isPaused {
                Model.shared.addCoordinate(location.coordinate, at:NSDate().timeIntervalSince1970)
            }
        }
    }

}

class LocationManager: NSObject, CLLocationManagerDelegate {
    
    static let shared = LocationManager()
    
    private let locationManager = CLLocationManager()
    private var authCondition:NSCondition?
    private var locationCondition:NSCondition?
    private var currentLocation:CLLocation?

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10.0
        locationManager.headingFilter = 5.0
        locationManager.pausesLocationUpdatesAutomatically = false
    }
    
    private func registeredInUse(_  isRegistered: @escaping(Bool) -> ()) {
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
                    self.locationCondition = nil
                    DispatchQueue.main.async {
                        location(self.currentLocation)
                    }
                }
            } else {
                location(nil)
            }
        })
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
            self.currentLocation = location
            locationManager.stopUpdatingLocation()
            if self.locationCondition != nil {
                self.locationCondition?.lock()
                self.locationCondition?.signal()
                self.locationCondition?.unlock()
            }
        }
    }

}

