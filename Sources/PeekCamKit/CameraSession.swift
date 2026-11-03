import AVFoundation
import Darwin
import PeekCamCore

/// The camera behind the preview. A protocol so the service can be driven without hardware.
@MainActor
protocol CameraSession: AnyObject {
    /// Shows the frames. Rendered by the GPU; no frame is copied into our memory.
    var previewLayer: AVCaptureVideoPreviewLayer { get }
    /// Called on the main actor with a 0...1 level while a microphone is running.
    var onLevel: (@MainActor (Double) -> Void)? { get set }
    /// `microphone` adds a level meter input; the caller checks the permission first.
    func start(camera: CameraInfo, mirror: Bool, microphone: Bool)
    func setMirror(_ mirror: Bool)
    /// One full-resolution still, exactly as the sensor sees it (never mirrored).
    func capturePhoto(_ done: @escaping @MainActor (CGImage?) -> Void)
    /// Tears everything down so the camera light goes off and memory drops back to idle.
    func stop()
}

@MainActor
final class AVCameraSession: CameraSession {
    let previewLayer = AVCaptureVideoPreviewLayer()
    var onLevel: (@MainActor (Double) -> Void)?
    private var meter: LevelMeter?
    private var session: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    /// Each capture keeps its delegate alive until the photo arrives.
    private var pendingPhotos: [PhotoDelegate] = []
    /// startRunning/stopRunning block for a few hundred ms, so they stay off the main thread.
    private let queue = DispatchQueue(label: "dev.kelvin.PeekCam.camera")

    init() {
        previewLayer.videoGravity = .resizeAspectFill
    }

    static var cameras: [CameraInfo] {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
            mediaType: .video, position: .unspecified
        ).devices.map {
            CameraInfo(id: $0.uniqueID, name: $0.localizedName, isBuiltIn: $0.deviceType == .builtInWideAngleCamera)
        }
    }

    func start(camera: CameraInfo, mirror: Bool, microphone: Bool) {
        stop()
        guard let device = AVCaptureDevice(uniqueID: camera.id),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        let session = AVCaptureSession()
        session.beginConfiguration()
        session.sessionPreset = session.canSetSessionPreset(.high) ? .high : .medium
        if session.canAddInput(input) { session.addInput(input) }
        // Added up front: adding it on the first snap would reconfigure the running session
        // and blank the preview for a moment. It holds no buffers until a photo is taken.
        let photo = AVCapturePhotoOutput()
        if session.canAddOutput(photo) {
            session.addOutput(photo)
            photoOutput = photo
        }
        if microphone, let mic = AVCaptureDevice.default(for: .audio),
           let micInput = try? AVCaptureDeviceInput(device: mic), session.canAddInput(micInput) {
            let output = AVCaptureAudioDataOutput()
            if session.canAddOutput(output) {
                session.addInput(micInput)
                session.addOutput(output)
                let meter = LevelMeter { [weak self] level in
                    Task { @MainActor in self?.onLevel?(level) }
                }
                output.setSampleBufferDelegate(meter, queue: queue)
                self.meter = meter
            }
        }
        session.commitConfiguration()
        previewLayer.session = session
        setMirror(mirror)
        self.session = session
        queue.async { session.startRunning() }
    }

    func setMirror(_ mirror: Bool) {
        guard let connection = previewLayer.connection, connection.isVideoMirroringSupported else { return }
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = mirror
    }

    func stop() {
        guard let session else { return }
        self.session = nil
        photoOutput = nil
        meter = nil
        previewLayer.session = nil
        queue.async {
            session.stopRunning()
            // Capture start touches tens of MB of framework heap; give the freed pages back
            // (and drop the swapped ones) so the footprint returns to idle.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { _ = malloc_zone_pressure_relief(nil, 0) }
        }
    }

    func capturePhoto(_ done: @escaping @MainActor (CGImage?) -> Void) {
        guard let photoOutput, session?.isRunning == true else { return done(nil) }
        var delegate: PhotoDelegate!
        delegate = PhotoDelegate { [weak self] image in
            self?.pendingPhotos.removeAll { $0 === delegate }
            done(image)
        }
        pendingPhotos.append(delegate)
        photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: delegate)
    }
}

private final class PhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let done: @MainActor (CGImage?) -> Void

    init(done: @escaping @MainActor (CGImage?) -> Void) {
        self.done = done
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let image = error == nil ? photo.cgImageRepresentation() : nil
        Task { @MainActor in done(image) }
    }
}

/// Turns microphone buffers into a smoothed 0...1 level, about every 10 ms.
/// Only the level leaves this class; no audio is stored or played.
private final class LevelMeter: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let report: @Sendable (Double) -> Void
    private var level = 0.0
    private var lastReport = Date.distantPast

    init(report: @escaping @Sendable (Double) -> Void) {
        self.report = report
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let samples = Self.samples(in: sampleBuffer) else { return }
        level = AudioLevel.smoothed(previous: level, new: AudioLevel.meter(rms: AudioLevel.rms(of: samples)))
        // 20 updates a second is plenty for a meter.
        let now = Date()
        guard now.timeIntervalSince(lastReport) >= 0.05 else { return }
        lastReport = now
        report(level)
    }

    /// Reads the buffer as 16-bit or 32-bit float PCM and returns samples in -1...1.
    private static func samples(in buffer: CMSampleBuffer) -> [Float]? {
        guard let format = CMSampleBufferGetFormatDescription(buffer),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(format)?.pointee,
              let block = CMSampleBufferGetDataBuffer(buffer) else { return nil }
        var length = 0
        var pointer: UnsafeMutablePointer<Int8>?
        guard CMBlockBufferGetDataPointer(block, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length,
                                          dataPointerOut: &pointer) == kCMBlockBufferNoErr, let pointer else { return nil }
        let isFloat = asbd.mFormatFlags & kAudioFormatFlagIsFloat != 0
        if isFloat && asbd.mBitsPerChannel == 32 {
            let count = length / 4
            return pointer.withMemoryRebound(to: Float.self, capacity: count) { Array(UnsafeBufferPointer(start: $0, count: count)) }
        }
        if !isFloat && asbd.mBitsPerChannel == 16 {
            let count = length / 2
            return pointer.withMemoryRebound(to: Int16.self, capacity: count) { p in
                (0..<count).map { Float(p[$0]) / 32768 }
            }
        }
        return nil
    }
}
