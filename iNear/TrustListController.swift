//
//  TrustListController.swift
//  v-Space
//
//  Created by Сергей Сейтов on 08.10.2017.
//  Copyright © 2017 Сергей Сейтов. All rights reserved.
//

import UIKit
import GoogleSignIn
import Firebase
import SDWebImage
import SVProgressHUD

enum InviteError {
    case none
    case notFound
    case alreadyInList
}

struct FriendPair {
    let uid:String
    let pair:[String]
    func friend() -> String {
        if currentUid()! == pair[0] {
            return pair[1]
        } else {
            return pair[0]
        }
    }
}

class TrustListController: UITableViewController, GIDSignInDelegate, UserCellDelegate {
    
    private var friendPairs:[FriendPair] = []
    private var inviteEnabled = false

    override func viewDidLoad() {
        super.viewDidLoad()        
        setupTitle(LOCALIZE("trustListTitle"))
        
        GIDSignIn.sharedInstance().clientID = "1027279802021-j65vtq40vuqvhknel6j72iqqiethlqau.apps.googleusercontent.com"
        GIDSignIn.sharedInstance().delegate = self
        GIDSignIn.sharedInstance().signInSilently()

        updateFriendList({ list in
            self.friendPairs = list
            self.tableView.reloadData()
        })
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(TrustListController.update(_:)),
                                               name: updateFriendsNotification,
                                               object: nil)

    }
    
    func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!, withError error: Error!) {
        if user != nil {
            inviteEnabled = true
        }
    }
    
    @objc func update(_ notify:Notification) {
        updateFriendList({ list in
            self.friendPairs = list
            self.tableView.reloadData()
        })
    }

    func updateFriendList(_ list: @escaping([FriendPair]) -> ()) {
        var result:[FriendPair] = []
        let ref = Database.database().reference()
        ref.child("friends").observeSingleEvent(of: .value, with: { snapshot in
            if let values = snapshot.value as? [String:Any] {
                for (key, value) in values {
                    if let pair = value as? [String] {
                        if pair[0] == currentUid()! || pair[1] == currentUid()! {
                            let friend = FriendPair(uid: key, pair: pair)
                            result.append(friend)
                        }
                    }
                }
            }
            list(result)
        })
    }
    
    // MARK: - Table view data source

    @IBAction func refresh(_ sender: UIRefreshControl) {
        updateFriendList({ list in
            self.friendPairs = list
            sender.endRefreshing()
            self.tableView.reloadData()
        })
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return LOCALIZE("myList")
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 40
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return friendPairs.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "user", for: indexPath) as! UserCell
        let friend = friendPairs[indexPath.row]
        cell.uid = friend.friend()
        cell.delegate = self
        return cell
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            tableView.beginUpdates()
            let friend = friendPairs[indexPath.row]
            let ref = Database.database().reference()
            ref.child("friends").child(friend.uid).removeValue()
            friendPairs.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .top)
            tableView.endUpdates()
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let cell = tableView.cellForRow(at: indexPath) as? UserCell {
            performSegue(withIdentifier: "map", sender: cell)
        }
    }
    
    // MARK: - Commands

    @IBAction func close(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func signOut(_ sender: Any) {
        let ask = createQuestion(LOCALIZE("SignOut"), acceptTitle: "Ok", cancelTitle: "Cancel", acceptHandler: {
            SVProgressHUD.show(withStatus: "SignOut")
            let ref = Database.database().reference()
            for friend in self.friendPairs {
                ref.child("friends").child(friend.uid).removeValue()
            }
            AuthModel.shared.signOut {
                SVProgressHUD.dismiss()
                self.dismiss(animated: true, completion: nil)
            }
        })
        ask?.show()
    }
    
    @IBAction func addFriend(_ sender: Any) {
        SVProgressHUD.show(withStatus: "Update location...")
        LocationManager.shared.getCurrentLocation({ location in
            SVProgressHUD.dismiss()
            if location == nil {
                self.showMessage("You must enable location access for v-Space in device settings.", messageType: .error)
            } else {
                let update = ["latitude" : location!.coordinate.latitude,
                              "longitude" : location!.coordinate.longitude,
                              "date" : Date().timeIntervalSince1970]
                let ref = Database.database().reference()
                ref.child("locations").child(currentUid()!).setValue(update)

                let ask = TextInput.getEmail(cancelHandler: {}, acceptHandler: { email in
                    self.findUser(email, result: { uid, token, error in
                        if token != nil {
                            PushManager.shared.pushInvite(token!, success: { result in
                                if !result {
                                    self.showMessage("Can not send invite.", messageType: .error)
                                } else {
                                    self.showMessage(LOCALIZE("inviteSent"), messageType: .information)
                                }
                            })
                        } else {
                            if error == .alreadyInList {
                                self.showMessage(LOCALIZE("alreadyInList"), messageType: .information)
                            } else {
                                if self.inviteEnabled {
                                    let ask = self.createQuestion(LOCALIZE("askNotRegistered"), acceptTitle: "Send", cancelTitle: "Cancel", acceptHandler:
                                    {
                                        self.sendInvite()
                                    })
                                    ask?.show()
                                } else {
                                    self.showMessage(LOCALIZE("notRegistered"), messageType: .error)
                                }
                            }
                        }
                    })
                })
                ask?.show()
            }
        })
    }
    
    private func sendInvite() {
        DispatchQueue.main.async {
            if let invite = Invites.inviteDialog() {
                invite.setInviteDelegate(self)
                let message = "\(Auth.auth().currentUser!.displayName!) invite you into v-Space!"
                invite.setMessage(message)
                invite.setTitle("Invite")
                invite.setDeepLink(deepLink)
                invite.setCallToActionText("Install")
                invite.open()
            }
        }
    }

    private func friendExist(_ uid:String) -> Bool {
        for friend in friendPairs {
            if friend.friend() == uid {
                return true
            }
        }
        return false
    }
    
    func findUser(_ email:String, result: @escaping(String?, String?, InviteError) -> ()) {
        SVProgressHUD.show(withStatus: "Search...")
        let ref = Database.database().reference()
        let myUid = Auth.auth().currentUser!.uid
        ref.child("users").queryOrdered(byChild: "email").queryEqual(toValue: email).observeSingleEvent(of: .value, with: { snapshot in
            if let values = snapshot.value as? [String:Any] {
                for uid in values.keys {
                    if uid == myUid {
                        continue
                    } else {
                        SVProgressHUD.dismiss()
                        if self.friendExist(uid) {
                            result(nil, nil, .alreadyInList)
                        } else {
                            if let user = values[uid] as? [String:Any], let token = user["token"] as? String {
                                result(uid, token, .none)
                            } else {
                                result(nil, nil, .notFound)
                            }
                        }
                        return
                    }
                }
                SVProgressHUD.dismiss()
                result(nil, nil, .notFound)
            } else {
                SVProgressHUD.dismiss()
                result(nil, nil, .notFound)
            }
        })
    }
    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "map" {
            let next = segue.destination as! LocationController
            if let cell = sender as? UserCell {
                next.friendUid = cell.uid
                next.friendName = cell.userName.text
                next.friendImage = cell.userImage.image
            }
        }
    }
    
    func userDidCall(_ uid:String, data:[String:Any]) {
        if let name = data["displayName"] as? String {
            ShowCall(userName: name, userID: uid, callID: nil)
        }
/*
        PushManager.shared.callRequest("TEST CALL", from: uid, userData: data, success: { isSuccess in
            if !isSuccess {
                self.showMessage(LOCALIZE("requestError"), messageType: .error)
            }
        })
 */
    }

}

extension TrustListController : InviteDelegate {
    
    func inviteFinished(withInvitations invitationIds: [String], error: Error?) {
        if let error = error {
            if error.localizedDescription != "Canceled by User" {
                let message = "Can not send invite. Error: \(error.localizedDescription)"
                showMessage(message, messageType: .error)
            }
        } else {
            let message = "\(invitationIds.count) invites sent."
            showMessage(message, messageType: .information)
        }
    }
}
