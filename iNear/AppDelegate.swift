//
//  AppDelegate.swift
//  iNear
//
//  Created by Сергей Сейтов on 15.11.16.
//  Copyright © 2016 Сергей Сейтов. All rights reserved.
//

import UIKit
import IQKeyboardManager
import SVProgressHUD
import WatchConnectivity
import GoogleMaps
import GooglePlaces
import Firebase
import UserNotifications
import GoogleSignIn

func IS_PAD() -> Bool {
    return UIDevice.current.userInterfaceIdiom == .pad
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate {

    var window: UIWindow?
    var watchSession:WCSession?
    private var isUpdateLocation = false
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

        // Use Firebase library to configure APIs
        FirebaseApp.configure()

        
        // Register_for_notifications
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { (granted, error) in
                
                guard error == nil else {
                    //Display Error.. Handle Error.. etc..
                    return
                }
                
                if granted {
                    DispatchQueue.main.async {
                        //Register for RemoteNotifications. Your Remote Notifications can display alerts now :)
                        application.registerForRemoteNotifications()
                    }
                }
                else {
                    //Handle user denying permissions..
                }
            }
        } else {
            let settings: UIUserNotificationSettings =
                UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
            application.registerUserNotificationSettings(settings)
            application.registerForRemoteNotifications()
        }
        
        Messaging.messaging().delegate = self

        // Initialize Google Maps
        
        GMSServices.provideAPIKey(GoolgleMapAPIKey)
        GMSPlacesClient.provideAPIKey(GoolglePlacesAPIKey)
        
        // connect iWatch
        
        if WCSession.isSupported() {
            watchSession = WCSession.default
            watchSession!.delegate = self
            watchSession!.activate()
        }
        
        // UI settings
        
        let splitViewController = self.window!.rootViewController as! UISplitViewController
        let navigationController = splitViewController.viewControllers[splitViewController.viewControllers.count-1] as! UINavigationController
        navigationController.topViewController!.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem
        splitViewController.delegate = self
        
        SVProgressHUD.setDefaultStyle(.custom)
        SVProgressHUD.setBackgroundColor(UIColor.mainColor())
        SVProgressHUD.setForegroundColor(UIColor.white)

        UIApplication.shared.statusBarStyle = .lightContent
        if let font = UIFont(name: "HelveticaNeue-CondensedBold", size: 17) {
            if IS_PAD() {
                UIBarButtonItem.appearance().setTitleTextAttributes([NSAttributedStringKey.font : font, NSAttributedStringKey.foregroundColor: UIColor.mainColor()], for: .normal)
            } else {
                UIBarButtonItem.appearance().setTitleTextAttributes([NSAttributedStringKey.font : font, NSAttributedStringKey.foregroundColor: UIColor.white], for: .normal)
            }
            SVProgressHUD.setFont(font)
        }
        IQKeyboardManager.shared().isEnableAutoToolbar = false
        
        return true
    }
    
    // MARK: - Application delegate
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        if url.scheme! == "iNearby" {
            return true
        } else {
            return GIDSignIn.sharedInstance().handle(url,
                                                     sourceApplication: options[.sourceApplication] as! String!,
                                                     annotation: options[.annotation])
        }
    }

    private func pushType(_ userInfo: [AnyHashable: Any]) -> PushType {
        if let pushTypeStr = userInfo["pushType"] as? String, let type = Int(pushTypeStr), let pt = PushType(rawValue: type) {
            return pt
        }
        return .unknown
    }
    
    private func acceptInvite(_ userInfo: [AnyHashable: Any]) {
        if let requester = userInfo["requester"] as? String,
            let aps = userInfo["aps"] as? [String:Any],
            let alert = aps["alert"] as? [String:Any],
            let body = alert["body"] as? String
        {
            LocationManager.shared.getCurrentLocation({location in
                if location != nil {
                    if let currentUid = Auth.auth().currentUser?.uid {
                        let update = ["latitude" : location!.coordinate.latitude,
                                      "longitude" : location!.coordinate.longitude,
                                      "date" : Date().timeIntervalSince1970]
                        let ref = Database.database().reference()
                        ref.child("locations").child(currentUid).setValue(update)
                    }
                    let ask = self.window?.topMostWindowController?.createQuestion(body,
                                                                              acceptTitle: "Accept",
                                                                              cancelTitle: "Reject",
                                                                              acceptHandler:
                        {
                            if let currentUid = Auth.auth().currentUser?.uid {
                                let update = [currentUid, requester]
                                let ref = Database.database().reference()
                                ref.child("friends").childByAutoId().setValue(update)
                            }
                    })
                    ask?.show()
                } else {
                    self.window?.topMostWindowController?.showMessage("You must enable location access for v-Space in device settings.", messageType: .error)
                }
            })
        }
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if pushType(userInfo) == .invite {
            if application.applicationState == .active {
                acceptInvite(userInfo)
            }
        } else if !isUpdateLocation {
            isUpdateLocation = true
            LocationManager.shared.getBackgroundLocation({ location in
                self.isUpdateLocation = false
                if location != nil {
                    if let currentUid = Auth.auth().currentUser?.uid {
                        let update = ["latitude" : location!.coordinate.latitude,
                                      "longitude" : location!.coordinate.longitude,
                                      "date" : Date().timeIntervalSince1970]
                        let ref = Database.database().reference()
                        ref.child("locations").child(currentUid).setValue(update)
                    }
                }
            })
        }
        completionHandler(.newData)
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Unable to register for remote notifications: \(error.localizedDescription)")
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        #if DEBUG
            Messaging.messaging().setAPNSToken(deviceToken, type: .sandbox)
        #else
            Messaging.messaging().setAPNSToken(deviceToken, type: .prod)
        #endif
    }

    func applicationWillResignActive(_ application: UIApplication) {
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        Cloud.shared.upload()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        Cloud.shared.sync({ error in
            if error != nil {
                print(error!)
            }
        })
    }

    func applicationWillTerminate(_ application: UIApplication) {
    }

    // MARK: - Split view
    
    func splitViewController(_ svc: UISplitViewController, shouldHide vc: UIViewController, in orientation: UIInterfaceOrientation) -> Bool {
        return false
    }
    
    func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController: UIViewController, onto primaryViewController: UIViewController) -> Bool {
        return true
    }
    
    func splitViewController(_ splitViewController: UISplitViewController, showDetail vc: UIViewController, sender: Any?) -> Bool {
        if splitViewController.isCollapsed {
            var secondViewController:UIViewController? = vc as? UINavigationController
            if secondViewController != nil {
                secondViewController = (secondViewController as! UINavigationController).topViewController
            } else {
                secondViewController = vc
            }
            
            if let master = splitViewController.viewControllers[0] as? UINavigationController {
                master.pushViewController(secondViewController!, animated: true)
            }
            return true
        } else {
            return false
        }
    }
    
    func application(_ application: UIApplication, handleWatchKitExtensionRequest userInfo: [AnyHashable : Any]?, reply: @escaping ([AnyHashable : Any]?) -> Void) {
        
    }
}

