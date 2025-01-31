//
//  FirebaseModel.swift
//  Tourus
//
//  Created by admin on 02/01/2019.
//  Copyright © 2019 Tourus. All rights reserved.
//

import Foundation
import Firebase
import FirebaseDatabase
import UIKit
import CoreLocation

class FirebaseModel {
    var databaseRef: DatabaseReference!
    let firestoreRef:Firestore!
    lazy var storageRef = Storage.storage().reference(forURL:
        "gs://org-tourus-acb4d.appspot.com")
    
    init() {
        FirebaseApp.configure()
        databaseRef = Database.database().reference()
        firestoreRef = Firestore.firestore()
        
//        getAllInteractions(callback: {(int) in
//            print(int)
//        })
    }
    
    
    func getAllInteractionsFromDate(from:Double, callback:@escaping ([Interaction])->Void) {
        let stRef = databaseRef.child(consts.names.interactionsTableName)
        let fbQuery = stRef.queryOrdered(byChild: "lastUpdate").queryStarting(atValue: from)
        fbQuery.observe(.value) { (snapshot) in
            
            var data = [Interaction]()
            
            if let value = snapshot.value as? [String : Any] {
                for (id, json) in value {
                    data.append(Interaction(_id: id, json: json as! [String : Any]))
                }
            }
            
            callback(data)
        }
    }
    
    func getAllInteractions(callback:@escaping ([Interaction])->Void) {
        let stRef = databaseRef.child(consts.names.interactionsTableName)
        stRef.observeSingleEvent(of: .value) { (snapshot) in
            
            var data = [Interaction]()
            
            if let value = snapshot.value as? [String : Any] {
                for (id, json) in value {
                    data.append(Interaction(_id: id, json: json as! [String : Any]))
                }
            }
            
            callback(data)
        }
    }
    
    func getAllOptionsFromDate(from:Double, callback:@escaping ([Interaction.Option])->Void) {
        let stRef = databaseRef.child(consts.names.optionsTableName)
        let fbQuery = stRef.queryOrdered(byChild: "lastUpdate").queryStarting(atValue: from)
        fbQuery.observe(.value) { (snapshot) in
            
            var data = [Interaction.Option]()
            
            if let value = snapshot.value as? [String : Any] {
                for (type, json) in value {
                    if let inner_value = json as? [String : Any] {
                        for (key, text) in inner_value {
                            if text is String {
                                data.append(Interaction.Option(_id: key, type, text as! String))
                            }
                        }
                    }
                }
            }
            
            callback(data)
        }
    }
    
    //MARK:- UserFunctons
    
    func addUserInfo(_ userInfo:UserInfo, _ image:UIImage?, _ completionBlock:@escaping (Bool) -> Void = {_  in}) {
        if image != nil {
            saveImage(folderName: consts.names.profileImagesFolderName, image: image!) { (url:String?) in
                if url != nil {
                    userInfo.profileImageUrl = url!
                }
                self.databaseRef!.child(consts.names.userInfoTableName).child(userInfo.uid).setValue(userInfo.toJson())
                completionBlock(true)
            }
        }
        else {
            self.databaseRef!.child(consts.names.userInfoTableName).child(userInfo.uid).setValue(userInfo.toJson())
            completionBlock(true)
        }
    }
    
    func saveImage(folderName:String, image:UIImage, callback:@escaping (String?) -> Void) {
        let data = image.jpegData(compressionQuality: 0.8)
        let imageName = "\(Date().timeIntervalSince1970).jpg"
        let imageRef = storageRef.child(folderName).child(imageName)
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        imageRef.putData(data!, metadata: metadata) { (metadata, error) in
            imageRef.downloadURL { (url, error) in
                guard let downloadURL = url else {
                    // Uh-oh, an error occurred!
                    return
                }
                print("url: \(downloadURL)")
                callback(downloadURL.absoluteString)
            }
        }
    }
    
