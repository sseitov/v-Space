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

class TrustListController: UITableViewController {

    @IBOutlet weak var myImage: UIImageView!
    @IBOutlet weak var myName: UILabel!
    @IBOutlet weak var myEmail: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupTitle(LOCALIZE("trustListTitle"))
        myName.text = Auth.auth().currentUser?.displayName
        myEmail.text = Auth.auth().currentUser?.email
        myImage.setupCircle()
        let guest = UIImage(named:"avatar")
        if let url = Auth.auth().currentUser?.photoURL {
            myImage.sd_setImage(with: url, placeholderImage: guest, options: [], completed: nil)
        } else {
            myImage.image = guest
        }
    }
    
    // MARK: - Table view data source

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
        // #warning Incomplete implementation, return the number of rows
        return 0
    }

    /*
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "reuseIdentifier", for: indexPath)

        // Configure the cell...

        return cell
    }
    */

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */
    
    @IBAction func close(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func signOut(_ sender: Any) {
        let ask = createQuestion(LOCALIZE(""), acceptTitle: "Ok", cancelTitle: "Cancel", acceptHandler: {
            GIDSignIn.sharedInstance().signOut()
            try? Auth.auth().signOut()
            self.dismiss(animated: true, completion: nil)
        })
        ask?.show()
    }
    
    @IBAction func addFriend(_ sender: Any) {
        let ask = TextInput.getEmail(cancelHandler: {}, acceptHandler: { email in
            
        })
        ask?.show()
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
