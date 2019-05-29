//
//  AlgorithmModel.swift
//  Tourus
//
//  Created by aliceka on 23/03/2019.
//  Copyright © 2019 Tourus. All rights reserved.
//


import Foundation
import UIKit
import CoreLocation

class AlgorithmModel{
    private let minSupport = 0
    
    private let otherUsersHistoryData:[[String]] = [[String]()] //update every 30min time
    
    private var candidateSet:[String] = []
    
    private var refusingHistory: [String] = []
    
    private func updateHistoryData(){
        //30min time
    }
    
    var interactionsByUser = [String:[InteractionStory]]()
    var lastUpdatedInteractionsDate:Date?
    var lastUpdatedPlace:CLLocation?
    
    // KNN weights constants
    private let distDeltaWeight = 1.0
    private let timeDeltaWeight = 1.0
    private let dayInWeekWeight = 1.0
    private let monthDeltaWeight = 1.0
    private let positiveCtgryWeight = 1.0
    private let negativeCtgryWeight = -1.0
    
    init() {
        candidateSet = []
        updateHistoryData()
    }
    
    private func updateCandidateSet(_ complition: @escaping ([String]?) -> Void){
        MainModel.instance.getCurrentUserHistory { [weak self] (currUserHistory) in
            if currUserHistory == nil{
                complition(nil)
            }
            else{
                self?.candidateSet = []
                
                for (type, rating) in currUserHistory!{
                    
                    if (Int(rating) > self!.minSupport){
                        self?.candidateSet.append(type)
                    }
                }
                
                complition(self?.candidateSet)
            }
        }
    }
    
    func distanceGradeCalculator(distanceInMeters: Int, topGrade: Int, interestingKilometers: Double) -> Double{
        return (Double(topGrade) - ((Double(distanceInMeters)/(interestingKilometers * 1000)) * Double(topGrade)))
    }
    
    func timeGradeCalculator(candidatesDate: Date, topGrade: Int, interestingHourInterval: Int) -> Double{
        let candidateHour = Calendar.current.component(.hour, from: candidatesDate)
        let currHour = Calendar.current.component(.hour, from: Date())
        
        return(Double(topGrade) - (Double(abs(candidateHour - currHour))/Double(interestingHourInterval)) * Double(topGrade))
    }
    
    func dayInWeekGradeCalculator(candidatesDate: Date, topGrade: Int, interestingDaysInterval: Int) -> Double{
        let candidateDay = Calendar.current.component(.weekday, from: candidatesDate)
        let currDay = Calendar.current.component(.weekday, from: Date())
        let dayDelta = abs(currDay - candidateDay)
        
        return(Double(topGrade) - (Double(dayDelta)/Double(interestingDaysInterval)) * Double(topGrade))
    }
    
    func monthGradeCalculator(candidatesDate: Date, topGrade: Int, interestingMonthsInterval: Int) -> Double{
        let candidateMonth = Calendar.current.component(.month, from: candidatesDate)
        let currMonth = Calendar.current.component(.month, from: Date())
        var monthDelta = abs(currMonth - candidateMonth)
        
        if (monthDelta > 6){
            monthDelta = 12 - monthDelta
        }
        
        return(Double(topGrade) - (Double(monthDelta)/Double(interestingMonthsInterval)) * Double(topGrade))
    }
    
