//
//  ContactsController.swift
//  iNear
//
//  Created by Сергей Сейтов on 15.11.16.
//  Copyright © 2016 Сергей Сейтов. All rights reserved.
//

import UIKit
import Firebase
import SVProgressHUD

class ContactsController: UITableViewController {
    
    var contacts:[Contact] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTitle("Contacts")
        tableView.allowsSelectionDuringEditing = false
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(ContactsController.refresh),
                                               name: contactNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(ContactsController.refreshStatus),
                                               name: newMessageNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(ContactsController.refreshStatus),
                                               name: readMessageNotification,
                                               object: nil)

    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if currentUser() == nil {
            try? FIRAuth.auth()?.signOut()
            performSegue(withIdentifier: "login", sender: self)
        } else {
            Model.shared.startObservers()
            refresh()
        }
    }
    
    func refresh() {
        if let allContacts = currentUser()!.contacts?.allObjects as? [Contact] {
            contacts.removeAll()
            contacts = allContacts
        }
        tableView.reloadData()
        if IS_PAD() {
            if contacts.count > 0 {
                performSegue(withIdentifier: "showDetail", sender: contacts[0])
            } else {
                performSegue(withIdentifier: "showDetail", sender: nil)
            }
        }
    }
    
    func refreshStatus() {
        tableView.reloadData()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return currentUser() != nil ? contacts.count : 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Contact", for: indexPath) as! ContactCell
        cell.contact = contacts[indexPath.row]
        return cell
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let contact = contacts[indexPath.row]
            if let index = contacts.index(of: contact) {
                tableView.beginUpdates()
                contacts.remove(at: index)
                Model.shared.deleteContact(contact)
                tableView.deleteRows(at: [indexPath], with: .top)
                tableView.endUpdates()
                if contacts.count == 0 {
                    performSegue(withIdentifier: "showDetail", sender: nil)
                }
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let contact = contacts[indexPath.row]
        switch contact.getContactStatus() {
        case .requested:
            if contact.initiator != currentUser()!.uid, let user = Model.shared.getUser(contact.initiator!) {
                let question = createQuestion("\(user.shortName) ask you to add him into contact list. Are you agree?",
                    acceptTitle: "Yes", cancelTitle: "No",
                    acceptHandler: {
                        Model.shared.approveContact(contact)
                }, cancelHandler: {
                        Model.shared.rejectContact(contact)
                        self.refresh()
                })
                question?.show()
            }
        case .approved:
            self.performSegue(withIdentifier: "showDetail", sender: contact)
        default:
            break
        }
    }
    
    @IBAction func addContact(_ sender: Any) {
        let alert = EmailInput.getEmail(cancelHandler: {
        }, acceptHandler: { email in
            SVProgressHUD.show(withStatus: "Search...")
            let ref = FIRDatabase.database().reference()
            ref.child("users").queryOrdered(byChild: "email").queryEqual(toValue: email).observeSingleEvent(of: .value, with: { snapshot in
                if let values = snapshot.value as? [String:Any] {
                    for uid in values.keys {
                        if uid != currentUser()!.uid! {
                            if Model.shared.contactWithUser(uid) != nil {
                                SVProgressHUD.dismiss()
                                self.showMessage("This user is in list already.", messageType: .information)
                                return
                            } else if let profile = values[uid] as? [String:Any] {
                                let user = Model.shared.createUser(uid)
                                user.setUserData(profile, completion:{
                                    Model.shared.addContact(with: user)
                                    SVProgressHUD.dismiss()
                                    self.refresh()
                                })
                                return
                            }
                        }
                    }
                    SVProgressHUD.dismiss()
                    self.showMessage("User not found.", messageType: .error)
                } else {
                    SVProgressHUD.dismiss()
                    self.showMessage("User not found.", messageType: .error)
                }
            })
        })
        alert?.show()
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "showDetail" {
            if let contact = sender as? Contact {
                if let user = Model.shared.getUser(contact.uid!) {
                    if user.token == nil {
                        self.showMessage("\(user.shortName) does not available for chat now.", messageType: .information)
                        return false
                    }
                }
            }
        }
        return true
    }
    
    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showDetail" {
            let nav = segue.destination as! UINavigationController
            if let controller = nav.topViewController as? ChatController {
                if let contact = sender as? Contact {
                    if contact.getContactStatus() == .approved {
                        if contact.initiator! == currentUser()!.uid! {
                            controller.user = Model.shared.getUser(contact.requester!)
                        } else {
                            controller.user = Model.shared.getUser(contact.initiator!)
                        }
                    }
                }
            }
        }
    }
}