    func getImage(_ url:String, _ callback:@escaping (UIImage?) -> Void) {
        let ref = Storage.storage().reference(forURL: url)
        ref.getData(maxSize: 10 * 1024 * 1024) { data, error in
            if error != nil {
                callback(nil)
            } else {
                let image = UIImage(data: data!)
                callback(image)
            }
        }
    }
    
    func getUserInfo(_ uid:String, callback:@escaping (UserInfo?) -> Void) {
        self.databaseRef!.child(consts.names.userInfoTableName).child(uid).observeSingleEvent(of: .value, with: {
            (snapshot) in
            
            if snapshot.exists() {
                let value = snapshot.value as! [String:Any]
                let userInfo = UserInfo(_uid: uid, json: value)
                
                callback(userInfo)
            }
            else {
                callback(nil)
            }
        })
    }
    
    func updateUserInfo(_ userId:String, _ preImageUrl:String?, _ image:UIImage?, _ completionBlock:@escaping (Bool) -> Void = {_  in}) {
        if image != nil {
            let folder = consts.names.profileImagesFolderName
            saveImage(folderName: folder, image: image!) { (url:String?) in
                if url != nil {
                    if (preImageUrl != nil && preImageUrl != "") {
                        self.deleteImage(preImageUrl!)
                    }
                    let userInfo = consts.names.userInfoTableName
                    self.databaseRef!.child(userInfo).child(userId).child("profileImageUrl").setValue(url)
                    //saving the new userinfo details and saving the image locally
                    MainModel.instance.getUserInfo(userId) { userInfo in
                        MainModel.instance.getImage(url!) { image in completionBlock(true) }
                    }
                } else {
                    completionBlock(false)
                }
            }
        }
        else {
            completionBlock(false)
        }
    }
    
    func deleteImage(_ imageUrl:String) {
        let desertRef = Storage.storage().reference(forURL: imageUrl)
        
        desertRef.delete { error in
            if error != nil {
                print("error while trying to delete an image")
            } else {
                print("image deleted")
            }
        }
    }
    
    func signUp(_ email:String, _ password:String, _ callback:@escaping (Bool) -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { (authResult, error) in
            if authResult?.user != nil {
                
                let email = authResult!.user.email!
                let display = (email.components(separatedBy: "@"))[0]
                
                let userInfo = UserInfo(_uid: authResult!.user.uid, _displayName: display, _email: email, _profileImageUrl: nil)
                self.addUserInfo(userInfo, nil, { (val) in
                    callback(true)
                })
            }
            else {
                callback(false)
            }
        }
    }
    
    func signIn(_ email:String, _ password:String, _ callback:@escaping (Bool) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { (user, error) in
            if (user != nil  ) {
                callback(true)
            }
            else {
                callback(false)
            }
        }
    }
    
    func signOut(_ callback:@escaping () -> Void) {
        do {
            try Auth.auth().signOut()
            callback()
        } catch {
            print("Error while signing out!")
        }
    }
    
    func refreshUserToken(_ callback: @escaping (User?, String?) -> Void) {
        let currentuser = Auth.auth().currentUser

        if currentuser == nil {
            callback(nil, nil)
            return
        }
        
        currentuser?.getIDTokenForcingRefresh(true) { idToken, error in
            if let error = error {
                self.signOut() { callback(nil, error.localizedDescription) }
            }
            else {
                callback(currentuser, nil)
            }
        }
    }
    
    func currentUser() -> User? {
        return Auth.auth().currentUser
    }
    
    func getAllUsersHistory(_ callback: @escaping ([[String : Double]]) -> Void){
        // Get other users history- all users history besides the current user
        let user = currentUser()
        let uid = user?.uid
        
        if (user != nil && uid != nil) {
            self.databaseRef!.child("History").observeSingleEvent(of: .value) { (snapshot) in
                
                var history = [[String : Double]]()
                
                if snapshot.exists() {
                    if let value = snapshot.value as? [String : [String:Double]]{
                        for otherUsersHistory in value{
                            if(otherUsersHistory.key != uid){
                                history.append(otherUsersHistory.value)
                            }
                        }
                    }
                }
                callback(history)
            }
        }
        else {
            callback([[String : Double]]())
        }
    }
    
