//
//  ViewController.swift
//  ios-camera-video-save-to-file-by-frames
//
//  Created by Zhaonan Li on 8/13/16.
//  Copyright © 2016 Zhaonan Li. All rights reserved.
//

import UIKit
import GLKit
import Photos
import AVFoundation

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var videoCaptureStatusLabel: UILabel!
    @IBOutlet weak var startRecordVideoBtn: UIButton!
    @IBOutlet weak var finishRecordVideoBtn: UIButton!
    
    lazy var lastSampleTime: CMTime = {
        let lastSampleTime = kCMTimeZero
        return lastSampleTime
    }()
    
    lazy var glContext: EAGLContext = {
        let glContext = EAGLContext(API: .OpenGLES2)
        return glContext
    }()
    
    lazy var glView: GLKView = {
        let glView = GLKView(
        frame: CGRect(
            x: 0,
            y: 0,
            width: self.cameraView.bounds.width,
            height: self.cameraView.bounds.height),
        context: self.glContext)
        
        glView.bindDrawable()
        return glView
    }()
    
    lazy var ciContext: CIContext = {
        let ciContext = CIContext(EAGLContext: self.glContext)
        return ciContext
    }()
    
    lazy var cameraSession: AVCaptureSession = {
        let session = AVCaptureSession()
        session.sessionPreset = AVCaptureSessionPresetPhoto
        return session
    }()
    
    lazy var isRecordingVideo: Bool = {
        let isRecordingVideo = false
        return isRecordingVideo
    }()
    
    var videoOutputFullFileName: String?
    var videoWriterInput: AVAssetWriterInput?
    var videoWriter: AVAssetWriter?
    
    
    
    
    
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        setupCameraSession()
    }
    
    override func viewDidAppear(animated: Bool) {
        self.cameraView.addSubview(self.glView)
        cameraSession.startRunning()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    
    
    
    @IBAction func startRecordVideo(sender: AnyObject) {
        
        let documentsPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0]
        self.videoOutputFullFileName = documentsPath.stringByAppendingString("/test_camera_capture_video.m4v")
        
        if self.videoOutputFullFileName == nil {
            print("Error:The video output file name is nil")
            return
        }
        
        self.isRecordingVideo = true
        self.videoCaptureStatusLabel.text = "Recording Video"
        
        let fileManager = NSFileManager.defaultManager()
        if fileManager.fileExistsAtPath(self.videoOutputFullFileName!) {
            print("WARN:::The file: \(self.videoOutputFullFileName!) exists, will delete the existing file")
            do {
                try fileManager.removeItemAtPath(self.videoOutputFullFileName!)
            } catch let error as NSError {
                print("WARN:::Cannot delete existing file: \(self.videoOutputFullFileName!), error: \(error.debugDescription)")
            }
            
        } else {
            print("DEBUG:::The file \(self.videoOutputFullFileName!) not exists")
        }
        

        // AVVideoAverageBitRateKey is for pecifying a key to access the average bit rate (as bits per second) used in encoding.
        // This video shoule be video size * a float number, and here 10.1 is equal to AVCaptureSessionPresetHigh.
        let videoCompressionPropertys = [
            AVVideoAverageBitRateKey: self.cameraView.bounds.width * self.cameraView.bounds.height * 10.1
        ]
        
        let videoSettings: [String: AnyObject] = [
            AVVideoCodecKey: AVVideoCodecH264,
            AVVideoWidthKey: self.cameraView.bounds.width,
            AVVideoHeightKey: self.cameraView.bounds.height,
            AVVideoCompressionPropertiesKey:videoCompressionPropertys
        ]
        
        
        self.videoWriterInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: videoSettings)
        self.videoWriterInput!.expectsMediaDataInRealTime = true
        
        
        //        let sourcePixelBufferAttributes = [
        //            kCVPixelBufferPixelFormatTypeKey as String: NSNumber(unsignedInt: kCVPixelFormatType_32BGRA),
        //            kCVPixelBufferWidthKey as String: NSNumber(int: Int32(self.cameraView.bounds.width)),
        //            kCVPixelBufferHeightKey as String: NSNumber(int: Int32(self.cameraView.bounds.height))
        //        ]
        //
        //        self.videoWriterInputPixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
        //            assetWriterInput: self.videoWriterInput,
        //            sourcePixelBufferAttributes: sourcePixelBufferAttributes
        //        )
        
        do {
            self.videoWriter = try AVAssetWriter(URL: NSURL(fileURLWithPath: self.videoOutputFullFileName!), fileType: AVFileTypeMPEG4)
        } catch let error as NSError {
            print("ERROR:::::>>>>>>>>>>>>>Cannot init videoWriter, error:\(error.localizedDescription)")
        }
        
        
        if self.videoWriter!.canAddInput(self.videoWriterInput!) {
            self.videoWriter!.addInput(self.videoWriterInput!)
        } else {
            print("ERROR:::Cannot add videoWriterInput into videoWriter")
        }
        
        
        if self.videoWriter!.status != AVAssetWriterStatus.Writing {
            
            print("DEBUG::::::::::::::::The videoWriter status is not writing, and will start writing the video.")
            
            let hasStartedWriting = self.videoWriter!.startWriting()
            if hasStartedWriting {
                self.videoWriter!.startSessionAtSourceTime(self.lastSampleTime)
                print("DEBUG:::Have started writting on videoWriter, session at source time: \(self.lastSampleTime)")
            } else {
                print("WARN:::Fail to start writing on videoWriter")
            }
            
            
            
        } else {
            print("WARN:::The videoWriter.status is writting now, so cannot start writing action on videoWriter")
        }
    }
    
    @IBAction func finishRecordVideo(sender: AnyObject) {
        self.isRecordingVideo = false
        self.videoCaptureStatusLabel.text = "Previewing"
        
        self.videoWriterInput!.markAsFinished()
        self.videoWriter!.finishWritingWithCompletionHandler {
            
            if self.videoWriter!.status == AVAssetWriterStatus.Completed {
                print("DEBUG:::The videoWriter status is completed")
                
                let fileManager = NSFileManager.defaultManager()
                if fileManager.fileExistsAtPath(self.videoOutputFullFileName!) {
                    print("DEBUG:::The file: \(self.videoOutputFullFileName) has been save into documents folder, and is ready to be moved to camera roll")
                    PHPhotoLibrary.sharedPhotoLibrary().performChanges({
                        PHAssetChangeRequest.creationRequestForAssetFromVideoAtFileURL(NSURL(fileURLWithPath: self.videoOutputFullFileName!))
                    }) { completed, error in
                        if completed {
                            print("Video \(self.videoOutputFullFileName) has been moved to camera roll")
                        }
                        
                        if error != nil {
                            print ("ERROR:::Cannot move the video \(self.videoOutputFullFileName) to camera roll, error: \(error!.localizedDescription)")
                        }
                    }
                } else {
                    print("ERROR:::The file: \(self.videoOutputFullFileName) not exists, so cannot move this file camera roll")
                }
            } else {
                print("WARN:::The videoWriter status is not completed, stauts: \(self.videoWriter!.status)")
            }
        }
    }
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    

    
    
    
    
    
    
    
    
    
    
    
    
    
    func setupCameraSession() {
        let captureDevice = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo) as AVCaptureDevice
        
        do {
            self.cameraSession.beginConfiguration()
            
            let deviceInput = try AVCaptureDeviceInput(device: captureDevice)
            if self.cameraSession.canAddInput(deviceInput) {
                self.cameraSession.addInput(deviceInput)
            }
            
            let dataOutput = AVCaptureVideoDataOutput()
            dataOutput.videoSettings = [
                (kCVPixelBufferPixelFormatTypeKey as NSString) : NSNumber(unsignedInt: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
            ]
            dataOutput.alwaysDiscardsLateVideoFrames = true
            if self.cameraSession.canAddOutput(dataOutput) {
                self.cameraSession.addOutput(dataOutput)
            }
            
            self.cameraSession.commitConfiguration()
            
            let videoStreamingQueue = dispatch_queue_create("com.somedomain.videoStreamingQueue", DISPATCH_QUEUE_SERIAL)
            dataOutput.setSampleBufferDelegate(self, queue: videoStreamingQueue)
            
        } catch let error as NSError {
            NSLog("\(error), \(error.localizedDescription)")
        }
    }
    
    // Implement the delegate method
    // Interface: AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        // Here we can collect the frames, and process them.
        
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        self.lastSampleTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        
        
        // Append the sampleBuffer into videoWriterInput
        if self.isRecordingVideo {
            if self.videoWriterInput!.readyForMoreMediaData {
                
                if self.videoWriter!.status == AVAssetWriterStatus.Writing {
                    let whetherAppendSampleBuffer = self.videoWriterInput!.appendSampleBuffer(sampleBuffer)
                    
                    print(">>>>>>>>>>>>>The time::: \(self.lastSampleTime.value)/\(self.lastSampleTime.timescale)")
                    
                    if whetherAppendSampleBuffer {
                        print("DEBUG::: Append sample buffer successfully")
                    } else {
                        print("WARN::: Append sample buffer failed")
                    }
                } else {
                    print("WARN:::The videoWriter status is not writing")
                }
                
                
            } else {
                print("WARN:::Cannot append sample buffer into videoWriterInput")
            }
            
//            let fps: Int32 = 30
//            let frameDuration = CMTimeMake(1, fps)
//            let lastFrameTime = CMTimeMake(self.frameCounter, fps)
//            let presentationTime = self.frameCounter == 0 ? lastFrameTime : CMTimeAdd(lastFrameTime, frameDuration)
//            
//            if self.videoWriterInputPixelBufferAdaptor.assetWriterInput.readyForMoreMediaData {
//                let whetherPixelBufferAppendedtoAdaptor = self.videoWriterInputPixelBufferAdaptor.appendPixelBuffer(pixelBuffer!, withPresentationTime: presentationTime)
//                
//                if whetherPixelBufferAppendedtoAdaptor {
//                    print("DEBUG:::PixelBuffer appended adaptor successfully")
//                } else {
//                    print("WARN:::PixelBuffer appended adapotr failed")
//                }
//                
//                
//                self.frameCounter += 1
//                
//                print("DEBUG:::The current frame counter = \(self.frameCounter)")
//            } else {
//                print("WARN:::The assetWriterInput is not ready")
//            }
        }
        
        
        let ciImage = CIImage(CVPixelBuffer: pixelBuffer!)
        
        // Rotate the ciImage 90 degrees to right.
        var affineTransform = CGAffineTransformMakeTranslation(ciImage.extent.width / 2, ciImage.extent.height / 2)
        affineTransform = CGAffineTransformRotate(affineTransform, CGFloat(-1 * M_PI_2))
        affineTransform = CGAffineTransformTranslate(affineTransform, -ciImage.extent.width / 2, -ciImage.extent.height / 2)
        
        let transformFilter = CIFilter(
            name: "CIAffineTransform",
            withInputParameters: [
                kCIInputImageKey: ciImage,
                kCIInputTransformKey: NSValue(CGAffineTransform: affineTransform)
            ]
        )
        
        let transformedCIImage = transformFilter!.outputImage!
        
        let scale = UIScreen.mainScreen().scale
        let previewImageFrame = CGRectMake(0, 0, self.cameraView.frame.width * scale, self.cameraView.frame.height * scale)
        
        // Draw the transformedCIImage sized by previewImageFrame on GLKView.
        if self.glContext != EAGLContext.currentContext() {
            EAGLContext.setCurrentContext(self.glContext)
        }
        self.glView.bindDrawable()
        self.ciContext.drawImage(transformedCIImage, inRect: previewImageFrame, fromRect: transformedCIImage.extent)
        self.glView.display()
        
    }
    
    // Implement the delegate method
    // Interface: AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(captureOutput: AVCaptureOutput!, didDropSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        // Here we can deal with the frames have been droped.
    }
}
