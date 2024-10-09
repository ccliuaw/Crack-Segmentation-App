import UIKit
import AVFoundation
import Vision
import CoreML

@available(iOS 13.0, *)
class ViewController: UIViewController {
    
    @IBOutlet weak var cameraPreview: CameraPreviewView!
    @IBOutlet weak var predictionView: UIImageView!
    
    private var session: AVCaptureSession?
    
    lazy var predictionRequest: VNCoreMLRequest = {
        // Load the ML model through its generated class and create a Vision request for it.
        do {
            let model = try VNCoreMLModel(for: Crack_model().model)
//            let request = VNCoreMLRequest(model: model, completionHandler: self.handlePrediction)
            let request = VNCoreMLRequest(model: model)
            request.imageCropAndScaleOption = VNImageCropAndScaleOption.centerCrop
            return request
        } catch {
            fatalError("can't load Vision ML model: \(error)")
        }
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        predictionView.transform = CGAffineTransform(translationX: 0, y: 170)//mirror rotation and 下平移 of the capture video.
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AVCaptureDevice.requestAuthorization { [weak self] (granted) in
            self?.permissions(granted)
        }
        session?.startRunning()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        session?.stopRunning()
    }
    
    private func permissions(_ granted: Bool) {
        if granted && session == nil {
            setupSession()
        }
    }
    
    private func setupSession() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: AVMediaType.video, position: .back) else {
            fatalError("Capture device not available")
        }   // here, position: .back or .front , we can change the camera.
        device.setFrameRate(frameRate:  1) // setting frame rate to lower fps, since we need to merge several images into 1 full image.
        guard let input = try? AVCaptureDeviceInput(device: device) else {
            fatalError("Capture input not available")
        }
        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: DispatchQueue.global(qos: .userInteractive))
        
        let session = AVCaptureSession()
        session.addInput(input)
        session.addOutput(output)
        
//        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
//        cameraPreview.addCaptureVideoPreviewLayer(previewLayer)
        
        self.session = session
        session.startRunning()
    }
    
    /// Update orientation for AVCaptureConnection so that CVImageBuffer pixels
    /// are rotated correctly in captureOutput(_:didOutput:from:)
    /// - Note: Even though rotation of pixel buffer is hardware accelerated,
    /// this is not the most effecient way of handling it. I was not able to test
    /// getting exif rotation based on device rotation, hence rotating the buffer
    /// I will update it in a near future
    @objc private func deviceOrientationDidChange(_ notification: Notification) {
        session?.outputs.forEach {
            $0.connections.forEach {
                $0.videoOrientation = UIDevice.current.videoOrientation
            }
        }
    }
    
}

@available(iOS 13.0, *)
extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        deviceOrientationDidChange(Notification(name: Notification.Name("")))
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        // merge UIImages begun
        let size = CGSize(width: 1080, height: 1080)
        UIGraphicsBeginImageContext(size)   // start to generate image context
        // create a single color image at bottom
        let bottomImage = UIImage(color: .red, size: CGSize(width: 1080, height: 1080))
        let areaSize = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        bottomImage!.draw(in: areaSize)
        
        // By changing cropSize, x, y, we can change the slice size and # of sliced images
        // ex: cropSize=256 -> x,y,need to be 0~3, and we can slice into 16 images. Then we can set the edge padding to 28 (1080%256=56,上下左右各補28 pixel)
        let cropSize:Int = 256
        let edgePadding: Int = 28
        // looping cropped pixelBuffer and make masks
        for x in 0...3{
            for y in 0...3{
                // crop pixelBuffer by x and y, with cropSize = cropSize
                guard let cropPixelBuffer = resizePixelBufferBiPlanar(pixelBuffer, cropRect: CGRect(x: edgePadding + x*cropSize, y: edgePadding + y*cropSize, width: cropSize, height: cropSize), scaleWidth: cropSize, scaleHeight: cropSize) else{return} // x: padding+x*cropSize
                
                // input PixelBuffer as input image into our model.
                let handler = VNImageRequestHandler(cvPixelBuffer: cropPixelBuffer)
                
                do {
                    try handler.perform([predictionRequest])
                } catch {
                    print(error)
                }
                // each prediction is now attached to the request
                // obtain model result
                guard let observations = predictionRequest.results as? [VNCoreMLFeatureValueObservation] else {
                    fatalError("unexpected result type from VNCoreMLRequest")
                }
                
                // making mask
                var mask: UIImage = UIImage()
                if let multiArray: MLMultiArray = observations[0].featureValue.multiArrayValue {
                    //print(multiArray.shape)
                    mask = maskToRGBA(maskArray: MultiArray<Float>(multiArray), rgba: (255, 255, 50, 80))!
                }
                // image: UIImage, merging mask and cropPixelBuffer
                let image = mergeMaskAndBackground(mask: mask, background: cropPixelBuffer, size: cropSize)!
                
                // copy cropped image onto bottemImage for merging
                image.draw(in: CGRect(x: edgePadding + x*cropSize, y: edgePadding + y*cropSize, width: cropSize, height: cropSize))

            }
        }
        