    func getCurrentUserHistory(_ callback:@escaping ([String : Double]?) -> Void) {
        let user = currentUser()
        let uid = user?.uid
        
        if(user != nil){
            self.databaseRef!.child("History").child(uid!).observeSingleEvent(of: .value) { (snapshot) in
                if snapshot.exists() {
                    if let value = snapshot.value as? [String : Double]{
                        callback(value)
                    }
                }
                else {
                    callback(nil)
                }
            }
        }
    }
    
    func updateUserHistory(_ categories:[String] ,_ addedvalue:Double) {
        let user = currentUser()
        let uid = user?.uid
        
        if(uid != nil) {
            
            for category in categories{
                let db = self.databaseRef!.child("History").child(uid!).child(category)
                
                db.observeSingleEvent(of: .value, with: { (snapshot) in
                    
                    if snapshot.exists() {
                        
                        if let value = snapshot.value as? Double {
                            db.setValue(value + addedvalue)
                        }
                    }
                    else{
                        db.setValue(addedvalue)
                    }
                })
            }
        }
    }
    
    func addStoryToInteractions(interacton:InteractionStory) {
        firestoreRef.collection(consts.names.interactionHistoryTableName).addDocument(data: interacton.toJson()) { err in
            if let err = err {
                print("Error adding document: \(err)")
            }
        }
    }
    
    func getInteractionsStories(_ currUserLocation:CLLocation , _ callback: @escaping ([InteractionStory]) -> Void){
        //_ callback: @escaping ([InteractionStory]) -> Void
        firestoreRef.collection(consts.names.interactionHistoryTableName).getDocuments() { (querySnapshot, err) in
            if let err = err {
                print("Error getting documents: \(err)")
            } else {
                var stories = [InteractionStory]()
                
                for document in querySnapshot!.documents {
                    let interaction = InteractionStory(json: document.data())
                    interaction.getDistanceInMeters(currUserLocation)
                    stories.append(interaction)
                }
                
                callback(stories)
            }
        }
    }
    
    func getUserInteractionStories(_ callback: @escaping ([InteractionStory]) -> Void) {
    
        let time24hoursBeforeNow = Date().timeIntervalSince1970 - (24 * 60 * 60)
        let date = Date(timeIntervalSince1970: time24hoursBeforeNow)
        let userId = currentUser()?.uid ?? nil
        
        if userId != nil {
            firestoreRef.collection(consts.names.interactionHistoryTableName).whereField("userID", isEqualTo: userId!).whereField("date", isGreaterThanOrEqualTo: date).whereField("answer", isEqualTo: OptionType.accept.index).order(by: "date", descending: true).getDocuments() { (querySnapshot, err) in
                if let err = err {
                    print("Error getting documents: \(err)")
                } else {
                    var stories = [InteractionStory]()
                    
                    for document in querySnapshot!.documents {
                        let interaction = InteractionStory(json: document.data())
                        //interaction.getDistanceInMeters(currUserLocation)
                        stories.append(interaction)
                    }
                    
                    callback(stories)
                }
            }
        }
    }
    
    func updateUserPreferences(_ categories:[String]) {
        let user = currentUser()
        let uid = user?.uid
        
        if(uid != nil) {
            
            var json = Dictionary<String, Double>()
            categories.forEach() { category in
                json[category] = 0
            }
        
           self.databaseRef!.child("Preferences").child(uid!).setValue(json)
        }
    }
    
    func getCurrentUserPreferences(_ callback:@escaping ([String]) -> Void) {
        let user = currentUser()
        let uid = user?.uid
        var categories = [String]()
        
        if(uid != nil){
            self.databaseRef!.child("Preferences").child(uid!).observeSingleEvent(of: .value) { (snapshot) in
                if snapshot.exists() {
    
                    if let value = snapshot.value as? Dictionary<String, Double> {
                        for snap in value {
                            let category = snap.key
                            categories.append(category)
                        }
                    }
                }
                callback(categories)
            }
        }
    }
}
