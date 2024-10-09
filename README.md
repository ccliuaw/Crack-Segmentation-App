# CrackSegmentationApp
An iOS app for concrete crack real-time segmentation.

This project is supervised by Prof. Chia-Ming Chang in National Taiwan University (NTU), department of Civil Engineering.

The app is created by Chun-Cheng Liu (ccliuaw), as an research assistant under the supervision of Prof. Chia-Ming Chang, in 2024.

# Segmentation model
Training a U-net model for crack segmentation, using 12000+ images.

The model file for the demo is at the folder /Crack_segmentation/CoreMLSample/Extensions/Crack_model.mlmodel

# iOS application
Integrate the segmentation model into an iOS app, allow user to capture real-time segmentation results.

# Demo vedios
Please check the folder /Crack_segmentation/assets/ 

There are 2 demo videos in the folder.

3x3 means I slice the whole screen into 9 blocks (3 rows & 3 columns). Each block represents a picture, goes into U-net model for segmentation process.

4x4 means I slice the screen into 16 blocks (4 rows & 4 columns).

# Reference
coreMLhelpers by hollance

https://github.com/hollance/CoreMLHelpers.git

VFA-TRANHV-DO-NOT_USE

https://github.com/TRANHV-VFA-DO-NOT-USE/MobileAILab-HairColor-iOS.git
