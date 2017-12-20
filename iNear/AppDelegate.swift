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
import FBSDKLoginKit
import AWSCognito
import AWSSNS
import PushKit

func IS_PAD() -> Bool {
    return UIDevice.current.userInterfaceIdiom == .pad
}

func MainApp() -> AppDelegate {
    return UIApplication.shared.delegate as! AppDelegate
}

func ShowCall(userName:String?, userID:String?, callID:String?) {
    let call = UIStoryboard(name: "Call", bundle: nil)
    if let nav = call.instantiateViewController(withIdentifier: "Call") as? UINavigationController {
        nav.modalTransitionStyle = .flipHorizontal
        if let top = MainApp().window?.topMostWindowController {
            if let callController = nav.topViewController as? CallController {
                callController.userName = userName
                callController.callID = callID
                callController.userID = userID
            }
            top.present(nav, animated: true, completion: nil)

        }
    }
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate {

    var window: UIWindow?
    var watchSession:WCSession?
    var voipRegistry:PKPushRegistry?
    var providerDelegate: ProviderDelegate!
    let callManager = CallManager()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

        // Use Firebase library to configure APIs
        FirebaseApp.configure()

        // Register_for_notifications
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { (granted, error) in
            
            guard error == nil else {
                print("============ Display Error.. Handle Error.. etc..")
                return
            }
            
            if granted {
                DispatchQueue.main.async {                    
                    //register for voip notifications
                    self.voipRegistry = PKPushRegistry(queue: DispatchQueue.main)
                    self.voipRegistry?.desiredPushTypes = Set([.voIP])
                    self.voipRegistry?.delegate = self;

                    //Register for RemoteNotifications. Your Remote Notifications can display alerts now :)
                    application.registerForRemoteNotifications()
                }
            }
            else {
                print("======== user denying permissions..")
            }
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
        
        if currentUid() != nil {
            AuthModel.shared.startObservers()
        }

        // Initialize the Amazon Cognito credentials provider
        let credentialsProvider = AWSCognitoCredentialsProvider(regionType:.USEast1,
                                                                identityPoolId:identityPoolID)
        let configuration = AWSServiceConfiguration(region:.USEast1, credentialsProvider:credentialsProvider)
        AWSServiceManager.default().defaultServiceConfiguration = configuration
        
        providerDelegate = ProviderDelegate(callManager: callManager)

        return true
    }
    
    func closeCall() {
        providerDelegate.closeIncomingCall()
    }

    // MARK: - Application delegate
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        if url.scheme! == "iNearby" {
            return true
        } else if url.scheme! == FACEBOOK_SCHEME {
            return FBSDKApplicationDelegate.sharedInstance().application(app, open: url, options: options)
        } else {
            return GIDSignIn.sharedInstance().handle(url,
                                                     sourceApplication: options[.sourceApplication] as! String!,
                                                     annotation: options[.annotation])
        }
    }
    
    private func acceptInvite(_ userInfo: [AnyHashable: Any]) {
        if let requester = userInfo["requester"] as? String,
            let aps = userInfo["aps"] as? [String:Any],
            let alert = aps["alert"] as? [String:Any],
            let body = alert["body"] as? String
        {
            LocationManager.shared.getCurrentLocation({location in
                let ask = self.window?.topMostWindowController?.createQuestion(body,
                                                                               acceptTitle: "Accept",
                                                                               cancelTitle: "Reject",
                                                                               acceptHandler:
                    {
                        if currentUid() != nil {
                            let update = ["latitude" : location.coordinate.latitude,
                                          "longitude" : location.coordinate.longitude,
                                          "date" : Date().timeIntervalSince1970]
                            let ref = Database.database().reference()
                            ref.child("locations").child(currentUid()!).setValue(update)
                            
                            let update2 = [currentUid()!, requester]
                            ref.child("friends").childByAutoId().setValue(update2)
                        }
                })
                ask?.show()
            })
        }
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if application.applicationState == .active {
            acceptInvite(userInfo)
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
        acceptInvite(response.notification.request.content.userInfo)
        completionHandler()
    }
}

extension AppDelegate : MessagingDelegate {
    
    func messaging(_ messaging: Messaging, didRefreshRegistrationToken fcmToken: String) {
        print("============== fcmToken \(fcmToken)")
        Messaging.messaging().shouldEstablishDirectChannel = true
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

extension AppDelegate : PKPushRegistryDelegate {
    
    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        print("Token invalidated")
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        let sns = AWSSNS.default()
        let endpointRequest = AWSSNSCreatePlatformEndpointInput()
        #if DEBUG
            endpointRequest?.platformApplicationArn = endpointDev
        #else
            endpointRequest?.platformApplicationArn = endpointProd
        #endif
        
        endpointRequest?.token = pushCredentials.token.hexadecimalString
        sns.createPlatformEndpoint(endpointRequest!).continueWith(executor: AWSExecutor.mainThread(), block: { task in
            if let response = task.result, let endpoint = response.endpointArn {
                UserDefaults.standard.set(endpoint, forKey: "endpoint")
                if currentUid() != nil {
                    AuthModel.shared.publishEndpoint(endpoint)
                }
            }
            return nil
        })
    }
    
    private func processPayload(_ payload: PKPushPayload, complete: @escaping () -> Void) {
        if let payloadDict = payload.dictionaryPayload["aps"] as? Dictionary<String, String>,
            let message = payloadDict["alert"]
        {
            if message == "askLocaton" {
                LocationManager.shared.getCurrentLocation({ location in
                    if currentUid() != nil {
                        let update = ["latitude" : location.coordinate.latitude,
                                      "longitude" : location.coordinate.longitude,
                                      "date" : Date().timeIntervalSince1970]
                        let ref = Database.database().reference()
                        ref.child("locations").child(currentUid()!).setValue(update, withCompletionBlock: { _, _ in
                            complete()
                        })
                    } else {
                        complete()
                    }
                })
            } else if message == "hangup" {
                if UIApplication.shared.applicationState == .active {
                    NotificationCenter.default.post(name: hangUpCallNotification, object: nil)
                } else {
                    self.providerDelegate.closeIncomingCall()
                }
                complete()
            } else if message == "accept" {
                if UIApplication.shared.applicationState == .active {
                    NotificationCenter.default.post(name: acceptCallNotification, object: nil)
                }
                complete()
            } else {
                if let data = message.data(using: .utf8), let request = try? JSONSerialization.jsonObject(with: data, options: []), let requestData = request as? [String:Any]
                {
                    if let userName = requestData["userName"] as? String,
                        let userID = requestData["userID"] as? String,
                        let callID = requestData["callID"] as? String
                    {
                        if UIApplication.shared.applicationState == .active {
                            MainApp().window?.topMostWindowController?.yesNoQuestion("\(userName) call you.", acceptLabel: "Accept", cancelLabel: "Reject", acceptHandler:
                                {
                                    SVProgressHUD.show()
                                    PushManager.shared.pushCommand(userID, command:"accept", success: { result in
                                        SVProgressHUD.dismiss()
                                        if !result {
                                            MainApp().window?.topMostWindowController?.showMessage("requestError".localized, messageType: .error)
                                        } else {
                                            ShowCall(userName: userName, userID: userID, callID: callID)
                                        }
                                    })
                                    
                            }, cancelHandler: {
                                PushManager.shared.pushCommand(userID, command: "hangup", success: { _ in })
                            })
                            complete()
                        } else {
                            self.providerDelegate.reportIncomingCall(callID: callID,
                                                                     userName: userName,
                                                                     userID: userID, completion:
                                { error in
                                    if error != nil {
                                        print(error!.localizedDescription)
                                    }
                                    complete()
                            })
                        }
                    } else {
                        complete()
                    }
                } else {
                    complete()
                }
            }
        } else {
            complete()
        }
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType) {
        processPayload(payload, complete: {
        })
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void)
    {
        processPayload(payload, complete: {
            completion()
        })
    }
}
