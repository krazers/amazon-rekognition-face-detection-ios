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
import Foundation
import AVFoundation
import SafariServices
import AWSRekognition
import AWSDynamoDB

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, SFSafariViewControllerDelegate, AVCapturePhotoCaptureDelegate, UITableViewDataSource, UITableViewDelegate {

    //Declare Outlet variables
    @IBOutlet weak var captureImageView: UIImageView!
    @IBOutlet var tableview: UITableView!
    @IBOutlet var tableheader : UILabel!
    @IBOutlet var tableheadergood : UILabel!
    @IBOutlet var tableheaderverify : UILabel!
    @IBOutlet var tableheaderunknown : UILabel!
    @IBOutlet var tableheadergoodicon: UIImageView!
    @IBOutlet var tableheaderverifyicon: UIImageView!
    @IBOutlet var tableheaderunknownicon: UIImageView!

    @IBOutlet weak var previewView: UIView!
    @IBOutlet var takephoto: UIButton!
    
    var infoLinksMap: [Int:String] = [1000:""]
    var rekognitionObject:AWSRekognition?
    var dynamoDB:AWSDynamoDB?
    var captureSession: AVCaptureSession!
    var stillImageOutput: AVCapturePhotoOutput!
    var videoPreviewLayer: AVCaptureVideoPreviewLayer!
    let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.whiteLarge)
    var isRunning: Bool!
    var totalFacesDetected: Int!
    var totalFacesProcessed: Int!
    var totalFacesGood: Int!
    var totalFacesBad: Int!
    var totalFacesVerify: Int!
    
    //Faces datasource for table
    var facesDetected: [Face] = []
    var workitems: [DispatchWorkItem] = []
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.facesDetected.count
    }
    
    func numberOfSectionsInTableView(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "customcell") as! CustomTableViewCell
        
        if(facesDetected.count > 0){
            let text = facesDetected[indexPath.row].name
            cell.label.text = text
            let simularity = String(format: "%.2f%%", facesDetected[indexPath.row].simularity)
            cell.simularity.text = simularity
            if(facesDetected[indexPath.row].simularity < 70.0){
                cell.simularity.textColor = UIColor.red
            }
            else if(facesDetected[indexPath.row].simularity >= 98.0){
                cell.simularity.textColor = UIColor.green
            }
            else{
                cell.simularity.textColor = UIColor.yellow
            }
            let face = facesDetected[indexPath.row].face
            cell.imageicon.image = face
        }
        return cell
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.tableview.delegate = self
        self.tableview.dataSource = self
        self.tableview.register(UITableViewCell.self, forCellReuseIdentifier: "cell")

        self.updateLabels(facesprocessed: 0, facesdetected: 0, goodcount: 0, unknowncount: 0, verifycount: 0, showcounts: false)
        
        let faceImage:Data = UIImageJPEGRepresentation(captureImageView.image!, 0.2)!
        sendImageToRekognition(originalImage: captureImageView.image!, faceImageData: faceImage, handleRotation: false, lastorientation: UIDeviceOrientation.portrait)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        self.captureSession.stopRunning()
        
        setupSession()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setupSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.captureSession.stopRunning()
    }
    
    //Setup camera session
    func setupSession(){
        //Setup activity indicator
        self.activityIndicator.center = CGPoint(x: self.tableview.bounds.size.width/2, y: self.tableview.bounds.size.height/2)
        self.tableview.addSubview(activityIndicator)
        
        //Resize text for button
        self.takephoto?.titleLabel?.minimumScaleFactor = 0.5
        self.takephoto?.titleLabel?.numberOfLines = 0
        self.takephoto?.titleLabel?.adjustsFontSizeToFitWidth = true

        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .medium
        guard let backCamera = AVCaptureDevice.default(for: AVMediaType.video)
            else {
                print("Unable to access back camera!")
                return
        }
        
        do {
            if(backCamera.isFocusModeSupported(.continuousAutoFocus)){
                try! backCamera.lockForConfiguration()
                backCamera.focusMode = .continuousAutoFocus
                backCamera.unlockForConfiguration()
            }
            let input = try AVCaptureDeviceInput(device: backCamera)
            //Step 9
            stillImageOutput = AVCapturePhotoOutput()
            
            if captureSession.canAddInput(input) && captureSession.canAddOutput(stillImageOutput) {
                captureSession.addInput(input)
                captureSession.addOutput(stillImageOutput)
                setupLivePreview()
            }
        }
        catch let error  {
            print("Error Unable to initialize back camera:  \(error.localizedDescription)")
        }
        //self.captureSession.stopRunning()
    }
    
    //Setup live preview, handle rotations
    func setupLivePreview() {
        previewView.layer.sublayers?.removeAll()
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        
        videoPreviewLayer.videoGravity = .resizeAspect
        if UIDevice.current.orientation == UIDeviceOrientation.landscapeLeft {
            videoPreviewLayer.connection?.videoOrientation = .landscapeRight
        } else if UIDevice.current.orientation == UIDeviceOrientation.landscapeRight {
            videoPreviewLayer.connection?.videoOrientation = .landscapeLeft
        } else if UIDevice.current.orientation == UIDeviceOrientation.portrait {
            videoPreviewLayer.connection?.videoOrientation = .portrait
        } else if UIDevice.current.orientation == UIDeviceOrientation.portraitUpsideDown{
            videoPreviewLayer.connection?.videoOrientation = .portraitUpsideDown
        }
        previewView.layer.addSublayer(videoPreviewLayer)
        
        DispatchQueue.global(qos: .userInitiated).async { //[weak self] in
            self.captureSession.startRunning()
            //Step 13
            DispatchQueue.main.async {
                self.videoPreviewLayer.frame = self.previewView.bounds
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation()
            else { return }

        var orientation = UIImageOrientation.up
        if UIDevice.current.orientation == UIDeviceOrientation.landscapeLeft || (UIDevice.current.orientation == UIDeviceOrientation.faceUp && UIDevice.current.orientation.isLandscape){
            orientation = UIImageOrientation.up
        } else if UIDevice.current.orientation == UIDeviceOrientation.landscapeRight {
            orientation = UIImageOrientation.down
        } else if UIDevice.current.orientation == UIDeviceOrientation.portrait || (UIDevice.current.orientation == UIDeviceOrientation.faceUp && UIDevice.current.orientation.isPortrait){
            orientation = UIImageOrientation.right
        } else if UIDevice.current.orientation == UIDeviceOrientation.portraitUpsideDown{
            orientation = UIImageOrientation.left
        }
        let uiimage = UIImage(data: imageData)
        let cgimage = CIImage(image: uiimage!)
        let image = UIImage(cgImage: (cgimage?.cgImage)!, scale: 1.0, orientation: orientation)
        
        captureImageView.image = image
        let faceImage:Data = UIImagePNGRepresentation(image)!
        
        self.activityIndicator.startAnimating()

        //Cancel all work items
        for item in self.workitems{
            item.cancel()
        }
        self.workitems.removeAll()
        
        
        
        sendImageToRekognition(originalImage: image, faceImageData: faceImage, handleRotation: true, lastorientation: UIDevice.current.orientation)
    }
    
    //MARK: - Button Actions
    @IBAction func CameraOpen(_ sender: Any) {
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        
        stillImageOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func updateLabels(facesprocessed: Int, facesdetected: Int, goodcount: Int, unknowncount: Int, verifycount:Int, showcounts: Bool){
        if(facesprocessed == 0 && facesdetected == 0 && !showcounts){
            self.tableheader?.text = "Results"
        }
        else if(facesprocessed == facesdetected){
            if(facesdetected == 1){
            self.tableheader?.text = String(format: "Results (Processed %@ face)",String(facesdetected))
            }else{
                self.tableheader?.text = String(format: "Results (Processed %@ faces)",String(facesdetected))
            }
        }else if(facesprocessed == 0 && facesdetected == 0 && showcounts){
            self.tableheader?.text = "Results (Processing...)"
        }
        else if(facesprocessed < facesdetected && showcounts){
            if(facesdetected == 1){
                self.tableheader?.text = String(format: "Results (Processing %@ face...)", String(facesdetected))
            }else{
                self.tableheader?.text = String(format: "Results (Processing %@ faces...)", String(facesdetected))
            }
        }

        self.totalFacesBad = unknowncount
        self.totalFacesGood = goodcount
        self.totalFacesVerify = verifycount
        self.tableheadergood.text = String(self.totalFacesGood)
        self.tableheaderverify.text = String(self.totalFacesVerify)
        self.tableheaderunknown.text = String(self.totalFacesBad)
        self.tableheadergood.isHidden = !showcounts
        self.tableheaderverify.isHidden = !showcounts
        self.tableheaderunknown.isHidden = !showcounts
        self.tableheadergoodicon.isHidden = !showcounts
        self.tableheaderverifyicon.isHidden = !showcounts
        self.tableheaderunknownicon.isHidden = !showcounts
    }
    
    func reloadList() { // should probably be called sort and not filter
        self.facesDetected.sort() { $0.simularity > $1.simularity } // sort the faces by simularity
        self.tableview.reloadData(); // notify the table view the data has changed
    }
    
    //MARK: - AWS Methods
    func sendImageToRekognition(originalImage: UIImage, faceImageData: Data, handleRotation: Bool, lastorientation: UIDeviceOrientation){
        self.totalFacesProcessed = 0
        self.totalFacesDetected = 0
        self.totalFacesGood = 0
        self.totalFacesBad = 0
        self.totalFacesVerify = 0
        
        var mainItem:DispatchWorkItem?
        //Dispatch work to reset labels
        mainItem = DispatchWorkItem {
            if(mainItem?.isCancelled)!{
                return
            }
            //Dispatch work to reset labels
            let workItem = DispatchWorkItem {
                [weak self] in
                if(mainItem?.isCancelled)!{
                    return
                }
                self?.facesDetected.removeAll()
                self?.reloadList()
                for subView in (self?.captureImageView?.subviews)! {
                    subView.removeFromSuperview()
                }
                self?.updateLabels(facesprocessed: self!.totalFacesProcessed, facesdetected: self!.totalFacesDetected, goodcount: self!.totalFacesGood, unknowncount: self!.totalFacesBad, verifycount: self!.totalFacesVerify, showcounts: true)
            }
            DispatchQueue.main.async(execute: workItem)
            self.workitems.append(workItem)
            
            self.rekognitionObject = AWSRekognition.default()
            let faceImageAWS = AWSRekognitionImage()
            faceImageAWS?.bytes = faceImageData
            let image = UIImage(data: faceImageData as Data)

            let detectfacesrequest = AWSRekognitionDetectFacesRequest()
            detectfacesrequest?.image = faceImageAWS

            
            //Detect all faces
            self.rekognitionObject?.detectFaces(detectfacesrequest!) {
                (result, error) in
                if error != nil{
                    print(error!)
                    return
                }
                
                print(String(format:"Faces detected: %@",String(result!.faceDetails!.count)))
                //1. First we check if there are any faces in the response
                
                if (result!.faceDetails!.count > 0){
                    //Dispatch work to reset labels
                    let workItem = DispatchWorkItem {
                        [weak self] in
                        self?.totalFacesDetected = result!.faceDetails!.count
                        self?.updateLabels(facesprocessed: self!.totalFacesProcessed, facesdetected: self!.totalFacesDetected, goodcount: self!.totalFacesGood, unknowncount: self!.totalFacesBad, verifycount: self!.totalFacesVerify, showcounts: true)
                        
                    }
                    DispatchQueue.main.async(execute: workItem)
                    
                    //2. Faces were found. Lets iterate through all of them
                    for (index, face) in result!.faceDetails!.enumerated(){
                        print(String(index))
                        if(mainItem?.isCancelled)!{
                            return
                        }
                        //If confident its face, search for face in index
                        if(face.confidence!.intValue > 50){
                            let viewHeight = face.boundingBox?.height  as! CGFloat
                            let viewWidth = face.boundingBox?.width as! CGFloat
                            let toRect = CGRect(x: face.boundingBox?.left as! CGFloat, y: face.boundingBox?.top as! CGFloat, width: viewWidth, height:viewHeight)
                            
                            let croppedImage = self.cropImage(image!, toRect: toRect, viewWidth: viewWidth, viewHeight: viewHeight, handleRotation: handleRotation, lastorientation: lastorientation)
                            
                            let croppedFace:Data = UIImageJPEGRepresentation(croppedImage!, 0.2)!

                            
                            //Detect face in rekognition
                            self.rekognizeFace(faceImageData: croppedFace, detectedface: face, croppedFace: croppedImage!, handleRotation: handleRotation, lastorientation: lastorientation)
                        }
                    }
                }
                else{
                    //No faces were found (presumably no people were found either)
                    print("No faces in this pic")
                }
            }
        }
        DispatchQueue.main.async(execute: mainItem!)
        self.workitems.append(mainItem!)
    }
    
    // Rekognize face
    func rekognizeFace(faceImageData: Data, detectedface: AWSRekognitionFaceDetail, croppedFace: UIImage, handleRotation: Bool, lastorientation: UIDeviceOrientation){
        rekognitionObject = AWSRekognition.default()
        let faceImageAWS = AWSRekognitionImage()
        faceImageAWS?.bytes = faceImageData
        let imagerequest = AWSRekognitionSearchFacesByImageRequest()
        imagerequest?.collectionId = "faces"
        imagerequest?.faceMatchThreshold = 70
        imagerequest?.maxFaces = 1
        imagerequest?.image = faceImageAWS
        
        let faceInImage = Face()
        faceInImage.face = croppedFace;
        faceInImage.scene = captureImageView!
        faceInImage.simularity = 0.0
        //Get coordinates for detected face in whole image
        faceInImage.boundingBox = ["height":detectedface.boundingBox?.height, "left":detectedface.boundingBox?.left, "top":detectedface.boundingBox?.top, "width":detectedface.boundingBox?.width] as! [String : CGFloat]
        
        rekognitionObject?.searchFaces(byImage: imagerequest!) {
            (result, error) in
            if error != nil{
                print(error!)
                print("No faces in this pic")
                faceInImage.name = "Unknown"
                
                //Dispatch work to add face and label
                let workItem = DispatchWorkItem {
                    [weak self] in
                    self?.facesDetected.append(faceInImage)
                    self?.reloadList()
                    //Create a label for face.
                    let infoButton:UIButton = faceInImage.createInfoButton()
                    self?.captureImageView.addSubview(infoButton)
                    
                    self?.totalFacesProcessed = self!.totalFacesProcessed + 1
                    self?.totalFacesBad = self!.totalFacesBad + 1
                    self?.updateLabels(facesprocessed: self!.totalFacesProcessed, facesdetected: self!.totalFacesDetected, goodcount: self!.totalFacesGood, unknowncount: self!.totalFacesBad, verifycount: self!.totalFacesVerify, showcounts: true)
                    
                }
                DispatchQueue.main.async(execute: workItem)
                self.workitems.append(workItem)
                return
            }
            print(String(format:"Faces found: %@",String(result!.faceMatches!.count)))
            //1. First we check if there are any faces in the response
            if (result!.faceMatches!.count > 0){
                
                //2. Faces were found. Lets iterate through all of them
                for (index, face) in result!.faceMatches!.enumerated(){
                    print(String(index))
                    //Check the confidence value returned by the API for each celebirty identified
                    if(face.similarity!.intValue > 50){ //Adjust the confidence value to whatever you are comfortable with
                        
                        //Look up name of face identified in dynamo
                        var workItem:DispatchWorkItem?
                        workItem = DispatchWorkItem {
                            [weak self] in
                            
                            if(workItem?.isCancelled)!{
                                return
                            }
                            faceInImage.simularity = face.similarity!.floatValue
                            
                            //Get name for face
                            self!.dynamoDB = AWSDynamoDB.default()
                            let iteminput = AWSDynamoDBQueryInput()
                            iteminput?.indexName = "faceid-index"
                            iteminput?.tableName = "index-face"
                            iteminput?.keyConditionExpression = "faceid = :v1"
                            let value = AWSDynamoDBAttributeValue()
                            value?.s = face.face?.faceId
                            iteminput?.expressionAttributeValues = [":v1" : value!]
                            self!.dynamoDB?.query(iteminput!) {
                                (result, err) in
                                if let error = err as NSError? {
                                    print("Error occurred: \(error)")
                                    faceInImage.name = "Unknown"
                                    self?.totalFacesProcessed = self!.totalFacesProcessed + 1
                                    self?.totalFacesBad = self!.totalFacesBad + 1
                                    self?.updateLabels(facesprocessed: self!.totalFacesProcessed, facesdetected: self!.totalFacesDetected, goodcount: self!.totalFacesGood, unknowncount: self!.totalFacesBad, verifycount: self!.totalFacesVerify, showcounts: true)
                                }
                                else{
                                    //Find faaceid value
                                    for (_, value1) in
                                        result!.items!.enumerated(){
                                            for (_, value2) in value1.enumerated(){
                                                if(value2.key == "name"){
                                                    faceInImage.name = value2.value.s!
                                                    
                                                }
                                            }
                                    }
                                }
                                let workItem2 = DispatchWorkItem {
                                    [weak self] in
                                    if(workItem?.isCancelled)!{
                                        return
                                    }
                                    self?.facesDetected.append(faceInImage)
                                    self?.reloadList()
                                    //Create a label for face.
                                    let infoButton:UIButton = faceInImage.createInfoButton()
                                    self?.captureImageView.addSubview(infoButton)
                                    self?.totalFacesProcessed = self!.totalFacesProcessed + 1
                                    
                                    if(face.similarity!.intValue >= 98){
                                        self?.totalFacesGood = self!.totalFacesGood + 1
                                    }else{
                                        self?.totalFacesVerify = self!.totalFacesVerify + 1
                                    }
                                    self?.updateLabels(facesprocessed: self!.totalFacesProcessed, facesdetected: self!.totalFacesDetected, goodcount: self!.totalFacesGood, unknowncount: self!.totalFacesBad, verifycount: self!.totalFacesVerify, showcounts: true)

                                }
                                DispatchQueue.main.async(execute: workItem2)
                                self?.workitems.append(workItem2)
                            }
                        }
                        DispatchQueue.main.async(execute: workItem!)
                        self.workitems.append(workItem!)
                    }
                    
                }
            }
            else{
                //No faces were found (presumably no people were found either)
                print("No faces in this pic")
                faceInImage.name = "Unknown"
                
                let workItem3 = DispatchWorkItem {
                    [weak self] in
                    self?.facesDetected.append(faceInImage)
                    self?.reloadList()
                    //Create a label for face.
                    let infoButton:UIButton = faceInImage.createInfoButton()
                    self?.captureImageView.addSubview(infoButton)
                    self?.totalFacesProcessed = self!.totalFacesProcessed + 1
                    self?.totalFacesBad = self!.totalFacesBad + 1
                    self?.updateLabels(facesprocessed: self!.totalFacesProcessed, facesdetected: self!.totalFacesDetected, goodcount: self!.totalFacesGood, unknowncount: self!.totalFacesBad, verifycount: self!.totalFacesVerify, showcounts: true)
                }
                DispatchQueue.main.async(execute: workItem3)
                self.workitems.append(workItem3)
                
            }
        }
    }
    
    
    //Crop image for individual faces found
    func cropImage(_ inputImage: UIImage, toRect cropRect: CGRect, viewWidth: CGFloat, viewHeight: CGFloat, handleRotation: Bool, lastorientation: UIDeviceOrientation) -> UIImage?
    {
        
        // Scale cropRect to handle images larger than shown-on-screen size
        let cropZone = CGRect(x:cropRect.origin.x * inputImage.size.width,
                              y:cropRect.origin.y * inputImage.size.height,
                              width:cropRect.size.width * inputImage.size.width,
                              height:cropRect.size.height * inputImage.size.height)
        
        // Perform cropping in Core Graphics
        guard let cutImageRef: CGImage = inputImage.cgImage?.cropping(to:cropZone)
            else {
                return nil
        }
        
        // Return image to UIImage
        if(handleRotation){
            var orientation = UIImageOrientation.up
            if lastorientation == UIDeviceOrientation.landscapeLeft || (UIDevice.current.orientation == UIDeviceOrientation.faceUp && UIDevice.current.orientation.isLandscape){
                orientation = UIImageOrientation.up
            } else if lastorientation == UIDeviceOrientation.landscapeRight {
                orientation = UIImageOrientation.down
            } else if lastorientation == UIDeviceOrientation.portrait || (UIDevice.current.orientation == UIDeviceOrientation.faceUp && UIDevice.current.orientation.isPortrait){
                orientation = UIImageOrientation.right
            } else if lastorientation == UIDeviceOrientation.portraitUpsideDown{
                orientation = UIImageOrientation.left
            }
            
            return UIImage(cgImage: cutImageRef, scale: 1.0, orientation: orientation)
        }else{
            return UIImage(cgImage: cutImageRef)
        }
    }

}
