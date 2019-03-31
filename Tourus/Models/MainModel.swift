//
//  MainModel.swift
//  Tourus
//
//  Created by admin on 02/01/2019.
//  Copyright © 2019 Tourus. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import GooglePlaces

class MainModel {
    static let instance:MainModel = MainModel()
    
    var firebaseModel = FirebaseModel()
    var placesModel = PlacesModel()
    var sqlModel = SqlModel()
    
    init() {
        listenToOptionUpdates()
        listenToInteractionUpdates()
    }
   
    func signIn(_ email:String, _ password:String, _ callback:@escaping (Bool)->Void)
    {
        firebaseModel.signIn(email, password, callback)
    }
    
    func signUp(_ email:String, _ password:String, _ callback:@escaping (Bool)->Void)
    {
        firebaseModel.signUp(email, password,callback)
    }
    
    func signOut(_ callback:@escaping () -> Void) {
        firebaseModel.signOut(callback)
    }
    
    func getInteraction(_ category:String? = nil) -> Interaction? {
        var interaction = Interaction.get(database: self.sqlModel.database, category: category)
        if(interaction == nil) {
            interaction = Interaction.get(database: self.sqlModel.database)
        }
        
        return interaction ?? nil
    }
    
    private func listenToInteractionUpdates() {
        var lastUpdated = Interaction.getLastUpdateDate(database: sqlModel.database)
        lastUpdated += 1
        
        firebaseModel.getAllInteractionsFromDate(from:lastUpdated) { (data:[Interaction]) in
            self.sqlInteractionHandler(data: data) { (isUpdated:Bool) in
                if(isUpdated) {
                    //do something?
                }
            }
        }
    }
    
    private func listenToOptionUpdates() {
        firebaseModel.getAllOptionsFromDate(from:0) { (data:[Interaction.Option]) in
            self.sqlOptionsHandler(data: data) {
                //do something?
            }
        }
    }
    
    private func sqlInteractionHandler(data:[Interaction], callback: (Bool) -> Void) {
        var lastUpdated = Interaction.getLastUpdateDate(database: sqlModel.database)
        lastUpdated += 1
        var isUpdated = false
        
        for interaction in data {
            if(interaction.isDeleted == 1) {
                Interaction.delete(database: self.sqlModel.database, id: interaction.id)
            } else {
                Interaction.addNew(database: self.sqlModel.database, interaction: interaction)
            }
            
            if(interaction.lastUpdate > lastUpdated) {
                lastUpdated = interaction.lastUpdate
                isUpdated = true
            }
        }
        
        if(isUpdated) {
            Interaction.setLastUpdateDate(database: self.sqlModel.database, date: lastUpdated)
        }
        
        callback(isUpdated)
    }
    
    private func sqlOptionsHandler(data:[Interaction.Option], callback: () -> Void) {
        for option in data {
            Interaction.Option.addNew(database: self.sqlModel.database, option: option)
        }
        
        callback()
    }
    
    func getAdditionalOptionText(_ category:String) -> String {
        //return Interaction.Option.get(database: self.sqlModel.database, type: type.rawValue)?.text ?? type.defaultString
    return ""
    }
    
    func getUserInfo(_ uid:String, callback:@escaping (UserInfo?) -> Void) {
        firebaseModel.getUserInfo(uid) { (info:UserInfo?) in
            if(info != nil) {
                var lastUpdated = UserInfo.getLastUpdateDate(database: self.sqlModel.database)
                lastUpdated += 1;
                
                UserInfo.addNew(database: self.sqlModel.database, info: info!)
                
                if (info!.timestamp > lastUpdated) {
                    lastUpdated = info!.timestamp
                    UserInfo.setLastUpdateDate(database: self.sqlModel.database, date: lastUpdated)
                    self.getUserInfoFromLocalAndNotify(uid, callback)
                }
            }
        }
        
        getUserInfoFromLocalAndNotify(uid, callback)
    }
    
    private func getUserInfoFromLocalAndNotify(_ uid:String, _ callback:@escaping (UserInfo?) -> Void) {
        let info = UserInfo.get(database: self.sqlModel.database, userId: uid)
        if(info != nil) {
            callback(info)
            NotificationModel.userInfoNotification.notify(data: info!)
        }
    }
    
    func getImage(_ url:String, _ callback:@escaping (UIImage?)->Void){
        //1. try to get the image from local store
        let _url = URL(string: url)
        let localImageName = _url!.lastPathComponent
        if let image = self.getImageFromFile(name: localImageName){
            callback(image)
            print("got image from cache \(localImageName)")
        }else{
            //2. get the image from Firebase
            firebaseModel.getImage(url){(image:UIImage?) in
                if (image != nil){
                    //3. save the image localy
                    self.saveImageToFile(image: image!, name: localImageName)
                }
                //4. return the image to the user
                callback(image)
                print("got image from firebase \(localImageName)")
            }
        }
    }
    
    func getPlaseImage(_ placeId:String, _ maxwidth:Int, _ callback:@escaping (UIImage?)->Void) {
        placesModel.fetchGoogleNearbyPlacesPhoto(placeId, maxwidth, callback)
    }
    
    func saveImageToFile(image:UIImage, name:String){
        if let data = image.jpegData(compressionQuality: 0.8) {
            let filename = getDocumentsDirectory().appendingPathComponent(name)
            try? data.write(to: filename)
        }
    }
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in:
            .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory
    }
    
    func getImageFromFile(name:String)->UIImage?{
        let filename = getDocumentsDirectory().appendingPathComponent(name)
        return UIImage(contentsOfFile:filename.path)
    }
    
    func currentUser() -> User? {
        return firebaseModel.currentUser()
    }
    
    private func downloadImageData(from url: URL, completion: @escaping (Data?, URLResponse?, Error?) -> ()) {
        URLSession.shared.dataTask(with: url, completionHandler: completion).resume()
    }
    
    func getImage(_ url: URL, _ alpha:CGFloat, _ callback: @escaping (UIImage?) -> Void) {
        print("Download Started")
        downloadImageData(from: url) { data, response, error in
            guard let data = data, error == nil else { return }
            print(response?.suggestedFilename ?? url.lastPathComponent)
            print("Download Finished")
            DispatchQueue.main.async() {
                var image = UIImage(data: data)
                if(image != nil) {
                    image = image!.alpha(alpha)
                }
                callback(image)
            }
        }
    }
    
    func fetchNearbyPlaces(location: String, radius: Int, callback: @escaping ([Place]?, String?) -> Void){
        placesModel.fetchGoogleNearbyPlaces(key: "AIzaSyChHqn4cqme0MTgu6QRmaJHppcGs_NbeIc",location: location ,radius: radius, callback: callback);
    }
}
