//
//  SettingsController.swift
//  iNear
//
//  Created by Сергей Сейтов on 03.03.17.
//  Copyright © 2017 Сергей Сейтов. All rights reserved.
//

import UIKit

class SettingsController: UITableViewController, TrackerCellDelegate, ProfileCellDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTitle("Settings")
        setupBackButton()
    }

    override func goBack() {
        dismiss(animated: true, completion: nil)
    }

    func trackerStatusChanged() {
        tableView.reloadData()
    }
    
    func signOut() {
        let alert = createQuestion("Are you really want to sign out?", acceptTitle: "Yes", cancelTitle: "Cancel", acceptHandler: {
            LocationManager.shared.stop()
            Model.shared.signOut()
            self.dismiss(animated: true, completion: nil)
        })
        alert?.show()
    }
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? 3 : 1
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? "tracker" : "account"
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 40
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 1 {
            let profileCell = tableView.dequeueReusableCell(withIdentifier: "profile", for: indexPath) as! ProfileCell
            profileCell.accountType.text = currentUser()!.socialTypeName()
            profileCell.account.text = currentUser()!.email!
            profileCell.delegate = self
            return profileCell
        } else {
            if indexPath.row == 0 {
                let trackerCell = tableView.dequeueReusableCell(withIdentifier: "tracker", for: indexPath) as! TrackerCell
                trackerCell.delegate = self
                return trackerCell
            } else {
                let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
                cell.selectionStyle = .none
                cell.textLabel?.font = UIFont.condensedFont()
                if LocationManager.shared.trackSize() > 1 {
                    cell.textLabel?.textColor = UIColor.mainColor()
                } else {
                    cell.textLabel?.textColor = UIColor.mainColor(0.3)
                }
                if indexPath.row == 1 {
                    cell.textLabel?.text = "Show track"
                    cell.accessoryType = .disclosureIndicator
                } else {
                    cell.textLabel?.text = "Clear track"
                    cell.accessoryType = .none
                }
                return cell
            }
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if LocationManager.shared.trackSize() > 1 {
            if indexPath.row == 1 {
                performSegue(withIdentifier: "showTrack", sender: nil)
            } else if indexPath.row == 2 {
                LocationManager.shared.clearTrack()
                tableView.reloadData()
            }
        }
    }
    
}