//        //----------------------original code before 5/23-----------
//        // 切右上角的256,256; resize成128,128; 丟進模型predict
//        guard let cropPixelBuffer = resizePixelBufferBiPlanar(pixelBuffer, cropRect: CGRect(x: 0, y: 0, width: cropSize, height: cropSize), scaleWidth: 128, scaleHeight: 128) else{return}
//
////        // setting sampleBuffer options for cameraIntrinsicData
////        var requestOptions: [VNImageOption: Any] = [:]
////        if let cameraIntrinsicData = CMGetAttachment(sampleBuffer, kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, nil) {
////            requestOptions = [.cameraIntrinsics: cameraIntrinsicData]
////        }
////        print(cropPixelBuffer)
//        // input PixelBuffer as input image into our model.
//        let handler = VNImageRequestHandler(cvPixelBuffer: cropPixelBuffer)
//        //let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: requestOptions) // 因為不知道requestOptions裡面的sampleBuffer要怎麼調 所以先槓掉，看起來func裡面的options不輸入好像也可以有正確的predict結果
//        do {
//            try handler.perform([predictionRequest])
//        } catch {
//            print(error)
//        }
//        // each prediction is now attached to the request
//        // obtain model result
//        guard let observations = predictionRequest.results as? [VNCoreMLFeatureValueObservation] else {
//            fatalError("unexpected result type from VNCoreMLRequest")
//        }
//        // print(observations[0]) // MultiArray : Float32 1 × 128 × 128 × 2 array
//        //print(observations[0].featureValue.multiArrayValue)
//        // convert to MLMultiArray and then convert to UIImage
//        var mask: UIImage = UIImage()
//        if let multiArray: MLMultiArray = observations[0].featureValue.multiArrayValue {
//            //print(multiArray.shape)
//            mask = maskToRGBA(maskArray: MultiArray<Float>(multiArray), rgba: (255, 255, 50, 100))!
//        }
//        
//        // image: UIImage
//        let image = mergeMaskAndBackground(mask: mask, background: cropPixelBuffer, size: cropSize)!
//        
//        // merge UIImages
//        let bottomImage = UIImage(color: .red, size: CGSize(width: 1080, height: 1080))
//        
//        var size = CGSize(width: 1080, height: 1080)
//        UIGraphicsBeginImageContext(size)
//
//        let areaSize = CGRect(x: 0, y: 0, width: size.width, height: size.height)
//        //bottomImage!.draw(in: areaSize)
//
//        image.draw(in: CGRect(x: 0, y: 0, width: cropSize, height: cropSize))
//        //--------------------original code before 5/23----------------

        var newImage:UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext() // end generating image context
        // merge UIImages done, newImage is the return Image
        
        // Display images
        DispatchQueue.main.async { [weak self] in
            //                self?.cameraPreview.image = image
            self?.predictionView.image = newImage
        }
    }
    
}

