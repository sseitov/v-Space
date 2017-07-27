//
//  Cloud.swift
//  v-Space
//
//  Created by Сергей Сейтов on 23.04.17.
//  Copyright © 2017 Сергей Сейтов. All rights reserved.
//

import UIKit
import CloudKit
import Photos
import GoogleMaps
import GooglePlaces

@objc class Cloud: NSObject {
    
    static let shared = Cloud()
    
    var cloudDB: CKDatabase?
    
    private override init() {
        super.init()
        
        let container = CKContainer.default()
        cloudDB = container.privateCloudDatabase
    }
    
    private func getTracks(_ tracks:@escaping ([Track], String?) -> ()) {
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: "Track", predicate: predicate)
        
        cloudDB!.perform(query, inZoneWith: nil) { results, error in
            guard error == nil else {
                DispatchQueue.main.async {
                    tracks([], "iCloud error: \(error!.localizedDescription)")
                }
                return
            }
            
            DispatchQueue.main.async {
                var newTracks:[Track] = []
                for record in results! {
                    if let uid = record.value(forKey: "uid") as? String,
                        let place = record.value(forKey: "place") as? String,
                        let path = record.value(forKey: "track") as? String,
                        let date = record.value(forKey: "date") as? Double,
                        let startDate = record.value(forKey: "startDate") as? Double,
                        let distance = record.value(forKey: "distance") as? Double
                    {
                        var track = LocationManager.shared.getTrack(uid)
                        if track == nil {
                            track = LocationManager.shared.saveTrack(uid, name: place, path: path, start: startDate, finish:date, distance: distance)
                        }
                        newTracks.append(track!)
                    }
                }
                tracks(newTracks, nil)
            }
        }
    }
    
    private func photoID(_ photos:[PHAsset], forDate:Double) -> String? {
        for photo in photos {
            let date = photo.creationDate!.timeIntervalSince1970
            if Int64(date) == Int64(forDate) {
                return photo.localIdentifier
            }
        }
        return nil
    }
    
    private func attachPhotosToTrack(_ track:Track, existing:[PHAsset], complete:@escaping () -> ()) {
        let predicate = NSPredicate(format: "trackID = %@", track.uid!)
        let query = CKQuery(recordType: "Photo", predicate: predicate)
        cloudDB!.perform(query, inZoneWith: nil) { results, error in
            guard error == nil else {
                DispatchQueue.main.async {
                    complete()
                }
                return
            }
            
            DispatchQueue.main.async {
                for record in results! {
                    if let photoDate = record.value(forKey: "photoDate") as? Double,
                        let latitude = record.value(forKey: "latitude") as? Double,
                        let longitude = record.value(forKey: "longitude") as? Double
                    {
                        if let uid = self.photoID(existing, forDate: photoDate), LocationManager.shared.getPhoto(uid) == nil {
                            LocationManager.shared.addPhotoIntoTrack(track, uid: uid, date: photoDate, latitude: latitude, longitude: longitude)
                        }
                    }
                }
                complete()
            }
        }
    }
    
    func syncTracks(_ photos:[PHAsset], error:@escaping (String?) -> ()) {
        let oldTracks = LocationManager.shared.allTracks()
        getTracks({ tracks, err in
            if err != nil {
                error(err)
            } else {
                let next = NSCondition()
                DispatchQueue.global().async {
                    for track in tracks {
                        self.attachPhotosToTrack(track, existing: photos, complete: {
                            next.lock()
                            next.signal()
                            next.unlock()
                        })
                        next.lock()
                        next.wait()
                        next.unlock()
                    }
                    DispatchQueue.main.async {
                        for old in oldTracks {
                            if !tracks.contains(old) {
                                LocationManager.shared.managedObjectContext.delete(old)
                                LocationManager.shared.saveContext()
                            }
                        }
                        error(nil)
                    }
                }
            }
        })
    }
    
    func syncPlaces(_ result:@escaping (String?) -> ()) {
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: "Place", predicate: predicate)
        let oldPlaces = LocationManager.shared.allPlaces()

        cloudDB!.perform(query, inZoneWith: nil) { results, error in
            guard error == nil else {
                DispatchQueue.main.async {
                    result("iCloud error: \(error!.localizedDescription)")
                }
                return
            }
            
            DispatchQueue.main.async {
                var newPlaces:[Place] = []
                for record in results! {
                    if let placeID = record.value(forKey: "placeID") as? String,
                        let name = record.value(forKey: "name") as? String,
                        let latitude = record.value(forKey: "latitude") as? Double,
                        let longitude = record.value(forKey: "longitude") as? Double
                    {
                        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                        let phone = record.value(forKey: "phone") as? String
                        let address = record.value(forKey: "address") as? String
                        let website = record.value(forKey: "website") as? String
                        let url = website != nil ? URL(string: website!) : nil
                        let place = LocationManager.shared.createPlace(placeID,
                                                           name: name,
                                                           coordinate: coordinate,
                                                           phone: phone,
                                                           address: address,
                                                           website: url)
                        newPlaces.append(place!)
                    }
                }
                for old in oldPlaces {
                    if !newPlaces.contains(old) {
                        LocationManager.shared.managedObjectContext.delete(old)
                        LocationManager.shared.saveContext()
                    }
                }
                result(nil)
            }
        }
    }
    
    private func savePhotos(_ photos:[Photo], complete:@escaping () -> ()) {
        let next = NSCondition()
        DispatchQueue.global().async {
            for photo in photos {
                let record = CKRecord(recordType: "Photo")
                record.setValue(photo.creationDate!.timeIntervalSince1970, forKey: "photoDate")
                record.setValue(photo.latitude, forKey: "latitude")
                record.setValue(photo.longitude, forKey: "longitude")
                record.setValue(photo.track!.uid!, forKey: "trackID")
                self.cloudDB!.save(record, completionHandler: { record, error in
                    if error != nil {
                        print(error!.localizedDescription)
                    }
                    DispatchQueue.main.async {
                        next.lock()
                        next.signal()
                        next.unlock()
                    }
                })
                next.lock()
                next.wait()
                next.unlock()
            }
            DispatchQueue.main.async {
                complete()
            }
        }
    }
    
    private func saveTrack(_ track:Track) {
        let record = CKRecord(recordType: "Track")
        record.setValue(track.path!, forKey: "track")
        record.setValue(track.place!, forKey: "place")
        record.setValue(track.finishDate!.timeIntervalSince1970, forKey: "date")
        record.setValue(track.startDate!.timeIntervalSince1970, forKey: "startDate")
        record.setValue(track.distance, forKey: "distance")
        record.setValue(track.uid!, forKey: "uid")
        self.cloudDB!.save(record, completionHandler: { record, error in
            if error != nil {
                print(error!.localizedDescription)
            }
        })
    }
    
    func putTrack(_ track:Track) {
        if let photos = track.photos?.allObjects as? [Photo] {
            self.savePhotos(photos, complete: {
                self.saveTrack(track)
            })
        } else {
            self.saveTrack(track)
        }
    }
    
    func savePlace(_ place:GMSPlace, result:@escaping (String?) -> ()) {
        if LocationManager.shared.getPlace(place.placeID) == nil {
            _ = LocationManager.shared.createPlace(place.placeID,
                                               name: place.name,
                                               coordinate: place.coordinate,
                                               phone: place.phoneNumber,
                                               address: place.formattedAddress,
                                               website: place.website)
            let record = CKRecord(recordType: "Place")
            record.setValue(place.placeID, forKey: "placeID")
            record.setValue(place.name, forKey: "name")
            record.setValue(place.coordinate.latitude, forKey: "latitude")
            record.setValue(place.coordinate.longitude, forKey: "longitude")
            if place.phoneNumber != nil {
                record.setValue(place.phoneNumber!, forKey: "phone")
            }
            if place.formattedAddress != nil {
                record.setValue(place.formattedAddress!, forKey: "address")
            }
            if place.website != nil {
                record.setValue(place.website!.absoluteString, forKey: "website")
            }
            self.cloudDB!.save(record, completionHandler: { record, error in
                DispatchQueue.main.async {
                    if let error = error {
                        result("iCloud error: \(error.localizedDescription)")
                    } else {
                        result(nil)
                    }
                }
            })
        } else {
            result("Place already synced.")
        }
    }
    
    private func deletePhotos(_ track:Track, complete:@escaping () -> ()) {
        let next = NSCondition()
        let predicate = NSPredicate(format: "trackID = %@", track.uid!)
        let query = CKQuery(recordType: "Photo", predicate: predicate)
        cloudDB!.perform(query, inZoneWith: nil) { results, error in
            guard error == nil else {
                DispatchQueue.main.async {
                    print(error!.localizedDescription)
                    complete()
                }
                return
            }
            
            for record in results! {
                self.cloudDB?.delete(withRecordID: record.recordID, completionHandler: { _, error in
                    DispatchQueue.main.async {
                        if error != nil {
                            print(error!.localizedDescription)
                        }
                        next.lock()
                        next.signal()
                        next.unlock()
                    }
                })
                next.lock()
                next.wait()
                next.unlock()
            }
            DispatchQueue.main.async {
                complete()
            }
        }
    }

    func deleteTrack(_ track:Track, complete:@escaping () -> ()) {
        deletePhotos(track, complete: {
            let predicate = NSPredicate(format: "uid = %@", track.uid!)
            let query = CKQuery(recordType: "Track", predicate: predicate)
            self.cloudDB!.perform(query, inZoneWith: nil) { results, error in
                guard error == nil else {
                    DispatchQueue.main.async {
                        print(error!.localizedDescription)
                        complete()
                    }
                    return
                }
                if let record = results!.first {
                    self.cloudDB?.delete(withRecordID: record.recordID, completionHandler: { _, error in
                        DispatchQueue.main.async {
                            if error != nil {
                                print(error!.localizedDescription)
                            }
                            LocationManager.shared.managedObjectContext.delete(track)
                            LocationManager.shared.saveContext()
                            complete()
                        }
                    })
                } else {
                    DispatchQueue.main.async {
                        LocationManager.shared.managedObjectContext.delete(track)
                        LocationManager.shared.saveContext()
                        complete()
                    }
                }
            }
        })
    }
    
    func deletePlace(_ place:Place, complete:@escaping () -> ()) {
        let predicate = NSPredicate(format: "placeID = %@", place.placeID!)
        let query = CKQuery(recordType: "Place", predicate: predicate)
        self.cloudDB!.perform(query, inZoneWith: nil) { results, error in
            guard error == nil else {
                DispatchQueue.main.async {
                    print(error!.localizedDescription)
                    complete()
                }
                return
            }
            if let record = results!.first {
                self.cloudDB?.delete(withRecordID: record.recordID, completionHandler: { _, error in
                    DispatchQueue.main.async {
                        if error != nil {
                            print(error!.localizedDescription)
                        }
                        LocationManager.shared.managedObjectContext.delete(place)
                        LocationManager.shared.saveContext()
                        complete()
                    }
                })
            } else {
                DispatchQueue.main.async {
                    LocationManager.shared.managedObjectContext.delete(place)
                    LocationManager.shared.saveContext()
                    complete()
                }
            }
        }
    }
}