    func knnAlgorithm(_ usersStory: [String:[InteractionStory]],_ places: [Place], _ callback: @escaping ([String:Double]) -> Void){
        var categoriesGrades = [String:Double]()
        
        for userData in usersStory{
            for userStory in userData.value{
                for category in userStory.categories{
                    let currAnswerWeight = userStory.answer == 1 ? positiveCtgryWeight : negativeCtgryWeight
                    let currDataGrade = (distanceGradeCalculator(distanceInMeters: userStory.distanceBetweenUsers ?? 5000,
                                                                topGrade: 10, interestingKilometers: 5) * distDeltaWeight +
                                         timeGradeCalculator(candidatesDate: userStory.date, topGrade: 10, interestingHourInterval: 6) * timeDeltaWeight +
                                         dayInWeekGradeCalculator(candidatesDate: userStory.date, topGrade: 10, interestingDaysInterval: 6) * dayInWeekWeight +
                                         monthGradeCalculator(candidatesDate: userStory.date, topGrade: 10, interestingMonthsInterval: 6) * monthDeltaWeight) * currAnswerWeight
                    
                    if (categoriesGrades.keys.contains(category)){
                        categoriesGrades[category]! += currDataGrade
                    }
                    else{
                        categoriesGrades.updateValue(currDataGrade, forKey: category)
                    }
                }
            }
        }
        
        callback(categoriesGrades)
    }
    
