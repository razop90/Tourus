//
//  MainViewController.swift
//  Tourus
//
//  Created by admin on 03/01/2019.
//  Copyright © 2019 Tourus. All rights reserved.
//
import UIKit
import CoreLocation

class MainViewController: UIViewController, CLLocationManagerDelegate {
    
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var graphView: GraphView!
    
    // MARK:Local const props
    let optionButtonMinHeight = 20
    let optionButtonSpace = 10
    let minimumBottomConstraint:CGFloat = -30
    let defaultInfoImage:UIImage? = UIImage(named: "no_image") ?? nil
    let backgroundImage:UIImageView = UIImageView(frame: UIScreen.main.bounds)
    let locationManager = CLLocationManager()
    
    // MARK:Outlets
    @IBOutlet var settingsBtn: UIButton!
    @IBOutlet var navigationBtn: UIButton!
    @IBOutlet var mainView: UIView!
    @IBOutlet var interactionLabel: UILabel!
    @IBOutlet var interactionView: UIView!
    @IBOutlet var verticalStackView: UIStackView!
    @IBOutlet var optionsStackHeightConstraint: NSLayoutConstraint!
    @IBOutlet var optionsView: UIView!
    @IBOutlet var moreInfoView: UIView!
    @IBOutlet var inquiryImage: UIImageView!
    @IBOutlet var moreInfoImage: UIImageView!
    @IBOutlet var moreInfoButtonView: UIView!
    
    // MARK:Outlets - Constraints
    @IBOutlet var interactionSettingsConstraint: NSLayoutConstraint!
    @IBOutlet var settingsInteractionConstraint: NSLayoutConstraint!
    @IBOutlet var optionsBottomConstraint: NSLayoutConstraint!
    
    var interaction:Interaction? = nil
    var currUserLocation:CLLocation? = nil
    var imageIndex:Int = 0
    var photos:[UIImage] = [UIImage]()
    var lastLoadedIndex = 1;
    
    override func viewDidLoad() {
        super.viewDidLoad()

        BuisyIndicator.Instance.showBuisyIndicator()
        optionsView.fadeOut()
        interactionView.fadeOut()
        moreInfoView.fadeOut()
        
        verticalStackView.spacing = 15.0
        inquiryImage.isHidden = true
        navigationBtn.isHidden = true
        setBackroundImage(nil)
        setInfoImage(nil)
        
        InitCurrentUserInfo()
        addBackgroundImage()
        initLocationManager()
        setUpSwipe()
        InitGraphData()
    }
    
    // not in use
    @IBAction func navigationButtonAction(_ sender: Any) {
        if (interaction != nil && interaction?.place != nil) {
            navigate((interaction?.place)!)
        }
    }
    
    //MARK: Knn algo
    // get interaction offer to user
    func getNextInteraction(interaction:InteractionStory?) {
        
        MainModel.instance.getAlgorithmNextPlace(currUserLocation!, interaction: interaction) { interact in
            self.interaction = Interaction(interact.id, interact.isDeleted, interact.type.rawValue, interact.text, interact.options, interact.category, interact.lastUpdate, interact.place!)
            
            if self.interaction != nil {
                self.setInteractionwithAnimation(self.interaction!)
            }
            else {
                //Handle nil situation
            }
        }
    }
    
    // MARK: Simulation - not in use
    var count = 0
    private func simulateOnce() {
        
        MainModel.instance.fetchNearbyPlaces(location: currUserLocation!, callback: { (places, token, err)  in
            DispatchQueue.main.async {
                if places != nil && places!.count > 0 {

                    MainModel.instance.getInteraction(places![0].types, { intereact in
                        self.interaction = intereact
                        if self.interaction != nil {
                            self.interaction?.place = places![0]
                            
                            if(self.count % 2 == 0) {
                                self.interaction?.type = .question
                                self.setInteractionwithAnimation(self.interaction!)
                            } else {
                                self.setInteractionwithAnimation(self.interaction!)
                            }
                            
                            self.count += 1
                        }
                    })
                }
            }
        })
    }
    