//func resizedCroppedImage(image: UIImage, newSize:CGSize) -> UIImage {
//    var ratio: CGFloat = 0
//    var delta: CGFloat = 0
//    var offset = CGPoint.zero
//    if image.size.width > image.size.height {
//        ratio = newSize.width / image.size.width
//        delta = (ratio * image.size.width) - (ratio * image.size.height)
//        offset = CGPoint(x: delta / 2, y: 0)
//    } else {
//        ratio = newSize.width / image.size.height
//        delta = (ratio * image.size.height) - (ratio * image.size.width)
//        offset = CGPoint(x: 0, y: delta / 2)
//    }
//    let clipRect = CGRect(x: -offset.x, y: -offset.y, width: (ratio * image.size.width) + delta, height: (ratio * image.size.height) + delta)
//    UIGraphicsBeginImageContextWithOptions(newSize, true, 0.0)
//    UIRectClip(clipRect)
//    image.draw(in: clipRect)
//    let newImage = UIGraphicsGetImageFromCurrentImageContext()
//    UIGraphicsEndImageContext()
//    return newImage!
//}

func cropImageToSquare(image: UIImage) -> UIImage? {
    var imageHeight = image.size.height
    var imageWidth = image.size.width
    
    if imageHeight > imageWidth {
        imageHeight = imageWidth
    }
    else {
        imageWidth = imageHeight
    }
    
    let size = CGSize(width: imageWidth, height: imageHeight)
    
    let refWidth : CGFloat = CGFloat(image.cgImage!.width)
    let refHeight : CGFloat = CGFloat(image.cgImage!.height)
    
    let x = (refWidth - size.width) / 2
    let y = (refHeight - size.height) / 2
    
    let cropRect = CGRect(x: x, y: y, width: size.height, height: size.width)
    if let imageRef = image.cgImage!.cropping(to: cropRect) {
        return UIImage(cgImage: imageRef, scale: 0, orientation: image.imageOrientation)
    }
    
    return nil
}
    
func mergeMaskAndBackground(mask: UIImage, background: CVPixelBuffer, size: Int) -> UIImage? {
    // Merge two images
    let sizeImage = CGSize(width: size, height: size)
    UIGraphicsBeginImageContext(sizeImage)
    
    let areaSize = CGRect(x: 0, y: 0, width: sizeImage.width, height: sizeImage.height)
    
    // background
    var background = UIImage(pixelBuffer: background)
    background = cropImageToSquare(image: background!)
    background?.draw(in: areaSize)
    // mask
    mask.draw(in: areaSize)
    
    let newImage:UIImage = UIGraphicsGetImageFromCurrentImageContext()!
    UIGraphicsEndImageContext()
    return newImage
}

func maskToRGBA(maskArray: MultiArray<Float>,
                rgba: (r: Double, g: Double, b: Double, a: Double)) -> UIImage? {
    // maskArray shape = [1, 128, 128, 2]
    let height = maskArray.shape[1] // 128
    let width = maskArray.shape[2]  // 128
    var bytes = [UInt8](repeating: 0, count: height * width * 4)
    
    for h in 0..<height {   // from 0~128
        for w in 0..<width {    // from 0~128
            let offset = h * width * 4 + w * 4
            let seg = maskArray[0, h, w, 0] // the value of that pixel:
            // seg == 1 -> this pixel is crack; seg==0 -> this pixel is background; seg can be 0.0~1.0
            var val = 0.0
            if (seg > 0.92){ // if seg > 0.9, identify this pixel as background
                val = 0.0
            }else{  // if seg > 0.5, identify this pixel as crack
                val = 1.0
            }
            bytes[offset + 0] = (val * rgba.r).toUInt8
            bytes[offset + 1] = (val * rgba.g).toUInt8
            bytes[offset + 2] = (val * rgba.b).toUInt8
            bytes[offset + 3] = (val * rgba.a).toUInt8
        }
    }
    return UIImage.fromByteArray(bytes, width: width, height: height,
                                 scale: 0, orientation: .up,
                                 bytesPerRow: width * 4,
                                 colorSpace: CGColorSpaceCreateDeviceRGB(),
                                 alphaInfo: .premultipliedLast)
}