    func getAlgorithmNextPlace(_ location:CLLocation, _ callback: @escaping (Interaction) -> Void) {
        MainModel.instance.fetchNearbyPlaces(location: location, callback: { (places, err)  in
            if ((places == nil) || (places?.count == 0)){
                DispatchQueue.main.async {
                    let alert = UIAlertController(title: "Lonley:'(", message: "Couldn't fetch any place around you...", preferredStyle: UIAlertController.Style.alert)
                    alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertAction.Style.default, handler: nil))
                    
                    UIApplication.topViewController()?.present(alert, animated: true, completion: nil)
                }
            }
            else{
                self.algorithmOrchestra(location, places!) { place in
                    MainModel.instance.getInteraction(place.types) { intereaction in
                        
                        intereaction!.place = place
                        
                        DispatchQueue.main.async {
                            callback(intereaction!)
                        }
                    }
                }
            }
        })
    }
    
    func algorithmOrchestra(_ currUserLocation:CLLocation, _ places: [Place], _ callback: (Place) -> Void){
        let group = DispatchGroup()

        group.enter()
        updateCandidateSet { [weak self] (candidateSet) -> Void in
            if candidateSet != nil{
                self?.candidateSet = candidateSet!
            }
            group.leave()
        }
        
        group.wait()
        
        if candidateSet == []{
            callback(places.randomElement()!)
        }
        else{
            if let aprioriResults = choosePlace(places){
                let validPlaces = getValidPlacesByTypes(places, types: aprioriResults)

                if validPlaces.count > 0{
                    callback(validPlaces.randomElement()!)
                }
                else {
                    callback(places.randomElement()!)
                }
            }
            else{
                callback(places.randomElement()!)
            }
            
//            GetCategoryByKnn(currUserLocation, places, {(categoryList) in
//
//            })
        }
    }
    
    func GetCategoryByKnn(_ currUserLocation:CLLocation, _ places: [Place], _ callback: @escaping ([String:Double]) -> Void){
        let currDate  = Date()
        let interval :Double =  (currDate.timeIntervalSince(lastUpdatedInteractionsDate ?? Date(timeIntervalSince1970: 0)) / 3600)
        let distance : Int
        
        if let loc = lastUpdatedPlace{
            distance = Int(loc.distance(from: currUserLocation))
        }else{
            distance = 5000
        }
        
        if (interval >= 1 || distance > 500){
            MainModel.instance.getInteractionsStories(currUserLocation, {(interactions:[InteractionStory]) in
                self.lastUpdatedPlace = currUserLocation
                self.lastUpdatedInteractionsDate = Date()
                self.interactionsByUser = self.GroupInteractionsByUser(interactions)
                self.knnAlgorithm(self.interactionsByUser, places, callback)
            })
        }else{
            self.knnAlgorithm(self.interactionsByUser, places, callback)
        }
    }
    
    private func getValidPlacesByTypes(_ places: [Place],types: [String]) -> [Place]{
        var validPlaces = [Place]()
        
        for place in places{
            for type in place.types!{
                if types.contains(type){
                    validPlaces.append(place)
                    
                    break
                }
            }
        }
        
        return validPlaces
    }
    
    private func loadFreqSet(_ availableUsersCategories:[[String]]) -> [String:Int] {
        var counter:Int = 0
        var frequencyTable:[String:Int] = [:]
        
        for i in 0..<candidateSet.count {
            counter = 0
            for j in 0..<availableUsersCategories.count {
                for q in 0..<availableUsersCategories[j].count {
                    if candidateSet[i] == availableUsersCategories[j][q] {
                        counter += 1
                    }
                }
            }
            
            frequencyTable[candidateSet[i]] = counter
            
        }
        
        return frequencyTable
    }
    
    //loadFreqSet()
    
    private func combineArray<T:Equatable>(data:[T]) -> [[T]] {
        var c:[[T]] = []
        
        for i in 0..<data.count {
            for j in i+1..<data.count {
                if data[i] != data[j] {
                    c.append([data[i],data[j]])
                }
            }
        }
        return c
    }
    
    private func getValidTypes(_ places:[Place]) -> [String]{
        var validTypes = [String]()
        
        for place in places{
            if place.types != nil{
                for type in place.types!{
                    if (!validTypes.contains(type)){
                        validTypes.append(type)
                    }
                }
            }
        }

        return validTypes
    }
    
    private func getRelevantHistory(_ places:[Place]) ->  [[String]] {
        var data:[[String]] = [[String]]()
        let validTypes = getValidTypes(places)
        let group = DispatchGroup()

        group.enter()
        MainModel.instance.getAllUsersHistory { [weak self] (preferenceDict) in
            for i in 0..<preferenceDict.count{
                var newUserPref = [String]()
                
                for (type, rating) in preferenceDict[i]{
                    if((self!.minSupport < Int(rating)) && validTypes.contains(type)){
                        newUserPref.append(type)
                    }
                }
                
                if (newUserPref != []){
                    data.append(newUserPref)
                }
            }
            
            group.leave()
        }
        
        group.wait()
        return data
    }
    
    //Algo
    func choosePlace(_ places: [Place]) -> [String]? {
        var data:[[String]] = [[String]]()
        var frequencyTable:[String:Int] = [:]
        
        //initialize data by places array from Baruch
        data = getRelevantHistory(places)
        
        //Initialize FreqSet
        frequencyTable = loadFreqSet(data)
        
        
        var newFreqTable:[String:Int] = frequencyTable
        
        for (key,value) in newFreqTable {
            if value < minSupport {
                newFreqTable.removeValue(forKey: key)
            }
        }
        
        let fqTable:[String] = Array(newFreqTable.keys)
        var genereteTable = [[String]](repeating: [], count: newFreqTable.count)
        genereteTable = combineArray(data: fqTable)
        var lastFreqCounts:[Int] = [Int](repeating: 0, count: genereteTable.count)
        print(genereteTable)
        
        for i in 0..<data.count {
            for w in 0..<genereteTable.count {
                for r in 0..<genereteTable[w].count - 1 {
                    if data[i].contains(genereteTable[w][r]) && data[i].contains(genereteTable[w][r + 1])  {
                        print("\(i) -> \(genereteTable[w][r]),\(genereteTable[w][r + 1])")
                        lastFreqCounts[w] += 1
                    }
                }
            }
        }
        print(lastFreqCounts)
        
        if lastFreqCounts.count == 0{
            return nil
        }
        
        return genereteTable[lastFreqCounts.index(of: lastFreqCounts.max()!)!]
    }
    
    
    
    func GroupInteractionsByUser(_ interactions:[InteractionStory]) ->[String:[InteractionStory]] {
        
        var interactionsByUser = [String:[InteractionStory]]()
            
        if interactions.count > 0 {
            for story in interactions {
                if interactionsByUser[story.userID] == nil {
                    interactionsByUser[story.userID] = [InteractionStory]()
                }
                    
                interactionsByUser[story.userID]?.append(story)
            }
        }
        
        return(interactionsByUser)
    }
    
}





