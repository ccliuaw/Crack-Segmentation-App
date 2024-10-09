/*
  Copyright (c) 2017 M.I. Hollemans

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to
  deal in the Software without restriction, including without limitation the
  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
  sell copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
  IN THE SOFTWARE.
*/

import Foundation
import Accelerate
import CoreImage

/**
 Creates a RGB pixel buffer of the specified width and height.
*/
public func createPixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
  var pixelBuffer: CVPixelBuffer?
  let status = CVPixelBufferCreate(nil, width, height,
                                   kCVPixelFormatType_32BGRA, nil,
                                   &pixelBuffer)
  if status != kCVReturnSuccess {
    print("Error: could not create resized pixel buffer", status)
    return nil
  }
  return pixelBuffer
}

/**
 First crops the pixel buffer, then resizes it.
*/
public func resizePixelBuffer(_ srcPixelBuffer: CVPixelBuffer,
                              cropX: Int,
                              cropY: Int,
                              cropWidth: Int,
                              cropHeight: Int,
                              scaleWidth: Int,
                              scaleHeight: Int) -> CVPixelBuffer? {

  CVPixelBufferLockBaseAddress(srcPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
  guard let srcData = CVPixelBufferGetBaseAddress(srcPixelBuffer) else {
    print("Error: could not get pixel buffer base address")
    return nil
  }
  let srcBytesPerRow = CVPixelBufferGetBytesPerRow(srcPixelBuffer)
  let offset = cropY*srcBytesPerRow + cropX*4
  var srcBuffer = vImage_Buffer(data: srcData.advanced(by: offset),
                                height: vImagePixelCount(cropHeight),
                                width: vImagePixelCount(cropWidth),
                                rowBytes: srcBytesPerRow)

  let destBytesPerRow = scaleWidth*4
  guard let destData = malloc(scaleHeight*destBytesPerRow) else {
    print("Error: out of memory")
    return nil
  }
  var destBuffer = vImage_Buffer(data: destData,
                                 height: vImagePixelCount(scaleHeight),
                                 width: vImagePixelCount(scaleWidth),
                                 rowBytes: destBytesPerRow)

  let error = vImageScale_ARGB8888(&srcBuffer, &destBuffer, nil, vImage_Flags(0))
  CVPixelBufferUnlockBaseAddress(srcPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
  if error != kvImageNoError {
    print("Error:", error)
    free(destData)
    return nil
  }

  let releaseCallback: CVPixelBufferReleaseBytesCallback = { _, ptr in
    if let ptr = ptr {
      free(UnsafeMutableRawPointer(mutating: ptr))
    }
  }

  let pixelFormat = CVPixelBufferGetPixelFormatType(srcPixelBuffer)
  var dstPixelBuffer: CVPixelBuffer?
  let status = CVPixelBufferCreateWithBytes(nil, scaleWidth, scaleHeight,
                                            pixelFormat, destData,
                                            destBytesPerRow, releaseCallback,
                                            nil, nil, &dstPixelBuffer)
  if status != kCVReturnSuccess {
    print("Error: could not create new pixel buffer")
    free(destData)
    return nil
  }
  return dstPixelBuffer
}

/**
 Resizes a CVPixelBuffer to a new width and height.
*/
public func resizePixelBuffer(_ pixelBuffer: CVPixelBuffer,
                              width: Int, height: Int) -> CVPixelBuffer? {
  return resizePixelBuffer(pixelBuffer, cropX: 0, cropY: 0,
                           cropWidth: CVPixelBufferGetWidth(pixelBuffer),
                           cropHeight: CVPixelBufferGetHeight(pixelBuffer),
                           scaleWidth: width, scaleHeight: height)
}

/**
 Resizes a CVPixelBuffer to a new width and height.
*/
public func resizePixelBuffer(_ pixelBuffer: CVPixelBuffer,
                              width: Int, height: Int,
                              output: CVPixelBuffer, context: CIContext) {
  let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
  let sx = CGFloat(width) / CGFloat(CVPixelBufferGetWidth(pixelBuffer))
  let sy = CGFloat(height) / CGFloat(CVPixelBufferGetHeight(pixelBuffer))
  let scaleTransform = CGAffineTransform(scaleX: sx, y: sy)
  let scaledImage = ciImage.transformed(by: scaleTransform)
  context.render(scaledImage, to: output)
}

// Works with BiPlanar types kCVPixelFormatType_420YpCbCr8BiPlanarFullRange and kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
// Planar video would only be a matter of repeating the steps for each plane as the Cb and Cr planes would be separate. But the iOS
// camera can't output planar video so I have no way to test that

// Based on https://github.com/hollance/CoreMLHelpers/blob/master/CoreMLHelpers/CVPixelBuffer%2BHelpers.swift#L45

public func resizePixelBufferBiPlanar(_ srcPixelBuffer: CVPixelBuffer,
                                      cropRect: CGRect,
                                      scaleWidth: Int,
                                      scaleHeight: Int) -> CVPixelBuffer? {
    
    let cropX = Int(cropRect.minX)
    let cropY = Int(cropRect.minY)
    let cropHeight = Int(cropRect.height)
    let cropWidth = Int(cropRect.width)
    
    assert(CVPixelBufferGetPlaneCount(srcPixelBuffer) == 2)
    
    guard CVPixelBufferLockBaseAddress(srcPixelBuffer, [.readOnly]) == kCVReturnSuccess else { return nil }
    defer { CVPixelBufferUnlockBaseAddress(srcPixelBuffer, [.readOnly]) }
    
    // Do Luminance Plane Setup
    
    guard let sourceLuminanceData = CVPixelBufferGetBaseAddressOfPlane(srcPixelBuffer, 0) else {
        print("Error: could not get pixel buffer base address")
        return nil
    }
    
    let bytesPerRowLuminance = CVPixelBufferGetBytesPerRowOfPlane(srcPixelBuffer, 0)
    let bytesPerPixelLuminance = 1 // bytesPerRowLuminance / widthLuminance
    let croppingOffsetLuminance = cropY * bytesPerRowLuminance + cropX * bytesPerPixelLuminance
    var sourceBufferLuminance = vImage_Buffer(data: sourceLuminanceData.advanced(by: croppingOffsetLuminance),
                                              height: vImagePixelCount(cropHeight),
                                              width: vImagePixelCount(cropWidth),
                                              rowBytes: bytesPerRowLuminance)
    
    let destinationBytesPerRowLuminance = scaleWidth * bytesPerPixelLuminance
    
    let outputBufferSizeLuminance = scaleHeight * destinationBytesPerRowLuminance
    
    // End Luminance Plane Setup
    
    // Do CbCr Plane Setup
    
    guard let sourceCbCrData = CVPixelBufferGetBaseAddressOfPlane(srcPixelBuffer, 1) else {
        print("Error: could not get pixel buffer base address")
        return nil
    }
    
    let bytesPerRowCbCr = CVPixelBufferGetBytesPerRowOfPlane(srcPixelBuffer, 1)
    let bytesPerPixelCbCr = 2 // bytesPerRowCbCr / widthCbCr
    
    let croppingOffsetCbCr = cropY / 2 * bytesPerRowCbCr + cropX / 2 * bytesPerPixelCbCr
    var sourceBufferCbCr = vImage_Buffer(data: sourceCbCrData.advanced(by: croppingOffsetCbCr),
                                         height: vImagePixelCount(cropHeight / 2),
                                         width: vImagePixelCount(cropWidth / 2),
                                         rowBytes: bytesPerRowCbCr)
    
    let destinationBytesPerRowCbCr = scaleWidth / 2 * bytesPerPixelCbCr
    let outputBufferSizeCbCr = scaleHeight / 2 * destinationBytesPerRowCbCr
    
    // End CbCr Plance Setup
    
    let outputBufferSize = outputBufferSizeLuminance + outputBufferSizeCbCr
    guard let finalPixelData = malloc(outputBufferSize) else {
        print("Error: out of memory")
        return nil
    }
    
    // Do Luminace Plane Crop and Scale
    
    var luminanceDestBuffer = vImage_Buffer(data: finalPixelData,
                                            height: vImagePixelCount(scaleHeight),
                                            width: vImagePixelCount(scaleWidth),
                                            rowBytes: destinationBytesPerRowLuminance)
    
    let error = vImageScale_Planar8(&sourceBufferLuminance, &luminanceDestBuffer, nil, vImage_Flags(0))
    if error != kvImageNoError {
        print("Error:", error)
        free(finalPixelData)
        return nil
    }
    
    // End Luminance Plane Crop and Scale
    
    // Do CbCr Plane Crop and Scale
    
    let pixelDataCbCr = finalPixelData.advanced(by: outputBufferSizeLuminance)
    var cbCrDestBuffer = vImage_Buffer(data: pixelDataCbCr,
                                       height: vImagePixelCount(scaleHeight / 2),
                                       width: vImagePixelCount(scaleWidth / 2),
                                       rowBytes: destinationBytesPerRowCbCr)
    
    let errorCbCr = vImageScale_CbCr8(&sourceBufferCbCr, &cbCrDestBuffer, nil, vImage_Flags(0))
    if errorCbCr != kvImageNoError {
        print("Error:", errorCbCr)
        free(finalPixelData)
        return nil
    }
    
    // End CbCr Plane
    
    let releaseCallbackBiPlanar: CVPixelBufferReleasePlanarBytesCallback = { releaseRefCon, dataPtr, dataSize, numberOfPlanes, planeAddresses in
        if let dataPtr = dataPtr {
            free(UnsafeMutableRawPointer(mutating: dataPtr))
        }
    }
    
    let pixelFormat = CVPixelBufferGetPixelFormatType(srcPixelBuffer)
    var outputPixelBuffer: CVPixelBuffer?
    
    var planeWidths = [scaleWidth, scaleWidth/2]
    var planeHeights = [scaleWidth, scaleWidth/2]
    var bytesPerRows = [destinationBytesPerRowLuminance, destinationBytesPerRowCbCr]
    var baseAddresses: [UnsafeMutableRawPointer?] = [finalPixelData, finalPixelData.advanced(by: outputBufferSizeLuminance)]
    
    let status = CVPixelBufferCreateWithPlanarBytes(
        nil, // 1
        scaleWidth, // 2
        scaleHeight, // 3
        pixelFormat, // 4
        finalPixelData, // 5
        outputBufferSize, // 6
        2, // 7
        &baseAddresses, // 8
        &planeWidths, // 9
        &planeHeights, // 10
        &bytesPerRows, // 11
        releaseCallbackBiPlanar, // 12
        nil, // 13
        nil, // 14
        &outputPixelBuffer // 16
    )
    
    if status != kCVReturnSuccess {
        print("Error: could not create new pixel buffer")
        free(finalPixelData)
        return nil
    }
    
    return outputPixelBuffer
}
