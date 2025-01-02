# Crack Segmentation App
This is an iOS app for concrete crack real-time segmentation. Integrate the segmentation model into an iOS app, allow user to capture real-time segmentation results.

This project is supervised by Prof. Chia-Ming Chang at National Taiwan University (NTU), department of Civil Engineering.

The app is created by Chun-Cheng Liu (ccliuaw), as an research assistant under the supervision of Prof. Chia-Ming Chang, in 2024.

## Image segmentation model
Training a U-net model for crack segmentation, using 12000+ images.

>The model file is under the folder /Crack_segmentation/CoreMLSample/Crack_model.mlmodel

## Platform tested

iOS 11.0, Xcode 15.2, iPhone 13

## Install app

Download the whole project to your local computer and launch with Xcode, connect with your iOS device (iPhone 13 or above recommended). And you are good to go!

Official instructions for installing iOS app: https://developer.apple.com/documentation/xcode/running-your-app-in-simulator-or-on-a-device

## Demo videos

There are 2 demo video YouTube links below, or you can check the folder /Crack_segmentation/assets/ , to find the mp4 files.

In these demo videos, I searched on google for "concrete images" and showed on my monitor to simulate a real concrete wall environment. You can see the real-time segmentation result will be presented as blue masks.

3x3 means I slice the whole screen into 9 blocks (3 rows & 3 columns). Each block represents a picture, goes into U-net model for segmentation process.
https://www.youtube.com/shorts/ivD1d-AnnV4


4x4 means I slice the screen into 16 blocks (4 rows & 4 columns).
https://youtube.com/shorts/IatsAP5FPcQ?feature=share

## Reference
1. coreMLhelpers by hollance

https://github.com/hollance/CoreMLHelpers.git

2. VFA-TRANHV-DO-NOT_USE

https://github.com/TRANHV-VFA-DO-NOT-USE/MobileAILab-HairColor-iOS.git
