//
//  WebController.swift
//  v-Space
//
//  Created by Сергей Сейтов on 27.04.17.
//  Copyright © 2017 Сергей Сейтов. All rights reserved.
//

import UIKit
import SVProgressHUD

class WebController: UIViewController, UIWebViewDelegate {

    @IBOutlet weak var webView: UIWebView!
    var placeName:String = ""
    var placeWebSite:URL?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTitle(placeName)
        setupBackButton()
        
        webView.loadRequest(URLRequest(url: placeWebSite!))
    }

    override func goBack() {
        webView.delegate = nil
        SVProgressHUD.dismiss()
        super.goBack()
    }

    func webViewDidStartLoad(_ webView: UIWebView) {
        SVProgressHUD.show(withStatus: "Load...")
    }
    
    func webViewDidFinishLoad(_ webView: UIWebView) {
        SVProgressHUD.dismiss()
    }
    
    func webView(_ webView: UIWebView, didFailLoadWithError error: Error) {
        SVProgressHUD.dismiss()
        showMessage(error.localizedDescription, messageType: .error)
    }
}
