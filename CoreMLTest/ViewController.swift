//
//  ViewController.swift
//  CoreMLTest
//
//  Created by Ilya Sysoi on 11/19/18.
//  Copyright © 2018 BeSmart-Mobile. All rights reserved.
//

import UIKit
import AVFoundation
import Vision
import SnapKit

class ViewController: UIViewController {

    private var resultLabel: UILabel!
    private var resultView: UIView!
    
    let session = AVCaptureSession()
    var previewLayer: AVCaptureVideoPreviewLayer!
    let captureQueue = DispatchQueue(label: "captureQueue")
    var visionRequests = [VNRequest]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        initAndConfigureSubviews()
        setupCamera()
    }
    
    private func initAndConfigureSubviews() {
        resultLabel = UILabel()
        resultView = UIView()
        
        resultLabel.numberOfLines = 0
        resultLabel.font = UIFont.boldSystemFont(ofSize: 40)
        resultLabel.backgroundColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
        resultLabel.textColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
        resultLabel.textAlignment = .center
        
        [resultView, resultLabel].forEach {
            view.addSubview($0)
        }
        
        resultLabel.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottomMargin)
            make.height.equalTo(60)
        }
        
        resultView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.topMargin)
            make.left.right.equalToSuperview()
            make.bottom.equalTo(resultView.snp.top)
        }

    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.frame
    }
    
    private func setupCamera() {
        guard let camera = AVCaptureDevice.default(for: .video) else {
            return
        }
        do {
            previewLayer = AVCaptureVideoPreviewLayer(session: session)
            resultView.layer.addSublayer(previewLayer)
            
            let cameraInput = try AVCaptureDeviceInput(device: camera)
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.setSampleBufferDelegate(self,
                                                queue: captureQueue)
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            
            session.sessionPreset = .high
            session.addInput(cameraInput)
            session.addOutput(videoOutput)
            
            let connection = videoOutput.connection(with: .video)
            connection?.videoOrientation = .portrait
            session.startRunning()
            
            guard let visionModel = try? VNCoreMLModel(for: Inceptionv3().model) else {
                fatalError("Could not load model")
            }
            
            let classificationRequest = VNCoreMLRequest(model: visionModel, completionHandler: handleClassifications)
            classificationRequest.imageCropAndScaleOption = VNImageCropAndScaleOption.centerCrop
            visionRequests = [classificationRequest]
        } catch {
            let alertController = UIAlertController(title: nil, message: error.localizedDescription, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
            present(alertController, animated: true, completion: nil)
        }
    }
    
    private func handleClassifications(request: VNRequest, error: Error?) {
        if let error = error {
            print(error.localizedDescription)
            return
        }
        guard let results = request.results as? [VNClassificationObservation] else {
            print("No results")
            return
        }
        
        let resultString = String(
            format: "Это%@часы",
            results[0...3]
                .map {
                    $0.identifier.lowercased()
                }
                .filter {
                    print($0)
                    return $0.range(of: "clock") != nil
                }.count == 0 ? " не " : " ")
        
        DispatchQueue.main.async {
            self.resultLabel.text = resultString
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        var requestOptions: [VNImageOption: Any] = [:]
        if let cameraIntrinsicData = CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil) {
            requestOptions = [.cameraIntrinsics: cameraIntrinsicData]
        }
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: CGImagePropertyOrientation.up, options: requestOptions)
        do {
            try imageRequestHandler.perform(visionRequests)
        } catch {
            print(error)
        }
    }
}
