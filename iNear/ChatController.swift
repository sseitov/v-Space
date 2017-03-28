//
//  ChatController.swift
//  iNear
//
//  Created by Сергей Сейтов on 01.12.16.
//  Copyright © 2016 Сергей Сейтов. All rights reserved.
//

import UIKit
import Firebase
import JSQMessagesViewController
import SVProgressHUD

class Avatar : NSObject, JSQMessageAvatarImageDataSource {
    
    var userImage:UIImage?
    
    init(_ user:User) {
        super.init()
        self.userImage = user.getImage().inCircle()
    }
    
    func avatarImage() -> UIImage! {
        return userImage
    }
    
    func avatarHighlightedImage() -> UIImage! {
        return userImage
    }
    
    func avatarPlaceholderImage() -> UIImage! {
        return UIImage(named: "logo")?.inCircle()
    }
}

class ChatController: JSQMessagesViewController, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    
    var user:User?
    var messages:[JSQMessage] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if user != nil {
            self.senderId = currentUser()!.uid!
            self.senderDisplayName = currentUser()!.shortName
            
            setupTitle(user!.shortName)
            
            collectionView!.collectionViewLayout.incomingAvatarViewSize = CGSize(width: 36, height: 36)
            collectionView!.collectionViewLayout.outgoingAvatarViewSize = CGSize(width: 36, height: 36)
            let cashedMessages = Model.shared.chatMessages(with: user!.uid!)
            for message in cashedMessages {
                if let jsqMessage = addMessage(message) {
                    if message.isNew {
                        Model.shared.readMessage(message)
                    }
                    messages.append(jsqMessage)
                }
                self.finishReceivingMessage()
            }
            
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(ChatController.newMessage(_:)),
                                                   name: newMessageNotification,
                                                   object: nil)
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(ChatController.deleteMessage(_:)),
                                                   name: deleteMessageNotification,
                                                   object: nil)
        } else {
            self.senderId = ""
            self.senderDisplayName = ""
            inputToolbar.isHidden = true
            navigationItem.rightBarButtonItem = nil
            setupTitle("Contact list is empty")
        }
        if IS_PAD() {
            navigationItem.leftBarButtonItem = nil
        } else {
            setupBackButton()
        }
    }
    
    func newMessage(_ notify:Notification) {
        if let message = notify.object as? Message {
            if let jsqMessage = addMessage(message) {
                messages.append(jsqMessage)
                self.finishReceivingMessage()
            }
        }
    }

    private func getMsg(sender:String, date:Date) -> JSQMessage? {
        for msg in messages {
            if msg.senderId == sender && msg.date.timeIntervalSince1970 == date.timeIntervalSince1970 {
                return msg
            }
        }
        return nil
    }
    
    func deleteMessage(_ notify:Notification) {
        if let message = notify.object as? Message {
            if let msg = getMsg(sender:message.from!, date:message.date as! Date) {
                if let index = messages.index(of: msg) {
                    self.collectionView.performBatchUpdates({
                        self.messages.remove(at: index)
                        self.collectionView.deleteItems(at: [IndexPath(row:index, section:0)])
                    }, completion: { _ in
                    })
                }
            }
        }
    }
    
    override func goBack() {
        _ = navigationController?.popViewController(animated: true)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        scrollToBottom(animated: true)
    }
    
    // MARK: - Send / receive messages
    
    private func addMessage(_ message:Message) -> JSQMessage? {
        if let user = Model.shared.getUser(message.from!) {
            Model.shared.readMessage(message)
            let name = user.shortName
            if message.imageData != nil {
                let photo = JSQPhotoMediaItem(image: UIImage(data: message.imageData as! Data))
                photo!.appliesMediaViewMaskAsOutgoing = (message.from! == currentUser()!.uid!)
                return JSQMessage(senderId: message.from!, senderDisplayName: name, date: message.date as! Date, media: photo)
            } else if message.track != nil {
                let track = TrackMediaItem(location: nil)
                track!.track = message.track
                track!.appliesMediaViewMaskAsOutgoing = (message.from! == currentUser()!.uid!)
                track!.setLocation(CLLocation(latitude: message.latitude, longitude: message.longitude), withCompletionHandler: {
                    self.collectionView.reloadData()
                })
                return JSQMessage(senderId: message.from!, senderDisplayName: name, date: message.date as! Date, media: track)
            } else if message.text != nil {
                return JSQMessage(senderId: message.from!, senderDisplayName: name, date: message.date as! Date, text: message.text!)
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
    
    override func didPressSend(_ button: UIButton!, withMessageText text: String!, senderId: String!, senderDisplayName: String!, date: Date!) {
        Model.shared.sendTextMessage(text, to: user!.uid!)
        JSQSystemSoundPlayer.jsq_playMessageSentSound()
        finishSendingMessage()
    }
    
    override func didPressAccessoryButton(_ sender: UIButton!) {
        UIApplication.shared.sendAction(#selector(UIApplication.resignFirstResponder), to: nil, from: nil, for: nil)
        let track = Model.shared.myTrackLastDay()
        
        let trackHandler:CompletionBlock? = (track == nil) ? nil : {
            Model.shared.sendTrackMessage(track!, to: self.user!.uid!)
        }

        let actionView = ActionSheet.create(
            title: "Choose Data",
            actions: (track == nil) ? ["Photo from Camera Roll", "Create photo use Camera"] :
                ["Photo from Camera Roll", "Create photo use Camera", "My track for last day"],
            handler1: {
                let imagePicker = UIImagePickerController()
                imagePicker.allowsEditing = false
                imagePicker.sourceType = .photoLibrary
                imagePicker.delegate = self
                imagePicker.modalPresentationStyle = .formSheet
                if let font = UIFont(name: "HelveticaNeue-CondensedBold", size: 15) {
                    imagePicker.navigationBar.titleTextAttributes = [NSForegroundColorAttributeName : UIColor.mainColor(), NSFontAttributeName : font]
                }
                imagePicker.navigationBar.tintColor = UIColor.mainColor()
                self.present(imagePicker, animated: true, completion: nil)
        }, handler2: {
            let imagePicker = UIImagePickerController()
            imagePicker.allowsEditing = false
            imagePicker.sourceType = .camera
            imagePicker.delegate = self
            self.present(imagePicker, animated: true, completion: nil)
        }, handler3: trackHandler)
        
        actionView?.show()
    }
    
    // MARK: - JSQMessagesCollectionView delegate
    
    lazy var outgoingBubbleImageView: JSQMessagesBubbleImage = self.setupOutgoingBubble()
    lazy var incomingBubbleImageView: JSQMessagesBubbleImage = self.setupIncomingBubble()
    
    private func setupOutgoingBubble() -> JSQMessagesBubbleImage {
        let bubbleImageFactory = JSQMessagesBubbleImageFactory()
        return bubbleImageFactory!.outgoingMessagesBubbleImage(with: UIColor.mainColor())
    }
    
    private func setupIncomingBubble() -> JSQMessagesBubbleImage {
        let bubbleImageFactory = JSQMessagesBubbleImageFactory()
        return bubbleImageFactory!.incomingMessagesBubbleImage(with: UIColor.jsq_messageBubbleLightGray())
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, attributedTextForCellBottomLabelAt indexPath: IndexPath!) -> NSAttributedString! {
        let message = messages[indexPath.item]
        return NSAttributedString(string: Model.shared.textDateFormatter.string(from: message.date))
    }
    
    override func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, heightForCellBottomLabelAt indexPath:IndexPath) -> CGFloat {
        return 20
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return messages.count
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageDataForItemAt indexPath: IndexPath!) -> JSQMessageData! {
        return messages[indexPath.item]
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, avatarImageDataForItemAt indexPath: IndexPath!) -> JSQMessageAvatarImageDataSource! {
        let message = messages[indexPath.item]
        if message.senderId == senderId {
            return Avatar(currentUser()!)
        } else {
            return Avatar(self.user!)
        }
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageBubbleImageDataForItemAt indexPath: IndexPath!) -> JSQMessageBubbleImageDataSource! {
        let message = messages[indexPath.item]
        if message.senderId == senderId {
            return outgoingBubbleImageView
        } else {
            return incomingBubbleImageView
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = super.collectionView(collectionView, cellForItemAt: indexPath) as! JSQMessagesCollectionViewCell
        let message = messages[indexPath.item]
        
        if message.senderId == senderId {
            cell.textView?.textColor = UIColor.white
        } else {
            cell.textView?.textColor = UIColor.black
        }
        return cell
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, didTapMessageBubbleAt indexPath: IndexPath!) {
        let message = messages[indexPath.item]
        if message.isMediaMessage || message.senderId == currentUser()!.uid! {
            let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            if (message.media as? JSQPhotoMediaItem) != nil {
                alert.addAction(UIAlertAction(title: "show photo", style: .default, handler: { _ in
                    self.performSegue(withIdentifier: "showPhoto", sender: message)
                }))
            }
            if (message.media as? TrackMediaItem) != nil {
                alert.addAction(UIAlertAction(title: "show track", style: .default, handler: { _ in
                    self.performSegue(withIdentifier: "showTrack", sender: message)
                }))
            }
            
            if message.senderId == currentUser()!.uid! {
                alert.addAction(UIAlertAction(title: "delete message", style: .destructive, handler: { _ in
                    if let msg = Model.shared.getMessage(from: currentUser()!, date: message.date) {
                        SVProgressHUD.show(withStatus: "Delete...")
                        Model.shared.deleteMessage(msg, completion: {
                            SVProgressHUD.dismiss()
                        })
                    }
                }))
            }
            alert.addAction(UIAlertAction(title: "cancel", style: .cancel, handler: nil))
            if IS_PAD() {
                alert.popoverPresentationController?.permittedArrowDirections = .any
                alert.popoverPresentationController?.sourceView = self.view
                var rc = collectionView.layoutAttributesForItem(at: indexPath)!.frame
                let sz = collectionView.collectionViewLayout.messageBubbleSizeForItem(at: indexPath)
                rc.origin.x = collectionView.frame.size.width - sz.width - collectionView.collectionViewLayout.outgoingAvatarViewSize.width
                rc.origin.y += 44
                rc.size.height = sz.height
                alert.popoverPresentationController?.sourceRect = rc
            }
            present(alert, animated: true, completion: nil)
        }
    }
    
    // MARK: - UIImagePickerController delegate
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        picker.dismiss(animated: true, completion: {
            if let pickedImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
                SVProgressHUD.show(withStatus: "Send...")
                Model.shared.sendImageMessage(pickedImage, to: self.user!.uid!, result: { error in
                    SVProgressHUD.dismiss()
                    if error != nil {
                        self.showMessage(error!.localizedDescription, messageType: .error)
                    } else {
                        JSQSystemSoundPlayer.jsq_playMessageSentSound()
                        self.finishSendingMessage()
                    }
                })
            }
        })
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Navigation
    
    @IBAction func showMap(_ sender: Any) {
        if user!.lastDate == 0 {
            self.showMessage("\(self.user!.shortName) does not published self location yet.", messageType: .information)
        } else {
            self.performSegue(withIdentifier: "showMap", sender: nil)
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showPhoto" {
            let message = sender as! JSQMessage
            let controller = segue.destination as! PhotoController
            controller.date = message.date
            let photo = message.media as! JSQPhotoMediaItem
            controller.image = photo.image
        } else if segue.identifier == "showMap" {
            let controller = segue.destination as! RouteController
            controller.user = self.user
        } else if segue.identifier == "showTrack" {
            let message = sender as! JSQMessage
            let controller = segue.destination as! TrackController
            if message.senderId != currentUser()!.uid! {
                controller.user = self.user
            }
            let track = message.media as! TrackMediaItem
            controller.track = track.track
        }

    }
}