    @objc func optionButtonAction( _ button : UIOptionButton) {
        
        if(interaction != nil && interaction?.place != nil) {
            
            //Update user history
            MainModel.instance.updateUserHistory((interaction?.place?.types)!, button.type.value)
            //Update user story
            let interactionStory = InteractionStory(place: (interaction?.place)!, location: currUserLocation!, _answer: button.type.index)
            MainModel.instance.addStoryToInteractions(interaction: interactionStory)
            
            switch button.type {
                case .accept: //navigate if a place is exist
                    //graphView.addData(interactionStory) //temp - will be moved to another code
                    navigate((interaction?.place)!)
                    return
                case .decline: break
                case .negative: break
                case .neutral: break
                case .opinionless: break
                case .additional: break
            }

            //clear value
            interaction = nil
            //#2: algo
            getNextInteraction(interaction: interactionStory)
        }
    }

    @IBAction func onSettingsClick(_ sender: Any) {
        //do something when settings button tapped?
    }

    // MARK:Navigation funcs
    private func navigate(_ place:Place) {
        
        guard let lat = place.location?.lat else { return }
        guard let long = place.location?.lng else { return }
        
        let mainStoryboard = UIStoryboard(name: "Main", bundle: Bundle.main)
        guard let mapVC = mainStoryboard.instantiateViewController(withIdentifier: "MapViewController") as? MapViewController else { return }
        mapVC.setDestinationData(destLat: lat, destlong: long, destName: place.name, destRating: place.rating)
        
        present(mapVC, animated: true, completion: nil)
    }

    // MARK:Background image funcs
    private func setBackroundImage(_ image:UIImage?) {
        DispatchQueue.main.async {
            //checking if the new image is valid for the current interaction's type
            var newImage:UIImage? = nil
            
            if (image != nil && self.interaction != nil && self.interaction?.type == .suggestion) {
                newImage = image
            }
            
             self.backgroundImage.image = newImage
        }
    }
    
    private func setInfoImage(_ image:UIImage?) {
        DispatchQueue.main.async {
            
            var newImage:UIImage? = self.defaultInfoImage
            
            if (image != nil && self.interaction != nil && self.interaction?.type == .suggestion) {
                newImage = image
            }
            
            self.moreInfoImage.image = newImage
        }
    }
    
    // MARK:interaction setting funcs
    func setInteractionwithAnimation(_ interaction:Interaction) {
        optionsView.fadeOut()
        //navigationBtn.fadeOut()
        interactionView.fadeOut()
        if let preImageView = self.view.viewWithTag(100) {
            preImageView.fadeOut()
        }
        moreInfoView.fadeOut() { (res) in
            self.setInteraction(interaction)
            
            //self.navigationBtn.fadeIn()
            self.optionsView.fadeIn()
            self.interactionView.fadeIn()
            self.moreInfoView.fadeIn()
            
            if let preImageView = self.view.viewWithTag(100) {
                preImageView.fadeIn()
            }
        }
    }
    
    @IBAction func moreInfoTapped(_ sender: Any) {
        //TODO
    }
    
    func setInteraction(_ interaction:Interaction) {
        //navigationBtn.isEnabled = true
        //navigationBtn.isHidden = true
        moreInfoView.isHidden = true
        
        let topConstraint:CGFloat = self.view.frame.height / 5
        var bottomConstraint:CGFloat = 0
        var interactionBackOpacity:CGFloat = 0

        setBackroundImage(nil)
        setInfoImage(nil)
        
        switch interaction.type {
        case .question:
            do {
                bottomConstraint = (self.view.frame.height / 5 - moreInfoView.frame.height) * -1
            }
        case .info:
            do {
                bottomConstraint = (self.view.frame.height / 5 - moreInfoView.frame.height) * -1
            }
        case .suggestion: //the only type in use
            do {
                interactionBackOpacity = 0.3
                //navigationBtn.isHidden = false
                moreInfoView.isHidden = false
                
                photos.removeAll()
                imageIndex = 0
                lastLoadedIndex = 1
                
                // check if place exist and if url's count is more then 0
                if(interaction.place != nil  && interaction.place!.picturesUrls.count > imageIndex) {
                    MainModel.instance.getPlaceImage(interaction.place!.googleID!, interaction.place!.picturesUrls[imageIndex], 800, 0.4, {(image, placeID) in
                        // check if place not changed
                        if placeID == interaction.place!.googleID!{
                            if let imageToSet = image {
                                self.photos.append(imageToSet)
                                self.setBackroundImage(imageToSet)
                                self.GetMoreImageURLS()
                            }
                        }
                    })
                }
            }
        }
        
        //checking the new bottom constraint. taking the minimum
        if(bottomConstraint > minimumBottomConstraint) {
            bottomConstraint = minimumBottomConstraint
        }
        //back colors of sub views
        interactionView.backgroundColor = UIColor(white: 0, alpha: interactionBackOpacity)
        moreInfoView.backgroundColor = UIColor(white: 0, alpha: interactionBackOpacity)
        optionsView.backgroundColor = UIColor(white: 0, alpha: interactionBackOpacity)
        //constraints of interaction text distance from settings button
        interactionSettingsConstraint.constant = topConstraint
        settingsInteractionConstraint.constant = topConstraint
        optionsBottomConstraint.constant = bottomConstraint
        
        interactionLabel.text = interaction.text
        //setting the option buttons
        setOptionsButtons(interaction.options)
    }
  
