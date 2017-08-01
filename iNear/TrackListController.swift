//
//  TrackListController.swift
//  v-Space
//
//  Created by Сергей Сейтов on 28.03.17.
//  Copyright © 2017 Сергей Сейтов. All rights reserved.
//

import UIKit
import Photos
import SVProgressHUD
import GoogleMaps
import GooglePlaces
import GooglePlacePicker

class CustomGMSPlacePickerViewController : GMSPlacePickerViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if IS_PAD() {
            setupTitle(NSLocalizedString("Places nearby", comment: ""), color: UIColor.mainColor())
        } else {
            setupTitle(NSLocalizedString("Places nearby", comment: ""))
        }
        if !IS_PAD() {
            self.navigationItem.rightBarButtonItem?.tintColor = UIColor.white
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(image: UIImage(named: "backButton"), style: .plain, target: nil, action: nil)
            self.navigationItem.leftBarButtonItem?.tintColor = UIColor.white
            setupBackButton()
            let searchBarTextAttributes = [NSForegroundColorAttributeName: UIColor.white]
            UITextField.appearance(whenContainedInInstancesOf:[UISearchBar.self]).defaultTextAttributes = searchBarTextAttributes
        }
    }
}

class TrackListController: UITableViewController, LastTrackCellDelegate, PHPhotoLibraryChangeObserver, GMSPlacePickerViewControllerDelegate {

    var tracks:[Track] = []
    var places:[Place] = []
    var assets:[PHAsset] = []

