//
//  PlaceInfoController.swift
//  v-Space
//
//  Created by Сергей Сейтов on 27.04.17.
//  Copyright © 2017 Сергей Сейтов. All rights reserved.
//

import UIKit
import GooglePlaces
import CoreTelephony
import SVProgressHUD

class PlaceInfoController: UITableViewController {

    var gmsPlace:GMSPlace?
    var place:Place?
    var myCoordinate:CLLocationCoordinate2D?
 
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTitle(gmsPlace != nil ? gmsPlace!.name : place!.name!)
        if IS_PAD() {
            navigationItem.leftBarButtonItem = nil
            navigationItem.hidesBackButton = true
        } else {
            setupBackButton()
        }
        if gmsPlace == nil {
            navigationItem.rightBarButtonItem = nil
        }
        
        if myCoordinate == nil {
            SVProgressHUD.show(withStatus: "Get location...")
            LocationManager.shared.getCurrentLocation({ location in
                SVProgressHUD.dismiss()
                if location != nil {
                    self.myCoordinate = location!.coordinate
                } else {
                    self.showMessage("Can not get current location.", messageType: .error)
                }
            })
        }
    }

    @IBAction func savePlace(_ sender: Any) {
        SVProgressHUD.show(withStatus: "Save...")
        Cloud.shared.savePlace(gmsPlace!, result: { error in
            SVProgressHUD.dismiss()
            if error != nil {
                self.showMessage(error!, messageType: .error)
            } else {
                NotificationCenter.default.post(name: newPlaceNotification, object: nil)
            }
        })
    }
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let isWebSite = gmsPlace != nil ? (gmsPlace?.website != nil) : (place?.website != nil)
        return isWebSite ? 3 : 2
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 40
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return indexPath.row == 1 ? 80 : 40
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "information"
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.accessoryType = .disclosureIndicator
        cell.textLabel?.font = UIFont.condensedFont(13)
        cell.textLabel?.textColor = UIColor.mainColor()
        cell.detailTextLabel?.font = UIFont.mainFont()
        cell.detailTextLabel?.textColor = UIColor.mainColor()
        cell.detailTextLabel?.numberOfLines = 0
        cell.detailTextLabel?.lineBreakMode = .byWordWrapping
        switch indexPath.row {
        case 0:
            cell.textLabel?.text = "PHONE"
            cell.detailTextLabel?.text = gmsPlace != nil ? gmsPlace?.phoneNumber : place?.phone
        case 1:
            cell.detailTextLabel?.text = gmsPlace != nil ? gmsPlace?.formattedAddress : place?.address
        case 2:
            cell.textLabel?.text = "WEB SITE"
            cell.detailTextLabel?.text = "Open"
        default:
            break
        }
        return cell
    }

    private func canMakePhoneCall() -> Bool {
        guard let url = URL(string: "tel://") else {
            return false
        }
        
        let mobileNetworkCode = CTTelephonyNetworkInfo().subscriberCellularProvider?.mobileNetworkCode
        
        let isInvalidNetworkCode = mobileNetworkCode == nil
            || mobileNetworkCode?.characters.count == 0
            || mobileNetworkCode == "65535"
        
        return UIApplication.shared.canOpenURL(url) && !isInvalidNetworkCode
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        switch indexPath.row {
        case 0:
            let phoneNumber = gmsPlace != nil ? gmsPlace?.phoneNumber : place?.phone
            if phoneNumber != nil {
                if canMakePhoneCall() {
                    let number = "tel://\(phoneNumber!)".replacingOccurrences(of: " ", with: "")
                    if let url = URL(string: number) {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    }
                } else {
                    self.showMessage("Your device can not make phone call.", messageType: .error)
                }
            }
        case 1:
            if myCoordinate != nil {
                performSegue(withIdentifier: "route", sender: nil)
            }
        case 2:
            performSegue(withIdentifier: "webPage", sender: nil)
        default:
            break
        }
    }
    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "webPage" {
            let next = segue.destination as! WebController
            next.placeName = gmsPlace != nil ? gmsPlace!.name : place!.name!
            if gmsPlace != nil {
                next.placeWebSite = gmsPlace!.website
            } else {
                if place!.website != nil {
                    next.placeWebSite = URL(string: place!.website!)
                }
            }
        } else if segue.identifier == "route" {
            let next = segue.destination as! RouteController
            next.myCoordinate = myCoordinate
            next.placeName = gmsPlace != nil ? gmsPlace!.name : place!.name!
            next.placeCoordinate = gmsPlace != nil ? gmsPlace!.coordinate : CLLocationCoordinate2D(latitude: place!.latitude, longitude: place!.longitude)
        }
    }

}
