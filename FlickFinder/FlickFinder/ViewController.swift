//
//  ViewController.swift
//  FlickFinder
//
//  Created by Jarrod Parkes on 11/5/15.
//  Copyright © 2015 Udacity. All rights reserved.
//

import UIKit
import Alamofire

// MARK: - ViewController: UIViewController

class ViewController: UIViewController {
    
    // MARK: Properties
    
    var keyboardOnScreen = false
    
    // MARK: Outlets
    
    @IBOutlet weak var photoImageView: UIImageView!
    @IBOutlet weak var photoTitleLabel: UILabel!
    @IBOutlet weak var phraseTextField: UITextField!
    @IBOutlet weak var phraseSearchButton: UIButton!
    @IBOutlet weak var latitudeTextField: UITextField!
    @IBOutlet weak var longitudeTextField: UITextField!
    @IBOutlet weak var latLonSearchButton: UIButton!
    
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        phraseTextField.delegate = self
        latitudeTextField.delegate = self
        longitudeTextField.delegate = self
        subscribeToNotification(.UIKeyboardWillShow, selector: #selector(keyboardWillShow))
        subscribeToNotification(.UIKeyboardWillHide, selector: #selector(keyboardWillHide))
        subscribeToNotification(.UIKeyboardDidShow, selector: #selector(keyboardDidShow))
        subscribeToNotification(.UIKeyboardDidHide, selector: #selector(keyboardDidHide))
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        unsubscribeFromAllNotifications()
    }
    
    // MARK: Search Actions
    
    @IBAction func searchByPhrase(_ sender: AnyObject) {

        userDidTapView(self)
        setUIEnabled(false)
        
        if !phraseTextField.text!.isEmpty {
            photoTitleLabel.text = "Searching..."
            // TODO: Set necessary parameters!
            let methodParameters: [String: AnyObject] = [
                Constants.FlickrParameterKeys.SafeSearch: Constants.FlickrParameterValues.UseSafeSearch as AnyObject,
                Constants.FlickrParameterKeys.Text: phraseTextField.text as AnyObject,
                Constants.FlickrParameterKeys.Extras: Constants.FlickrParameterValues.MediumURL as AnyObject,
                Constants.FlickrParameterKeys.APIKey: Constants.FlickrParameterValues.APIKey as AnyObject,
                Constants.FlickrParameterKeys.Method: Constants.FlickrParameterValues.SearchMethod as AnyObject,
                Constants.FlickrParameterKeys.Format: Constants.FlickrParameterValues.ResponseFormat as AnyObject,
                Constants.FlickrParameterKeys.NoJSONCallback: Constants.FlickrParameterValues.DisableJSONCallback as AnyObject
            ]
            displayImageFromFlickrBySearch(methodParameters)
        } else {
            setUIEnabled(true)
            photoTitleLabel.text = "Phrase Empty."
        }
    }
    
    @IBAction func searchByLatLon(_ sender: AnyObject) {

        userDidTapView(self)
        setUIEnabled(false)
        
        if isTextFieldValid(latitudeTextField, forRange: Constants.Flickr.SearchLatRange) && isTextFieldValid(longitudeTextField, forRange: Constants.Flickr.SearchLonRange) {
            photoTitleLabel.text = "Searching..."
            // TODO: Set necessary parameters!
            guard let latitudeText = latitudeTextField.text as? String, let longitudeText = longitudeTextField.text as? String else {
                print("no lat or lon")
                return
            }

            let methodParameters: [String: AnyObject] = [
                Constants.FlickrParameterKeys.SafeSearch: Constants.FlickrParameterValues.UseSafeSearch as AnyObject,
                Constants.FlickrParameterKeys.BoundingBox: bbox(latitudeText, longitudeText) as AnyObject,
                Constants.FlickrParameterKeys.Extras: Constants.FlickrParameterValues.MediumURL as AnyObject,
                Constants.FlickrParameterKeys.APIKey: Constants.FlickrParameterValues.APIKey as AnyObject,
                Constants.FlickrParameterKeys.Method: Constants.FlickrParameterValues.SearchMethod as AnyObject,
                Constants.FlickrParameterKeys.Format: Constants.FlickrParameterValues.ResponseFormat as AnyObject,
                Constants.FlickrParameterKeys.NoJSONCallback: Constants.FlickrParameterValues.DisableJSONCallback as AnyObject
            ]
            displayImageFromFlickrBySearch(methodParameters)
        }
        else {
            setUIEnabled(true)
            photoTitleLabel.text = "Lat should be [-90, 90].\nLon should be [-180, 180]."
        }
    }
    
    private func bbox(_ latitudeText: String, _ longitudeText: String) -> String {
        let lat = Double(latitudeText)!
        let lon = Double(longitudeText)!
        let latMin = max(lat - Constants.Flickr.SearchBBoxHalfHeight, Constants.Flickr.SearchLatRange.0)
        let latMax = min(lat + Constants.Flickr.SearchBBoxHalfHeight, Constants.Flickr.SearchLatRange.1)
        let lonMin = max(lon - Constants.Flickr.SearchBBoxHalfWidth, Constants.Flickr.SearchLonRange.0)
        let lonMax = min(lon + Constants.Flickr.SearchBBoxHalfWidth,Constants.Flickr.SearchLonRange.1)
        
        return "\(lonMin),\(latMin),\(lonMax),\(latMax)"
    }
    
    // MARK: Flickr API
    private func displayImageFromFlickrBySearch(_ methodParameters: [String: AnyObject]){
        Alamofire.request(flickrURLFromParameters(methodParameters), method: .get, parameters: methodParameters, encoding: JSONEncoding.default)
            .responseJSON { response in
                func displayError(_ error: String){
                    print(error)
                    performUIUpdatesOnMain {
                        self.setUIEnabled(true)
                        self.photoImageView.image = nil
                        self.photoTitleLabel.text = "No image found, try again"
                    }
                }
                
                guard response.error == nil else {
                    displayError("There was an error with your request: \(response.error)")
                    return
                }
                
                
                guard let parsedResult = response.value as? [String: AnyObject] else {
                    print("No data")
                    return
                }
                
                guard let parsedPhoto = parsedResult["photos"] as? [String: AnyObject] else {
                    print("No photos found in parsed data")
                    return
                }
                
                guard let totalPages = parsedPhoto["pages"] as? Int else {
                    return
                }
                
                let minPages = min(totalPages, 40)
                let randomPage = Int(arc4random_uniform(UInt32(minPages))) + 1
                
                self.displayImageFromFlickrBySearch(methodParameters, randomPage)
        }
    }
    
    private func displayImageFromFlickrBySearch(_ methodParameters: [String: AnyObject], _ withPageNumber: Int) {
        var mP = methodParameters
        mP["page"] = withPageNumber as AnyObject
        
        Alamofire.request(flickrURLFromParameters(mP), method: .get, parameters: methodParameters, encoding: JSONEncoding.default)
            .responseJSON { response in
                func displayError(_ error: String){
                    print(error)
                    performUIUpdatesOnMain {
                        self.setUIEnabled(true)
                        self.photoImageView.image = nil
                        self.photoTitleLabel.text = "No image found, try again"
                    }
                }
                
                guard response.error == nil else {
                    displayError("There was an error with your request: \(response.error)")
                    return
                }
                
                
                guard let parsedResult = response.value as? [String: AnyObject] else {
                    print("No data")
                    return
                }
            
                guard let parsedPhoto = parsedResult["photos"] as? [String: AnyObject], let photosArray = parsedPhoto["photo"] as? [[String: AnyObject]]  else {
                    print("No photos found in parsed data")
                    return
                }
      
                if parsedPhoto.count == 0 {
                    displayError("No Photos Found. Search Again.")
                    return
                } else {
                    
                    let randomPhotos = Int(arc4random_uniform(UInt32(photosArray.count)))
                    let imagePicked = photosArray[randomPhotos] as [String: AnyObject]

                    guard let imageURL = imagePicked[Constants.FlickrResponseKeys.MediumURL] as? String else {
                        print("No image url found")
                        return
                    }

                    guard let photoTitle = imagePicked[Constants.FlickrResponseKeys.Title] as? String else {
                        print("No photo title found")
                        return
                    }

                    let imageLink = URL(string: imageURL)
                    if let imageData = try? Data(contentsOf: imageLink!) {
                        performUIUpdatesOnMain {
                            self.setUIEnabled(true)
                            self.photoImageView.image = UIImage(data: imageData)
                            self.photoTitleLabel.text = photoTitle ?? "(Untitled)"
                        }
                    } else {
                        displayError("Image does not exist at \(imageURL)")
                    }
                }
            }

    }
    
    // MARK: Helper for Creating a URL from Parameters
    
    private func flickrURLFromParameters(_ parameters: [String: AnyObject]) -> URL {
        
        var components = URLComponents()
        components.scheme = Constants.Flickr.APIScheme
        components.host = Constants.Flickr.APIHost
        components.path = Constants.Flickr.APIPath
        components.queryItems = [URLQueryItem]()
        
        for (key, value) in parameters {
            let queryItem = URLQueryItem(name: key, value: "\(value)")
            components.queryItems!.append(queryItem)
        }
        
        return components.url!
    }
}

// MARK: - ViewController: UITextFieldDelegate

extension ViewController: UITextFieldDelegate {
    
    // MARK: UITextFieldDelegate
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    // MARK: Show/Hide Keyboard
    
    func keyboardWillShow(_ notification: Notification) {
        if !keyboardOnScreen {
            view.frame.origin.y -= keyboardHeight(notification)
        }
    }
    
    func keyboardWillHide(_ notification: Notification) {
        if keyboardOnScreen {
            view.frame.origin.y += keyboardHeight(notification)
        }
    }
    
    func keyboardDidShow(_ notification: Notification) {
        keyboardOnScreen = true
    }
    
    func keyboardDidHide(_ notification: Notification) {
        keyboardOnScreen = false
    }
    
    func keyboardHeight(_ notification: Notification) -> CGFloat {
        let userInfo = (notification as NSNotification).userInfo
        let keyboardSize = userInfo![UIKeyboardFrameEndUserInfoKey] as! NSValue
        return keyboardSize.cgRectValue.height
    }
    
    func resignIfFirstResponder(_ textField: UITextField) {
        if textField.isFirstResponder {
            textField.resignFirstResponder()
        }
    }
    
    @IBAction func userDidTapView(_ sender: AnyObject) {
        resignIfFirstResponder(phraseTextField)
        resignIfFirstResponder(latitudeTextField)
        resignIfFirstResponder(longitudeTextField)
    }
    
    // MARK: TextField Validation
    
    func isTextFieldValid(_ textField: UITextField, forRange: (Double, Double)) -> Bool {
        if let value = Double(textField.text!), !textField.text!.isEmpty {
            return isValueInRange(value, min: forRange.0, max: forRange.1)
        } else {
            return false
        }
    }
    
    func isValueInRange(_ value: Double, min: Double, max: Double) -> Bool {
        return !(value < min || value > max)
    }
}

// MARK: - ViewController (Configure UI)

private extension ViewController {
    
     func setUIEnabled(_ enabled: Bool) {
        photoTitleLabel.isEnabled = enabled
        phraseTextField.isEnabled = enabled
        latitudeTextField.isEnabled = enabled
        longitudeTextField.isEnabled = enabled
        phraseSearchButton.isEnabled = enabled
        latLonSearchButton.isEnabled = enabled
        
        // adjust search button alphas
        if enabled {
            phraseSearchButton.alpha = 1.0
            latLonSearchButton.alpha = 1.0
        } else {
            phraseSearchButton.alpha = 0.5
            latLonSearchButton.alpha = 0.5
        }
    }
}

// MARK: - ViewController (Notifications)

private extension ViewController {
    
    func subscribeToNotification(_ notification: NSNotification.Name, selector: Selector) {
        NotificationCenter.default.addObserver(self, selector: selector, name: notification, object: nil)
    }
    
    func unsubscribeFromAllNotifications() {
        NotificationCenter.default.removeObserver(self)
    }
}
