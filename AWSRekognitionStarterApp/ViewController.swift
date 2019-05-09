/*
 * Copyright 2018 Amazon.com, Inc. or its affiliates. All Rights Reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this
 * software and associated documentation files (the "Software"), to deal in the Software
 * without restriction, including without limitation the rights to use, copy, modify,
 * merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so.
 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
 * INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
 * PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 * OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 * SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */
import UIKit
import SafariServices
import AWSRekognition
import AWSDynamoDB

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, SFSafariViewControllerDelegate {
    
    @IBOutlet weak var FaceImageView: UIImageView!
    
    var infoLinksMap: [Int:String] = [1000:""]
    var rekognitionObject:AWSRekognition?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        let faceImage:Data = UIImageJPEGRepresentation(FaceImageView.image!, 0.2)!
        sendImageToRekognition(faceImageData: faceImage)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    
    //MARK: - Button Actions
    @IBAction func CameraOpen(_ sender: Any) {
        let pickerController = UIImagePickerController()
        pickerController.delegate = self
        pickerController.sourceType = .camera
        pickerController.cameraCaptureMode = .photo
        present(pickerController, animated: true)
    }
    
    @IBAction func PhotoLibraryOpen(_ sender: Any) {
        let pickerController = UIImagePickerController()
        pickerController.delegate = self
        pickerController.sourceType = .savedPhotosAlbum
        present(pickerController, animated: true)
    }
    
    func lookUpPerson(){
        let dynamoDB = AWSDynamoDB.default()
        let listTableInput = AWSDynamoDBListTablesInput()
        dynamoDB.listTables(listTableInput!).continueWith { (task:AWSTask<AWSDynamoDBListTablesOutput>) -> Any? in
            if let error = task.error as? NSError {
                print("Error occurred: \(error)")
                return nil
            }
            
            let listTablesOutput = task.result
            
            for tableName in listTablesOutput!.tableNames! {
                print("\(tableName)")
            }
            
            return nil
        }
    }
    
    // MARK: - UIImagePickerControllerDelegate
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        dismiss(animated: true)
        
        guard let image = info[UIImagePickerControllerOriginalImage] as? UIImage else {
            fatalError("couldn't load image from Photos")
        }
        
        FaceImageView.image = image
        let faceImage:Data = UIImageJPEGRepresentation(image, 0.2)!
        
        //Demo Line
        sendImageToRekognition(faceImageData: faceImage)
    }
    
    
    //MARK: - AWS Methods
    func sendImageToRekognition(faceImageData: Data){
        
        //Delete older labels or buttons
        DispatchQueue.main.async {
            [weak self] in
            for subView in (self?.FaceImageView.subviews)! {
                subView.removeFromSuperview()
            }
        }
        
        rekognitionObject = AWSRekognition.default()
        let faceImageAWS = AWSRekognitionImage()
        faceImageAWS?.bytes = faceImageData
        let imagerequest = AWSRekognitionSearchFacesByImageRequest()
        imagerequest?.collectionId = "myindex"
        imagerequest?.faceMatchThreshold = 95
        imagerequest?.image = faceImageAWS
        imagerequest?.maxFaces = 5
        rekognitionObject?.searchFaces(byImage: (imagerequest)!) {
            (result, error) in
            if error != nil{
                print(error!)
                return
            }
            
            //1. First we check if there are any faces in the response
            if ((result!.faceMatches?.count)! > 0){
                
                //2. Celebrities were found. Lets iterate through all of them
                for (index, face) in result!.faceMatches!.enumerated(){
                    
                    //Check the confidence value returned by the API for each celebirty identified
                    if(face.similarity!.intValue > 50){ //Adjust the confidence value to whatever you are comfortable with
                        
                        //We are confident this is celebrity. Lets point them out in the image using the main thread
                        DispatchQueue.main.async {
                            [weak self] in
                            
                            //Create an instance of Face. This class is availabe with the starter application you downloaded
                            let faceInImage = Face()
                            
                            faceInImage.scene = (self?.FaceImageView)!
                            
                            //Get the coordinates for where this celebrity face is in the image and pass them to the Celebrity instance
                            faceInImage.boundingBox = ["height":face.face?.boundingBox?.height, "left":face.face?.boundingBox?.left, "top":face.face?.boundingBox?.top, "width":face.face?.boundingBox?.width] as! [String : CGFloat]
                            
                            
                            //Get the person name and pass it along
                            //faceInImage.name = face.name!
                            //Get the first url returned by the API for this celebrity. This is going to be an IMDb profile link
                            //if (face.urls!.count > 0){
                            //    faceInImage.infoLink = face.urls![0]
                            //}
                                //If there are no links direct them to IMDB search page
                            //else{
                            //    celebrityInImage.infoLink = "https://www.imdb.com/search/name-text?bio="+celebrityInImage.name
                            //}
                            //Update the celebrity links map that we will use next to create buttons
                            //self?.infoLinksMap[index] = "https://"+celebFace.urls![0]
                            
                            //Create a button that will take users to the IMDb link when tapped
                            let infoButton:UIButton = faceInImage.createInfoButton()
                            infoButton.tag = index
                            infoButton.addTarget(self, action: #selector(self?.handleTap), for: UIControlEvents.touchUpInside)
                            self?.FaceImageView.addSubview(infoButton)
                        }
                    }
                    
                }
            }
                //If there were no celebrities in the image, lets check if there were any faces (who, granted, could one day become celebrities)
            //else if ((result!.unrecognizedFaces?.count)! > 0){
                //Faces are present. Point them out in the Image (left as an exercise for the reader)
                /**/
            //}
            else{
                //No faces were found (presumably no people were found either)
                print("No faces in this pic")
            } 
        }
        
    }
    
    @objc func handleTap(sender:UIButton){
        print("tap recognized")
        let celebURL = URL(string: self.infoLinksMap[sender.tag]!)
        let safariController = SFSafariViewController(url: celebURL!)
        safariController.delegate = self
        self.present(safariController, animated:true)
    }
}
