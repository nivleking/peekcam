import AVFoundation
import PeekCamCore

/// The camera behind the preview. A protocol so the service can be driven without hardware.
@MainActor
protocol CameraSession: AnyObject {
    /// Shows the frames. Rendered by the GPU; no frame is copied into our memory.
    var previewLayer: AVCaptureVideoPreviewLayer { get }
    func start(camera: CameraInfo, mirror: Bool)
    func setMirror(_ mirror: Bool)
    /// One full-resolution still, exactly as the sensor sees it (never mirrored).
    func capturePhoto(_ done: @escaping @MainActor (CGImage?) -> Void)
    /// Tears everything down so the camera light goes off and memory drops back to idle.
    func stop()
}

@MainActor
final class AVCameraSession: CameraSession {
    let previewLayer = AVCaptureVideoPreviewLayer()
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

    func start(camera: CameraInfo, mirror: Bool) {
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
        previewLayer.session = nil
        queue.async { session.stopRunning() }
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
