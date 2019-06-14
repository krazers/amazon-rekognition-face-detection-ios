
## Amazon Rekognition Face Detection IOS

iOS Swift project code for identifying people using Amazon Rekognition

### Getting started

First we will need to provision the backend services for the mobile app. Click on link below to execute the cloudformation template. The template is also added to this repository

<a href="https://console.aws.amazon.com/cloudformation/home?region=us-west-2#/stacks/new?stackName=rekognitionapp&amp;templateURL=https://rekognition-demo-app.s3.amazonaws.com/rekognitionapp.json"><img class="alignnone wp-image-1941 size-full" src="https://d2908q01vomqb2.cloudfront.net/0a57cb53ba59c46fc4b692527a38a87c78d84028/2018/10/17/cf-launch-stack.png" alt="" width="144" height="27"></a>

Note the **identityPoolId** that is provided in the output section of your cloudformation stack when complete. This will be used later in the mobile app.


*App is forked and modified from this blog: [AWS Mobile Blog - Using Amazon Rekognition to detect celebrities in an iOS app](https://aws.amazon.com/blogs/mobile/amazon-rekognition-detects-celebrities-in-ios-app/).*

## Steps to use

1. Enter the Cognito Identity Pool Id in the *AppDelegate.swift* file under the *Initialize Identity Provider* section. 
2. Run `pod install --repo-update` to get the required Pods. Your Podfile already has the dependencies listed.
3. Since no faces have been added yet to the rekognition collection, go to the s3 bucket created by the cloudformation template. The name of the bucket was requested as a parameter.
4. Drop an image of yourself or someone you want to identify into the bucket using AWS Console. Note that deleting a object from bucket will remove the face from the index.
5. Provide a Tag for the object called **Name** with the full name of the person as seen below:
<img class="alignnone wp-image-1941 size-full" src="https://github.com/krazers/amazon-rekognition-face-detection-ios/blob/master/s3objecttag.png?raw=true">
6. Save and hit next until complete.
7. Build the app for your device and confirm that the app is working and making calls to Amazon Rekognition. If everything works, you should see a label on the face in the image that Amazon Rekognition has identified in your collection called **faces**.

## License Summary

This sample code is made available under a modified MIT license. See the LICENSE file.
