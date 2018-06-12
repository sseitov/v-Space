//
//  TrackManager.swift
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

class TrackManager: NSObject, CLLocationManagerDelegate {
    
    static let shared = TrackManager()
    
    let manager: CLLocationManager = CLLocationManager()
    var isRunning:Bool = false
    
    private override init() {
        super.init()
        self.manager.delegate = self
        self.manager.desiredAccuracy = kCLLocationAccuracyBest
        self.manager.distanceFilter = 10.0
        self.manager.headingFilter = 5.0
        self.manager.pausesLocationUpdatesAutomatically = false
    }
    
    func startInBackground() -> Bool {
        if CLLocationManager.locationServicesEnabled() {
            switch CLLocationManager.authorizationStatus() {
            case .notDetermined:
                manager.requestAlwaysAuthorization()
                return true
            case .authorizedAlways:
                manager.startUpdatingLocation()
                manager.allowsBackgroundLocationUpdates = true
                isRunning = true
                return true
            default:
                return false
            }
        } else {
            return false
        }
    }
    
    func stop() {
        isRunning = false
        manager.stopUpdatingLocation()
    }
    
    //MARK: CLLocationManager Delegate methods
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedAlways {
            manager.startUpdatingLocation()
            manager.allowsBackgroundLocationUpdates = true
            isRunning = true
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            if isRunning && checkAccurancy(location) {
                Model.shared.addCoordinate(location.coordinate, at:NSDate().timeIntervalSince1970)
            }
        }
    }
}

class LocationManager: NSObject, CLLocationManagerDelegate {
    
    static let shared = LocationManager()
    
    let manager: CLLocationManager = CLLocationManager()
    var locationClosure: ((_ location: CLLocation) -> ())?

    private override init() {
        super.init()
        self.manager.delegate = self
        self.manager.desiredAccuracy = kCLLocationAccuracyBest
        self.manager.distanceFilter = 10.0
        self.manager.headingFilter = 5.0
    }
    
    func getCurrentLocation(_ closure: @escaping((_ location: CLLocation) -> ())) -> Bool {
        if CLLocationManager.locationServicesEnabled() {
            switch CLLocationManager.authorizationStatus() {
            case .notDetermined:
                manager.requestAlwaysAuthorization()
                return true
            case .restricted:
                return false
            case .denied:
                return false
            default:
                self.locationClosure = closure
                manager.startUpdatingLocation()
                return true
            }
        } else {
            return false
        }
    }
    
    //MARK: CLLocationManager Delegate methods
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            manager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last, let closure = self.locationClosure {
            closure(location)
            self.locationClosure = nil
            self.manager.stopUpdatingLocation()
        }
    }

}