// MARK: - NotificationCenter delegate

@available(iOS 10, *)
extension AppDelegate : UNUserNotificationCenterDelegate {
    
    // Receive displayed notifications for iOS 10 devices.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void)
    {
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void)
    {
        if pushType(response.notification.request.content.userInfo) == .invite {
            acceptInvite(response.notification.request.content.userInfo)
        }
        completionHandler()
    }
}

extension AppDelegate : MessagingDelegate {
    
    func messaging(_ messaging: Messaging, didRefreshRegistrationToken fcmToken: String) {
        print("============== fcmToken \(fcmToken)")
        Messaging.messaging().shouldEstablishDirectChannel = true
        UserDefaults.standard.set(fcmToken, forKey: "token")
        _ = AuthModel.shared.updatePerson(Auth.auth().currentUser)
    }    
}

// MARK: - WCSession delegate

extension AppDelegate : WCSessionDelegate {
    
    func sessionDidDeactivate(_ session: WCSession) {
        print("sessionDidDeactivate")
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("sessionDidBecomeInactive")
    }
    
    @available(iOS 9.3, *)
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("activationDidCompleteWith \(activationState)")
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("didReceiveMessage")
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        print("didReceiveApplicationContext \(applicationContext)")
    }
    
    // MARK: - iWatch messages
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        if let command = message["command"] as? String {
            if command == "status" {
                replyHandler(
                    ["isRunning" : !LocationManager.shared.isPaused,
                     "distance" : Model.shared.lastTrackDistance(),
                     "speed" : Model.shared.lastTrackSpeed()])
            } else if command == "start" {
                LocationManager.shared.startInBackground()
                replyHandler(["result": !LocationManager.shared.isPaused])
            } else if command == "stop" {
                LocationManager.shared.stop()
                replyHandler(["result": !LocationManager.shared.isPaused])
            }
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        print("sessionReachabilityDidChange")
    }
}