    func setOptionsButtons(_ options:[Interaction.Option])
    {
        for view in verticalStackView.subviews {
            view.removeFromSuperview()
        }
        
        var panel:UIStackView? = nil
        var subWidth:CGFloat = 0
        var maxWidth:CGFloat = 0
        var i = 0
        let sortedOptions = options.sorted(by: { $0.type.rawValue < $1.type.rawValue })
        
        for option in sortedOptions {
            if(i % 2 == 0) {
                if(panel != nil) {
                    let delta = (optionsView.frame.width - maxWidth) / 2
                    panel!.spacing = delta
                    verticalStackView.addArrangedSubview(panel!)
                }
                
                panel = UIStackView()
                panel!.axis = .horizontal
                panel!.spacing = 15.0
                subWidth = 0
            }
            
            let button = UIOptionButton(option: option, tag: i)
            button.addTarget(self, action: #selector(optionButtonAction), for: UIControl.Event.touchUpInside)
            subWidth += button.frame.size.width
            
            if(subWidth > maxWidth) {
                maxWidth = subWidth
            }
            
            panel!.addArrangedSubview(button)
            i += 1
        }
        
        if(panel != nil) {
            let delta = (optionsView.frame.width - maxWidth) / 2
            panel!.spacing = delta
            verticalStackView.addArrangedSubview(panel!)
        }
        
        optionsStackHeightConstraint.constant = CGFloat((optionButtonMinHeight + optionButtonSpace) * (i+1))
        self.view.layoutIfNeeded()
    }
    
    private func addBackgroundImage() {
        backgroundImage.tag = 100
        backgroundImage.contentMode = UIView.ContentMode.scaleAspectFill
        backgroundImage.alpha = 0.0
        self.view.insertSubview(backgroundImage, at: 0)
    }
    
    func InitCurrentUserInfo() {
        //init the user info data on the device - save the data locally if not exists
        if let user = MainModel.instance.currentUser() {
            MainModel.instance.getUserInfo(user.uid) { _ in }
        }
    }
    
    func InitGraphData() {
        MainModel.instance.getUserInteractionStories() { (stories) in
            self.graphView.overrideData(stories)
        }
    }
    
    ///MARK: Location Manager Functions
    func initLocationManager() {
        // set selfe be location deligate
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        enableLocationServices()
        // statr geting cordinates
        locationManager.startUpdatingLocation()
    }
    
    // function that location managet call after geting cordinates
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // get locatio cordinates
        let location = locations[locations.count - 1]
        
        // check if cordinates is precise
        if location.horizontalAccuracy > 0 && currUserLocation == nil {
            currUserLocation = location
            
            // if no iteraction offferd to user call getNextInteraction with nill to set Knn algoritem
            if interaction == nil {
                
                getNextInteraction(interaction: nil)
                
                self.view.isUserInteractionEnabled = true
                BuisyIndicator.Instance.hideBuisyIndicator()
            }
            
            locationManager.stopUpdatingLocation()
        }
    }
    
