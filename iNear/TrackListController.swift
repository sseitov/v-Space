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
import GoogleSignIn
import FBSDKLoginKit
import Firebase

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
            let searchBarTextAttributes = [NSAttributedStringKey.foregroundColor.rawValue : UIColor.white]
            UITextField.appearance(whenContainedInInstancesOf:[UISearchBar.self]).defaultTextAttributes = searchBarTextAttributes
        }
    }
}

class TrackListController: UITableViewController, LastTrackCellDelegate, PHPhotoLibraryChangeObserver, GMSPlacePickerViewControllerDelegate, GIDSignInDelegate, GIDSignInUIDelegate {

    var tracks:[Track] = []
    var places:[Place] = []
    var assets:[PHAsset] = []

    deinit {
        NotificationCenter.default.removeObserver(self)
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let versionNumber: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        setupTitle("v-Space ( \(versionNumber) )")
        
        GIDSignIn.sharedInstance().clientID = FirebaseApp.app()?.options.clientID
        GIDSignIn.sharedInstance().delegate = self
        GIDSignIn.sharedInstance().uiDelegate = self

        if IS_PAD() {
            if Model.shared.trackerIsRunning() {
                performSegue(withIdentifier: "showDetail", sender: nil)
            } else if tracks.count > 0 {
                performSegue(withIdentifier: "showDetail", sender: tracks[0])
            }
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.refreshPlaces), name: newPlaceNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.refreshCurrentTrack), name: newPointNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.finishSync), name: syncNotification, object: nil)
        
        PHPhotoLibrary.shared().register(self)
        
        Cloud.shared.sync({ error in
            if error != nil {
                self.showMessage(error!, messageType: .error)
            }
        })
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        finishSync()
    }
    
    @objc func refreshPlaces() {
        places = Model.shared.allPlaces()
        self.tableView.reloadData()
    }
    
    @objc func refreshCurrentTrack() {
        let indexPath = IndexPath(row: 0, section: 0)
        tableView.reloadRows(at: [indexPath], with: .fade)
    }
    
    @objc func finishSync() {
        tracks = Model.shared.allTracks()
        places = Model.shared.allPlaces()
        tableView.reloadData()
    }

    // MARK: - LastTrackCell delegate

    func accessDenied() {
        self.showMessage(NSLocalizedString("Can not get current location always.", comment: ""), messageType: .error)
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
                Model.shared.addPhotosIntoTrack(track, assets: self.assets)
                Cloud.shared.saveTrack(track)
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
    
    // MARK: - Places nearby

    @IBAction func nearByMe(_ sender: Any) {
        SVProgressHUD.show(withStatus: "Get location...")
        if !LocationManager.shared.getCurrentLocation({ location in
            SVProgressHUD.dismiss()
            let center = location.coordinate
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
        }) {
            SVProgressHUD.dismiss()
            showMessage("Location service disabled.".localized, messageType: .information)
        }
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
        SVProgressHUD.dismiss()
        if editingStyle == .delete {
            if indexPath.section == 1 {
                let track = tracks[indexPath.row]
                SVProgressHUD.show(withStatus: "Delete...")
                Cloud.shared.deleteTrack(track, complete: { success in
                    SVProgressHUD.dismiss()
                    if success {
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
                    } else {
                        self.showMessage(NSLocalizedString("iCloud unavailable", comment: ""), messageType: .error)
                    }
                })
            } else {
                let place = places[indexPath.row]
                SVProgressHUD.show(withStatus: "Delete...")
                Cloud.shared.deletePlace(place, complete: { success in
                    SVProgressHUD.dismiss()
                    if success {
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
                    } else {
                        self.showMessage(NSLocalizedString("iCloud unavailable", comment: ""), messageType: .error)
                    }
                })
            }
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        SVProgressHUD.dismiss()
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
    
    @IBAction func saveList(_ sender: Any) {
        if Auth.auth().currentUser != nil {
            self.performSegue(withIdentifier: "trustList", sender: nil)
        } else {
            let ask = createQuestion("trustList".localized, acceptTitle: "Ok", cancelTitle: "Cancel", acceptHandler: {
                let askProvider = ActionSheet.create(title: "Choose provider",
                                                     actions: ["Google+", "Facebook"],
                                                     handler1:
                    {
                        GIDSignIn.sharedInstance().signIn()
                }, handler2:
                    {
                        self.facebookSignIn()
                })
                askProvider?.show()
            })
            ask?.show()
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
        }
    }
    
    // MARK: - Google+ Auth
    
    func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!, withError error: Error!) {
        if error != nil {
            showMessage(error.localizedDescription, messageType: .error)
            return
        }
        let authentication = user.authentication
        let credential = GoogleAuthProvider.credential(withIDToken: (authentication?.idToken)!,
                                                       accessToken: (authentication?.accessToken)!)
        SVProgressHUD.show(withStatus: "Login...")
        Auth.auth().signInAndRetrieveData(with: credential, completion: { result, error in
            if error != nil {
                SVProgressHUD.dismiss()
                self.showMessage((error as NSError?)!.localizedDescription, messageType: .error)
            } else {
                if AuthModel.shared.updatePerson(Auth.auth().currentUser) {
                    SVProgressHUD.dismiss()
                    AuthModel.shared.startObservers()
                    self.performSegue(withIdentifier: "trustList", sender: nil)
                } else {
                    AuthModel.shared.signOut {
                        SVProgressHUD.dismiss()
                        self.showMessage("Can not upload profile data.", messageType: .error)
                    }
                }
            }
        })
    }
    
    func sign(_ signIn: GIDSignIn!, didDisconnectWith user: GIDGoogleUser!, withError error: Error!) {
        try? Auth.auth().signOut()
    }
    
    // MARK: - Facebook Auth
    func facebookSignIn() { // read_custom_friendlists
        FBSDKLoginManager().logIn(withReadPermissions: ["public_profile","email","user_friends","user_photos"], from: self, handler: { result, error in
            if error != nil {
                self.showMessage("Facebook authorization error.", messageType: .error)
                return
            }
            
            SVProgressHUD.show(withStatus: "Login...") // interested_in
            let params = ["fields" : "name,email,picture.width(480).height(480)"]
            let request = FBSDKGraphRequest(graphPath: "me", parameters: params)
            request!.start(completionHandler: { _, result, fbError in
                if fbError != nil {
                    SVProgressHUD.dismiss()
                    self.showMessage(fbError!.localizedDescription, messageType: .error)
                } else {
                    let credential = FacebookAuthProvider.credential(withAccessToken: FBSDKAccessToken.current().tokenString)
                    Auth.auth().signInAndRetrieveData(with: credential, completion: { result, error in
                        if error != nil {
                            SVProgressHUD.dismiss()
                            self.showMessage((error as NSError?)!.localizedDescription, messageType: .error)
                        } else {
                            if AuthModel.shared.updatePerson(Auth.auth().currentUser) {
                                SVProgressHUD.dismiss()
                                AuthModel.shared.startObservers()
                                self.performSegue(withIdentifier: "trustList", sender: nil)
                            } else {
                                AuthModel.shared.signOut {
                                    SVProgressHUD.dismiss()
                                    self.showMessage("Can not upload profile data.", messageType: .error)
                                }
                            }
                        }
                    })
                }
            })
        })
    }
}