    deinit {
        NotificationCenter.default.removeObserver(self)
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTitle("v-Space")
        
        if IS_PAD() {
            if tracks.count > 0 {
                performSegue(withIdentifier: "showDetail", sender: tracks[0])
            } else {
                performSegue(withIdentifier: "showDetail", sender: nil)
            }
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.refreshPlaces), name: newPlaceNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.refreshCurrentTrack), name: newPointNotification, object: nil)
        PHPhotoLibrary.shared().register(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tracks = Model.shared.allTracks()
        places = Model.shared.allPlaces()
        tableView.reloadData()
    }
    
    func refreshPlaces() {
        places = Model.shared.allPlaces()
        self.tableView.reloadData()
    }
    
    func refreshCurrentTrack() {
        let indexPath = IndexPath(row: 0, section: 0)
        tableView.reloadRows(at: [indexPath], with: .fade)
    }
    
    @IBAction func refresh() {
        
        func finishSync() {
            tracks = Model.shared.allTracks()
            places = Model.shared.allPlaces()
            tableView.reloadData()
            if IS_PAD() {
                if tracks.count > 0 {
                    performSegue(withIdentifier: "showDetail", sender: tracks[0])
                } else {
                    performSegue(withIdentifier: "showDetail", sender: nil)
                }
            }
        }

        SVProgressHUD.show(withStatus: "iCloud Sync...")
        Cloud.shared.syncPlaces({ placesError in
            if placesError != nil {
                SVProgressHUD.dismiss()
                self.showMessage(placesError!, messageType: .error)
            } else {
                Cloud.shared.syncTracks({ tracksError in
                    SVProgressHUD.dismiss()
                    if tracksError != nil {
                        self.showMessage(tracksError!, messageType: .error)
                    } else {
                        finishSync()
                    }
                })
            }
        })
    }
    
    func saveLastTrack() {
        if let points = Model.shared.lastTrack() {
            if points.count < 2 {
                Model.shared.clearLastTrack()
                self.assets.removeAll()
                return
            }
            let path = GMSMutablePath()
            for pt in points {
                path.add(CLLocationCoordinate2D(latitude: pt.latitude, longitude: pt.longitude))
            }
            let ask = TextInput.create(cancelHandler: {
                Model.shared.clearLastTrack()
                self.assets.removeAll()
            }, acceptHandler: { name in
                let track = Model.shared.createTrack(name, path: path.encodedPath(), start: points.last!.date, finish: points.first!.date, distance: Model.shared.lastTrackDistance())
                Model.shared.clearLastTrack()
                Cloud.shared.saveTrack(track, assets: self.assets)
                self.assets.removeAll()
                
                self.tableView.beginUpdates()
                self.tracks.insert(track, at: 0)
                self.tableView.insertRows(at: [IndexPath(row: 0, section: 1)], with: .bottom)
                self.tableView.endUpdates()
                
            })
            ask?.show()
        }

    }
    
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        DispatchQueue.main.sync {
            if let date = Model.shared.lastLocationDate(first: true) {
                self.putPhotosOnTrack(date, result: { success in
                    if !success {
                        self.showMessage(NSLocalizedString("photoLibrary", comment: ""), messageType: .error)
                    }
                })
            }
        }
    }

    private func putPhotosOnTrack(_ date:Date, result:@escaping (Bool) -> ()) {
        if PHPhotoLibrary.authorizationStatus() != .authorized {
            PHPhotoLibrary.requestAuthorization({ status in
                DispatchQueue.main.async {
                    if status == .authorized {
                        self.scanCameraRollChanges(date)
                        result(true)
                    } else {
                        result(false)
                    }
                }
            })
        } else {
            self.scanCameraRollChanges(date)
            result(true)
        }
    }
 
    private func scanCameraRollChanges(_ date:Date) {
        let syncedResult = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumUserLibrary, options: nil)
        if syncedResult.count > 0 {
            let collection = syncedResult.object(at: 0)
            let options = PHFetchOptions()
            options.sortDescriptors = [ NSSortDescriptor(key: "creationDate", ascending: false) ]
            options.predicate = NSPredicate(format: "creationDate > %@", date as CVarArg)
            let fetchResult = PHAsset.fetchAssets(in: collection, options: options)
            fetchResult.enumerateObjects({ asset, index, _ in
                if !self.assets.contains(asset) {
                    self.assets.append(asset)
                }
            })
        }
    }
 
    @IBAction func nearByMe(_ sender: Any) {
        SVProgressHUD.show(withStatus: "Get location...")
        LocationManager.shared.getCurrentLocation({ location in
            SVProgressHUD.dismiss()
            if location != nil {
                let center = location!.coordinate
                let northEast = CLLocationCoordinate2D(latitude: center.latitude + 0.1, longitude: center.longitude + 0.1)
                let southWest = CLLocationCoordinate2D(latitude: center.latitude - 0.1, longitude: center.longitude - 0.1)
                let viewport = GMSCoordinateBounds(coordinate: northEast, coordinate: southWest)
                let config = GMSPlacePickerConfig(viewport: viewport)
                let placePicker = CustomGMSPlacePickerViewController(config: config)
                placePicker.delegate = self
                if IS_PAD() {
                    self.present(placePicker, animated: true, completion: nil)
                } else {
                    self.navigationController?.pushViewController(placePicker, animated: true)
                }
            } else {
                self.showMessage("Can not get current location", messageType: .error)
            }
        })
    }
    
    func placePicker(_ viewController: GMSPlacePickerViewController, didPick place: GMSPlace) {
        if IS_PAD() {
            dismiss(animated: true, completion: {
                self.performSegue(withIdentifier: "placeInfo", sender: place)
            })
        } else {
            self.performSegue(withIdentifier: "placeInfo", sender: place)
        }
    }
    
    func placePickerDidCancel(_ viewController: GMSPlacePickerViewController) {
        dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 1:
            return tracks.count
        case 2:
            return places.count
        default:
            return 1
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return indexPath.section == 1 ? 80 : 60
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 1:
            return NSLocalizedString("my tracks", comment: "")
        case 2:
            return NSLocalizedString("bookmarks of interesing places", comment: "")
        default:
            return NSLocalizedString("current track", comment: "")
        }
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 40
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "lastTrack", for: indexPath) as! LastTrackCell
            cell.delegate = self
            return cell
        } else if indexPath.section == 1 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "savedTrack", for: indexPath) as! SavedTrackCell
            cell.track = tracks[indexPath.row]
            return cell
        } else {
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = places[indexPath.row].name
            cell.textLabel?.font = UIFont.condensedFont()
            cell.textLabel?.textColor = UIColor.mainColor()
            cell.accessoryType = .disclosureIndicator
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return (indexPath.section > 0)
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            if indexPath.section == 1 {
                let track = tracks[indexPath.row]
                SVProgressHUD.show(withStatus: "Delete...")
                Cloud.shared.deleteTrack(track, complete: {
                    SVProgressHUD.dismiss()
                    self.tableView.beginUpdates()
                    self.tracks.remove(at: indexPath.row)
                    self.tableView.deleteRows(at: [indexPath], with: .top)
                    self.tableView.endUpdates()
                    if IS_PAD() {
                        if self.tracks.count > 0 {
                            self.performSegue(withIdentifier: "showDetail", sender: self.tracks[0])
                        } else {
                            self.performSegue(withIdentifier: "showDetail", sender: nil)
                        }
                    }
                })
            } else {
                let place = places[indexPath.row]
                SVProgressHUD.show(withStatus: "Delete...")
                Cloud.shared.deletePlace(place, complete: {
                    SVProgressHUD.dismiss()
                    self.tableView.beginUpdates()
                    self.places.remove(at: indexPath.row)
                    self.tableView.deleteRows(at: [indexPath], with: .top)
                    self.tableView.endUpdates()
                    if IS_PAD() {
                        if self.tracks.count > 0 {
                            self.performSegue(withIdentifier: "showDetail", sender: self.tracks[0])
                        } else {
                            self.performSegue(withIdentifier: "showDetail", sender: nil)
                        }
                    }
                })
            }
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0  {
            if Model.shared.lastTrackSize() > 1 {
                performSegue(withIdentifier: "showDetail", sender: nil)
            }
        } else if indexPath.section == 1 {
            performSegue(withIdentifier: "showDetail", sender: tracks[indexPath.row])
        } else {
            tableView.deselectRow(at: indexPath, animated: false)
            performSegue(withIdentifier: "placeInfo", sender: places[indexPath.row])
        }
    }
    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showDetail" {
            let nav = segue.destination as! UINavigationController
            let controller = nav.topViewController as! TrackController
            controller.track = sender as? Track
        } else if segue.identifier == "placeInfo" {
            let nav = segue.destination as! UINavigationController
            let controller = nav.topViewController as! PlaceInfoController
            controller.gmsPlace = sender as? GMSPlace
            controller.place = sender as? Place
            controller.myCoordinate = LocationManager.shared.currentLocation?.coordinate
        }
    }

}
