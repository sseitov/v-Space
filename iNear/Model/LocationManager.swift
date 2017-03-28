//
//  LocationManager.swift
//  iNear
//
//  Created by Сергей Сейтов on 01.03.17.
//  Copyright © 2017 Сергей Сейтов. All rights reserved.
//

import UIKit
import CoreLocation
import CoreData

class LocationManager: NSObject {
    
    static let shared = LocationManager()
    
    let locationManager = CLLocationManager()
   
    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10.0
        locationManager.headingFilter = 5.0
//        locationManager.activityType = .automotiveNavigation
        locationManager.pausesLocationUpdatesAutomatically = false
    }

    func register() {
        if CLLocationManager.locationServicesEnabled() {
            if CLLocationManager.authorizationStatus() != .authorizedAlways {
                locationManager.requestAlwaysAuthorization()
            }
        }
    }
    
    func start() {
        if CLLocationManager.authorizationStatus() == .authorizedAlways {
            locationManager.startUpdatingLocation()
            sharedDefaults.set(true, forKey: "trackerRunning")
            sharedDefaults.synchronize()
        }
    }
    
    func startInBackground() {
        if CLLocationManager.authorizationStatus() == .authorizedAlways {
            start()
            locationManager.allowsBackgroundLocationUpdates = true
        }
    }
    
    func stop() {
        if isRunning() {
            locationManager.stopUpdatingLocation()
            sharedDefaults.set(false, forKey: "trackerRunning")
            sharedDefaults.synchronize()
        }
    }
    
    func isRunning() -> Bool {
        return sharedDefaults.bool(forKey: "trackerRunning")
    }
    
    // MARK: - CoreData stack
    
    lazy var sharedDefaults: UserDefaults = {
        return UserDefaults(suiteName: "group.com.vchannel.iNearby")!
    }()
    
    lazy var sharedDocumentsDirectory: URL = {
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.vchannel.iNearby")!
    }()
    
    lazy var managedObjectModel: NSManagedObjectModel = {
        let modelURL = Bundle.main.url(forResource: "LocationModel", withExtension: "momd")!
        return NSManagedObjectModel(contentsOf: modelURL)!
    }()
    
    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        let url = self.sharedDocumentsDirectory.appendingPathComponent("LocationModel.sqlite")
        do {
            try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: [NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true])
        } catch {
            print("CoreData data error: \(error)")
        }
        return coordinator
    }()
    
    lazy var managedObjectContext: NSManagedObjectContext = {
        let coordinator = self.persistentStoreCoordinator
        var managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = coordinator
        return managedObjectContext
    }()
    
    func saveContext () {
        if managedObjectContext.hasChanges {
            do {
                try managedObjectContext.save()
            } catch {
                print("Saved data error: \(error)")
            }
        }
    }
    
    // MARK: - Location table
    
    func addCoordinate(_ coordinate:CLLocationCoordinate2D, at:Double) {
        let point = NSEntityDescription.insertNewObject(forEntityName: "Location", into: managedObjectContext) as! Location
        point.date = at
        point.latitude = coordinate.latitude
        point.longitude = coordinate.longitude
        saveContext()
    }

    func myLocation() -> CLLocationCoordinate2D {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Location")
        let sortDescriptor = NSSortDescriptor(key: "date", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]
        fetchRequest.fetchLimit = 1
        if let all = try? managedObjectContext.fetch(fetchRequest) as! [Location], let location = all.first {
            return CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
        } else {
            return CLLocationCoordinate2D()
        }
    }
    
    func myLastLocationDate() -> Date? {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Location")
        let sortDescriptor = NSSortDescriptor(key: "date", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]
        fetchRequest.fetchLimit = 1
        if let all = try? managedObjectContext.fetch(fetchRequest) as! [Location], let location = all.first {
            return Date(timeIntervalSince1970: location.date)
        } else {
            return nil
        }
    }

    func myTrack(_ size:Int = 0) -> [Location]? {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Location")
        let sortDescriptor = NSSortDescriptor(key: "date", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]
        if size > 0 {
            fetchRequest.fetchLimit = size
        }
        return try? managedObjectContext.fetch(fetchRequest) as! [Location]
    }
    
    func myTrackPointsForLastDay() -> [Location]? {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Location")
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -1, to: Date())
        fetchRequest.predicate = NSPredicate(format: "date >= %f", startDate!.timeIntervalSince1970)
        let sortDescriptor = NSSortDescriptor(key: "date", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]
        if let all = try? managedObjectContext.fetch(fetchRequest) as! [Location], all.count > 1 {
            return all
        } else {
            return nil
        }
    }
    
    func clearTrack() {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Location")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        _ = try? persistentStoreCoordinator.execute(deleteRequest, with: managedObjectContext)
    }
    
    func trackSize() -> Int {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Location")
        if let count = try? managedObjectContext.count(for: fetchRequest) {
            return count
        } else {
            return 0
        }
    }
}

extension LocationManager : CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            if location.horizontalAccuracy <= 10.0 {
                addCoordinate(location.coordinate, at:NSDate().timeIntervalSince1970)
            }
        }
    }
}
