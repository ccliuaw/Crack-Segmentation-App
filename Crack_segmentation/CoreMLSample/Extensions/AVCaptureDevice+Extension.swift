//
//  AVCaptureDevice.swift
//  MLCamera
//
//  Created by Michael Inger on 13/06/2017.
//  Copyright © 2017 stringCode ltd. All rights reserved.
//

import Foundation
import AVFoundation

extension AVCaptureDevice {
    
    /// Requests permission for AVCaptureDevice video access
    /// - parameter completion: Called on the main queue
    class func requestAuthorization(completion: @escaping (_ granted: Bool)->() ) {
        AVCaptureDevice.requestAccess(for: .video) { (granted) in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }
    
    // set frame rate
    func setFrameRate(frameRate: Double) {
        guard let range = activeFormat.videoSupportedFrameRateRanges.first,
            range.minFrameRate...range.maxFrameRate ~= frameRate
            else {
                print("Requested FPS is not supported by the device's activeFormat !")
                return
        }

        do { try lockForConfiguration()
            activeVideoMinFrameDuration = CMTimeMake(1, Int32(frameRate))
            activeVideoMaxFrameDuration = CMTimeMake(1, Int32(frameRate))
            unlockForConfiguration()
        } catch {
            print("LockForConfiguration failed with error: \(error.localizedDescription)")
        }
      }
}
