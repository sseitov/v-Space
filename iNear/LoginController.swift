//
//  LoginController.swift
//  iNear
//
//  Created by Сергей Сейтов on 21.11.16.
//  Copyright © 2016 Сергей Сейтов. All rights reserved.
//

import UIKit
import Firebase
import SVProgressHUD
import SDWebImage

class LoginController: UIViewController, GIDSignInDelegate, GIDSignInUIDelegate, TextFieldContainerDelegate {
    
    @IBOutlet weak var authView: UIView!
    @IBOutlet weak var usrField: TextFieldContainer!
    @IBOutlet weak var pwdField: TextFieldContainer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        GIDSignIn.sharedInstance().clientID = FIRApp.defaultApp()?.options.clientID
        GIDSignIn.sharedInstance().delegate = self
        GIDSignIn.sharedInstance().uiDelegate = self
        
        usrField.textType = .emailAddress
        usrField.placeholder = "email address"
        usrField.returnType = .next
        usrField.delegate = self
        
        pwdField.placeholder = "password"
        pwdField.returnType = .go
        pwdField.secure = true
        pwdField.delegate = self
        
        navigationItem.hidesBackButton = true
        authView.alpha = 1
        setupTitle("Authentication")
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.tapScreen))
        self.view.addGestureRecognizer(tap)
    }

    func tapScreen() {
        TextFieldContainer.deactivateAll()
    }
    
    func textDone(_ sender:TextFieldContainer, text:String?) {
        if sender == usrField {
            if usrField.text().isEmail() {
                pwdField.activate(true)
            } else {
                showMessage("Email should have xxxx@domain.prefix format.", messageType: .error, messageHandler: {
                    self.usrField.activate(true)
                })
            }
        } else {
            if pwdField.text().isEmpty {
                showMessage("Password field required.", messageType: .error, messageHandler: {
                    self.pwdField.activate(true)
                })
            } else if usrField.text().isEmpty {
                usrField.activate(true)
            } else {
                emailAuth(user: usrField.text(), password: pwdField.text())
            }
        }
    }
    
    func textChange(_ sender:TextFieldContainer, text:String?) -> Bool {
        return true
    }
    
    override func goBack() {
        dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Email Auth
    
    func emailSignUp(user:String, password:String) {
        SVProgressHUD.show(withStatus: "SignUp...")
        FIRAuth.auth()?.createUser(withEmail: user, password: password, completion: { firUser, error in
            SVProgressHUD.dismiss()
            if error != nil {
                self.showMessage((error as! NSError).localizedDescription, messageType: .error)
            } else {
                Model.shared.setEmailUser(firUser!, email: user)
                self.goBack()
            }
        })
    }
    
    func emailAuth(user:String, password:String) {
        SVProgressHUD.show(withStatus: "Login...")
        FIRAuth.auth()?.signIn(withEmail: user, password: password, completion: { firUser, error in
            let err = error as? NSError
            if err != nil {
                SVProgressHUD.dismiss()
                if let reason = err!.userInfo["error_name"] as? String  {
                    if reason == "ERROR_USER_NOT_FOUND" {
                        let alert = self.createQuestion("User \(user) not found. Do you want to sign up?", acceptTitle: "SignUp", cancelTitle: "Cancel", acceptHandler: {
                            self.emailSignUp(user: user, password: password)
                        })
                        alert?.show()
                    } else {
                        self.showMessage(err!.localizedDescription, messageType: .error)
                    }
                } else {
                    self.showMessage(err!.localizedDescription, messageType: .error)
                }
            } else {
                SVProgressHUD.dismiss()
                Model.shared.setEmailUser(firUser!, email: user)
                LocationManager.shared.startInBackground()
                self.goBack()
            }
        })
    }
    
    // MARK: - Google+ Auth
    
    @IBAction func facebookSignIn(_ sender: Any) { // read_custom_friendlists
        FBSDKLoginManager().logIn(withReadPermissions: ["public_profile","email"], from: self, handler: { result, error in
            if error != nil {
                self.showMessage("Facebook authorization error.", messageType: .error)
                return
            }
            
            SVProgressHUD.show(withStatus: "Login...") // interested_in
            let params = ["fields" : "name,email,first_name,last_name,birthday,picture.width(480).height(480)"]
            let request = FBSDKGraphRequest(graphPath: "me", parameters: params)
            request!.start(completionHandler: { _, result, fbError in
                if fbError != nil {
                    SVProgressHUD.dismiss()
                    self.showMessage(fbError!.localizedDescription, messageType: .error)
                } else {
                    let credential = FIRFacebookAuthProvider.credential(withAccessToken: FBSDKAccessToken.current().tokenString)
                    FIRAuth.auth()?.signIn(with: credential, completion: { firUser, error in
                        if error != nil {
                            SVProgressHUD.dismiss()
                            self.showMessage((error as NSError?)!.localizedDescription, messageType: .error)
                        } else {
                            if let profile = result as? [String:Any] {
                                Model.shared.setFacebookUser(firUser!, profile: profile, completion: {
                                    SVProgressHUD.dismiss()
                                    LocationManager.shared.startInBackground()
                                    self.goBack()
                                })
                            } else {
                                self.showMessage("Can not read user profile.", messageType: .error)
                                try? FIRAuth.auth()?.signOut()
                            }
                        }
                    })
                }
            })
        })
    }
    
    // MARK: - Google+ Auth
    
    @IBAction func googleSitnIn(_ sender: Any) {
        GIDSignIn.sharedInstance().signIn()
    }
    
    func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!, withError error: Error!) {
        if error != nil {
            showMessage(error.localizedDescription, messageType: .error)
            return
        }
        let authentication = user.authentication
        let credential = FIRGoogleAuthProvider.credential(withIDToken: (authentication?.idToken)!,
                                                          accessToken: (authentication?.accessToken)!)
        SVProgressHUD.show(withStatus: "Login...")
        FIRAuth.auth()?.signIn(with: credential, completion: { firUser, error in
            if error != nil {
                SVProgressHUD.dismiss()
                self.showMessage((error as NSError?)!.localizedDescription, messageType: .error)
            } else {
                Model.shared.setGoogleUser(firUser!, googleProfile: user.profile, completion: {
                    SVProgressHUD.dismiss()
                    LocationManager.shared.startInBackground()
                    self.goBack()
                })
            }
        })
    }
    
    func sign(_ signIn: GIDSignIn!, didDisconnectWith user: GIDGoogleUser!, withError error: Error!) {
        try? FIRAuth.auth()?.signOut()
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showTrack" {
            let controller = segue.destination as! TrackController
            controller.user = currentUser()
        }
    }

}
