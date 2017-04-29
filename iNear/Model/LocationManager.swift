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
import Photos

// MARK: - Date formatter

func dateFormatter() -> DateFormatter {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
    return formatter
}

func textDateFormatter() -> DateFormatter {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    formatter.doesRelativeDateFormatting = true
    return formatter
}

func textYearFormatter() -> DateFormatter {
    let formatter = DateFormatter()
    formatter.dateStyle = .long
    formatter.timeStyle = .none
    return formatter
}

func IS_PAD() -> Bool {
    return UIDevice.current.userInterfaceIdiom == .pad
}

let newPointNotification = Notification.Name("NEW_POINT")

class LocationManager: NSObject {
    
    static let shared = LocationManager()
    
    let locationManager = CLLocationManager()
    
    var locationCondition:NSCondition?
    var currentLocation:CLLocation?

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10.0
        locationManager.headingFilter = 5.0
//        locationManager.activityType = .automotiveNavigation
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
        NotificationCenter.default.post(name: newPointNotification, object: nil)
        saveContext()
    }

    func lastLocation() -> CLLocationCoordinate2D {
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
    
    func lastLocationDate() -> Date? {
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

    func lastTrack() -> [Location]? {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Location")
        let sortDescriptor = NSSortDescriptor(key: "date", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]
        return try? managedObjectContext.fetch(fetchRequest) as! [Location]
    }
    
    func clearLastTrack() {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Location")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        _ = try? persistentStoreCoordinator.execute(deleteRequest, with: managedObjectContext)
    }
    
    func lastTrackSize(_ uid:String? = nil) -> Int {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Location")
        if let count = try? managedObjectContext.count(for: fetchRequest) {
            return count
        } else {
            return 0
        }
    }
    
    // MARK: - Track table

    func getTrack(_ uid:String) -> Track? {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Track")
        fetchRequest.predicate = NSPredicate(format: "uid = %@", uid)
        do {
            return try managedObjectContext.fetch(fetchRequest).first as? Track
        } catch {
            return nil
        }
    }
    
    func createTrack(_ uid:String, name:String, path:String, date:Double) -> Track {
        let track = NSEntityDescription.insertNewObject(forEntityName: "Track", into: managedObjectContext) as! Track
        track.uid = uid
        track.place = name
        track.path = path
        track.finishDate = NSDate(timeIntervalSince1970: date)
        saveContext()
        return track
    }
    
    func createTrack(_ name:String, path:String, start:Double, finish:Double) -> Track {
        let track = NSEntityDescription.insertNewObject(forEntityName: "Track", into: managedObjectContext) as! Track
        track.uid = UUID().uuidString
        track.place = name
        track.path = path
        track.startDate = NSDate(timeIntervalSince1970: start)
        track.finishDate = NSDate(timeIntervalSince1970: finish)
        saveContext()
        return track
    }
    
    func allTracks() -> [Track] {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Track")
        let sortDescriptor = NSSortDescriptor(key: "finishDate", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]
        if let all = try? managedObjectContext.fetch(fetchRequest) as! [Track] {
            return all
        } else {
            return []
        }
    }
    
    // MARK: - Place table
    
    func getPlace(_ uid:String) -> Place? {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Place")
        fetchRequest.predicate = NSPredicate(format: "placeID = %@", uid)
        do {
            return try managedObjectContext.fetch(fetchRequest).first as? Place
        } catch {
            return nil
        }
    }
    
    func createPlace(_ placeID:String, name:String, coordinate:CLLocationCoordinate2D, phone:String?, address:String?, website:URL?) -> Place? {
        var place = getPlace(placeID)
        if place == nil {
            place = NSEntityDescription.insertNewObject(forEntityName: "Place", into: managedObjectContext) as? Place
            place?.placeID = placeID
            place?.name = name
            place?.latitude = coordinate.latitude
            place?.longitude = coordinate.longitude
            place?.phone = phone
            place?.address = address
            if website != nil {
                place?.website = website!.absoluteString
            }
            saveContext()
        }
        return place
    }
    
    func allPlaces() -> [Place] {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Place")
        let sortDescriptor = NSSortDescriptor(key: "name", ascending: true)
        fetchRequest.sortDescriptors = [sortDescriptor]
        if let all = try? managedObjectContext.fetch(fetchRequest) as! [Place] {
            return all
        } else {
            return []
        }
    }

    // MARK: - Photo table

    func getPhoto(_ uid:String) -> Photo? {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Photo")
        fetchRequest.predicate = NSPredicate(format: "uid = %@", uid)
        do {
            return try managedObjectContext.fetch(fetchRequest).first as? Photo
        } catch {
            return nil
        }
    }
  
    func createPhoto(_ asset:PHAsset) -> Photo? {
        var photo = getPhoto(asset.localIdentifier)
        if photo == nil {
            photo = NSEntityDescription.insertNewObject(forEntityName: "Photo", into: managedObjectContext) as? Photo
            photo?.uid = asset.localIdentifier
            photo?.creationDate = asset.creationDate! as NSDate
            photo?.latitude = asset.location!.coordinate.latitude
            photo?.longitude = asset.location!.coordinate.longitude
            return photo!
        } else {
            return nil
        }
    }
    
    func addPhotoIntoTrack(_ track:Track, uid:String, date:Double, latitude:Double, longitude:Double) {
        var photo = getPhoto(uid)
        if photo == nil {
            photo = NSEntityDescription.insertNewObject(forEntityName: "Photo", into: managedObjectContext) as? Photo
            photo!.uid = uid
            photo!.creationDate = NSDate(timeIntervalSince1970: date)
            photo!.latitude = latitude
            photo!.longitude = longitude
            photo!.track = track
            track.addToPhotos(photo!)
            saveContext()
        }
    }
    
    func addPhotos(_ assets:[PHAsset], into:Track?) {
        for asset in assets {
            if asset.location != nil && asset.creationDate != nil {
                if let photo = createPhoto(asset) {
                    photo.track = into
                    into?.addToPhotos(photo)
                }
            }
        }
        saveContext()
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
                addCoordinate(location.coordinate, at:NSDate().timeIntervalSince1970)
            }
        }
    }
}
