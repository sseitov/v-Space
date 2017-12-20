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

class LocationManager: NSObject, CLLocationManagerDelegate {
    
    static let shared = LocationManager()
    
    let manager: CLLocationManager
    var isPaused:Bool = true
    var locationClosure: ((_ location: CLLocation) -> ())?
    
    private override init() {
        self.manager = CLLocationManager()
        super.init()
        self.manager.delegate = self
        self.manager.desiredAccuracy = kCLLocationAccuracyBest
        self.manager.distanceFilter = 10.0
        self.manager.headingFilter = 5.0
        self.manager.pausesLocationUpdatesAutomatically = false
    }
    
    func startInBackground() {
        if CLLocationManager.locationServicesEnabled() {
            if CLLocationManager.authorizationStatus() == .notDetermined {
                manager.requestAlwaysAuthorization()
            } else if CLLocationManager.authorizationStatus() == .restricted || CLLocationManager.authorizationStatus() == .denied {
            } else if CLLocationManager.authorizationStatus() == .authorizedAlways {
                manager.startUpdatingLocation()
                manager.allowsBackgroundLocationUpdates = true
                isPaused = false
            }
        }
    }
    
    func stop() {
        manager.stopUpdatingLocation()
        isPaused = true
    }

    func getCurrentLocation(_ closure: @escaping((_ location: CLLocation) -> ())) {
        
        self.locationClosure = closure
        
        if CLLocationManager.locationServicesEnabled() {
            if CLLocationManager.authorizationStatus() == .notDetermined {
                manager.requestAlwaysAuthorization()
            } else if CLLocationManager.authorizationStatus() == .restricted || CLLocationManager.authorizationStatus() == .denied {
            } else if CLLocationManager.authorizationStatus() == .authorizedAlways || CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
                manager.startUpdatingLocation()
                manager.allowsBackgroundLocationUpdates = true
            }
        }
    }
    
    //MARK: CLLocationManager Delegate methods
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            manager.startUpdatingLocation()
            manager.allowsBackgroundLocationUpdates = true
            if locationClosure == nil {
                isPaused = false
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            if self.locationClosure != nil {
                self.locationClosure!(location)
                self.locationClosure = nil
                self.manager.stopUpdatingLocation()
            } else {
                if !isPaused && checkAccurancy(location) {
                    Model.shared.addCoordinate(location.coordinate, at:NSDate().timeIntervalSince1970)
                }
            }
        }
    }
}