    //Write the didFailWithError method here:
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print(error)
    }
    
    // update user location
    func updateLocation(){
        currUserLocation = nil
        locationManager.startUpdatingLocation()
    }
    
    // app permission for navigation option
    private func enableLocationServices() {
        let status = CLLocationManager.authorizationStatus()
        
        switch status {
        case .notDetermined:
            // Request when-in-use authorization initially
            locationManager.requestAlwaysAuthorization()
            break
            
        case .restricted, .denied:
            // Disable location features
            break
            
        case .authorizedWhenInUse:
            // Enable basic location features
            break
            
        case .authorizedAlways:
            // Enable any of your app's location features
            break
        }
    }
    
    // enable handle right Swipe and left Swipe to pics
    func setUpSwipe(){
        let rightSwipe = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(sender:)))
        rightSwipe.direction = .right
        
        let leftSwipe = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(sender:)))
        leftSwipe.direction = .left
        view.addGestureRecognizer(rightSwipe)
        view.addGestureRecognizer(leftSwipe)
    }
    
    // function that wiil be called then swipe handeled
    @objc func handleSwipe(sender: UISwipeGestureRecognizer) {
        if sender.state == .ended && (photos.count > 1){
            switch sender.direction {
            case .right:
                // check if index is not 0 and set thie image as background
                if imageIndex > 0 {
                    imageIndex -= 1
                    setBackroundImage(photos[imageIndex])
                }
            case .left:
                // check if index is not bigger than count of images and set as background
                if imageIndex + 1 < (photos.count) {
                    imageIndex += 1
                    setBackroundImage(photos[imageIndex])
                    // get 3 more images to enble fast left swipe
                    GetMoreImages(endIndex: imageIndex + 3)
                }
            default:
                break
            }
        }
    }
    
    // get place's more image url's
    func GetMoreImageURLS() {
        // check if interaction exist
        if let placeID = interaction?.place?.googleID {
            MainModel.instance.GetPlacePhotos(placeID: placeID, callback: {(photosURL, placeID ,err) in
                if(err == nil && self.interaction?.place?.googleID == placeID) {
                    if var urls = photosURL {
                        urls.remove(at: 0)
                        
                        for photo in urls {
                            self.interaction?.place!.picturesUrls.append(photo.photoReference!)
                        }
                        // get firs image and set as more info background
                        if self.interaction!.place!.picturesUrls.count > 1 {
                            MainModel.instance.getPlaceImage((self.interaction?.place?.googleID)!, self.interaction!.place!.picturesUrls[1], 800, 0.4, {(image, placeID) in
                                
                                // check if interaction not changed
                                if((self.interaction?.place?.googleID) ?? nil == placeID ){
                                    if let imageToSet = image {
                                        self.photos.append(imageToSet)
                                        self.setInfoImage(imageToSet)
                                    }
                                }
                            })
                        }
                        self.GetMoreImages(endIndex: 3)
                    }
                }
            })
        }
    }
    
    func GetMoreImages(endIndex:Int) {
        if ((lastLoadedIndex + 1) < (interaction?.place!.picturesUrls.count)!) {
            let end:Int
            let start = (lastLoadedIndex + 1)
            
            //if gated end index bigger then images count set end images index by count of images
            if(endIndex >= (interaction?.place!.picturesUrls.count)!){
                end = ((interaction?.place!.picturesUrls.count)! - 1)
            }else{
                end = endIndex
            }
            
            // chack if nedd request images
            if (end > lastLoadedIndex){
                lastLoadedIndex = end
                
                for index in start...end{
                    MainModel.instance.getPlaceImage((interaction?.place?.googleID)!  ,interaction!.place!.picturesUrls[index], 800, 0.4, {(image, placeID) in
                        
                        // check if interaction not changed
                        if(placeID == (self.interaction?.place?.googleID) ?? nil ){
                            if let imageToSet = image {
                                self.photos.append(imageToSet)
                            }
                        }
                    })
                }
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.destination is MoreInfoViewController
        {
            let vc = segue.destination as? MoreInfoViewController
            vc?.displayInteractionInfo(name: interaction?.place?.name, rating: interaction?.place?.rating)
        }
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String?, sender: Any?) -> Bool {
        //avoid more info segue when no interaction exists
        if let ident = identifier {
            if ident == "MoreInfoSegue" {
                if self.interaction == nil {
                    return false
                }
            }
        }
        
        return true
    }
}
