//
//  LocationManager.swift
//  v-Space
//
//  Created by Sergey Seitov on 01.08.17.
//  Copyright © 2017 Сергей Сейтов. All rights reserved.
//

import Foundation
import CoreLocation
/*
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
//    private var authCondition:NSCondition?

    private override init() {
        super.init()
        trackManager.delegate = self
        trackManager.desiredAccuracy = kCLLocationAccuracyBest
        trackManager.distanceFilter = 10.0
        trackManager.headingFilter = 5.0
        trackManager.pausesLocationUpdatesAutomatically = false
    }
/*
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
    */
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
*/
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
            } else if CLLocationManager.authorizationStatus() == .authorizedAlways {
                manager.startUpdatingLocation()
            }
        }
    }
    
    //MARK: CLLocationManager Delegate methods
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            manager.startUpdatingLocation()
            if locationClosure == nil {
                manager.allowsBackgroundLocationUpdates = true
                isPaused = false
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            if self.locationClosure != nil {
                self.locationClosure!(location)
            } else {
                if !isPaused {
                    Model.shared.addCoordinate(location.coordinate, at:NSDate().timeIntervalSince1970)
                }
            }
            self.locationClosure = nil
        }
    }
}

