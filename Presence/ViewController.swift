/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 Main view controller for the AR experience.
 */

import ARKit
import SceneKit
import UIKit
import ScClient
import WebRTC

class ViewController: UIViewController, ARSessionDelegate {
    
    // MARK: Outlets
    
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var tabBar: UITabBar!
    @IBOutlet var connectButton: UIButton!
    @IBOutlet var channelIdText: UITextField!
    @IBOutlet var debugText: UILabel!
    
    private let config = Config.default
    private var webRTCClient: WebRTCClient {
        didSet {
            self.remoteCandidates = 0
        }
    }
    private let scClient: ScClient
    
    private var remoteCandidates: Int = 0
    
    private var channelId: String = "" {
        didSet {
            DispatchQueue.main.async {
                self.channelIdText.text = self.channelId
            }
            self.scClient.unsubscribe(channelName: "answer:" + oldValue)
            self.scClient.unsubscribe(channelName: "icecandidate:" + oldValue)
        }
    }
    
    private var readyToConnect: Bool = false {
        didSet {
            DispatchQueue.main.async {
                self.connectButton.isEnabled = self.readyToConnect
                self.channelIdText.isEnabled = self.readyToConnect
            }
        }
    }
    
    private var channelReady: Bool = false
    
    // MARK: Properties
    
    @IBAction func handleReset(_ sender: UIButton) {
        resetTracking()
    }
    @IBAction func handleConnect(_ sender: UIButton) {
        self.readyToConnect = false
        connectToWebRTC()
    }
    @IBAction func handleTap(_ sender: Any) {
        self.channelIdText.resignFirstResponder()
    }
    @IBAction func handleChannelIdChange(_ sender: Any) {
        channelId = channelIdText.text ?? ""
    }
    
    var contentControllers: [VirtualContentType: VirtualContentController] = [:]
    
    var selectedVirtualContent: VirtualContentType! {
        didSet {
            guard oldValue != nil, oldValue != selectedVirtualContent
                else { return }
            
            // Remove existing content when switching types.
            contentControllers[oldValue]?.contentNode?.removeFromParentNode()
            
            // If there's an anchor already (switching content), get the content controller to place initial content.
            // Otherwise, the content controller will place it in `renderer(_:didAdd:for:)`.
            if let anchor = currentFaceAnchor, let node = sceneView.node(for: anchor),
                let newContent = selectedContentController.renderer(sceneView, nodeFor: anchor) {
                node.addChildNode(newContent)
            }
        }
    }
    var selectedContentController: VirtualContentController {
        if let controller = contentControllers[selectedVirtualContent] {
            return controller
        } else {
            let controller = selectedVirtualContent.makeController()
            contentControllers[selectedVirtualContent] = controller
            return controller
        }
    }
    
    var currentFaceAnchor: ARFaceAnchor?
    
    init() {
        self.webRTCClient = WebRTCClient(iceServers: self.config.webRTCIceServers);
        self.scClient = ScClient(url: self.config.signalingServerUrl)
        super.init(nibName: String(describing: ViewController.self), bundle: Bundle.main)
    }
    
    required init?(coder aDecoder: NSCoder) {
        self.webRTCClient = WebRTCClient(iceServers: self.config.webRTCIceServers)
        self.scClient = ScClient(url: self.config.signalingServerUrl)
        super.init(coder: aDecoder)
    }
    
    deinit {
        self.scClient.disconnect()
    }
    
    // MARK: - View Controller Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        channelId = "RAVEN"
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.automaticallyUpdatesLighting = true
        
        // Set the initial face content.
        tabBar.selectedItem = tabBar.items![1]
        selectedVirtualContent = VirtualContentType(rawValue: tabBar.selectedItem!.tag)
        
        resetWebRTCClient()
        initializeSignal()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // AR experiences typically involve moving the device without
        // touch input for some time, so prevent auto screen dimming.
        UIApplication.shared.isIdleTimerDisabled = true
        
        // "Reset" to run the AR session for the first time.
        resetTracking()
    }
    
    // MARK: - ARSessionDelegate
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        guard error is ARError else { return }
        
        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")
        
        DispatchQueue.main.async {
            self.displayErrorMessage(title: "The AR session failed.", message: errorMessage)
        }
    }
    
    /// - Tag: ARFaceTrackingSetup
    func resetTracking() {
        guard ARFaceTrackingConfiguration.isSupported else { return }
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    // MARK: - Error handling
    
    func displayErrorMessage(title: String, message: String) {
        // Present an alert informing about the error that has occurred.
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
            alertController.dismiss(animated: true, completion: nil)
            self.resetTracking()
        }
        alertController.addAction(restartAction)
        present(alertController, animated: true, completion: nil)
    }
}

extension ViewController: UITabBarDelegate {
    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        guard let contentType = VirtualContentType(rawValue: item.tag)
            else { fatalError("unexpected virtual content tag") }
        selectedVirtualContent = contentType
    }
}

extension ViewController: ARSCNViewDelegate {
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }
        currentFaceAnchor = faceAnchor
        
        // If this is the first time with this anchor, get the controller to create content.
        // Otherwise (switching content), will change content when setting `selectedVirtualContent`.
        if node.childNodes.isEmpty, let contentNode = selectedContentController.renderer(renderer, nodeFor: faceAnchor) {
            node.addChildNode(contentNode)
        }
    }
    
    /// - Tag: ARFaceGeometryUpdate
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard anchor == currentFaceAnchor,
            let contentNode = selectedContentController.contentNode,
            contentNode.parent == node
            else { return }
        
        let position = contentNode.worldPosition;
        let orientation = contentNode.worldOrientation;
        let x = position.x;
        let y = position.y;
        let z = position.z;
        
        let rotation = orientation.toEuler()
        let X = rotation.x;
        let Y = rotation.y;
        let Z = rotation.z;
        
        DispatchQueue.main.async {
            let x_ = String(format: "%.03f", x);
            let y_ = String(format: "%.03f", y);
            let z_ = String(format: "%.03f", z);
            let X_ = String(format: "%.02f", X);
            let Y_ = String(format: "%.02f", Y);
            let Z_ = String(format: "%.02f", Z);
            
            self.debugText.text = #"x: \#(x_), y: \#(y_), z: \#(z_)"# + "\n" + #"rx: \#(X_), ry: \#(Y_), rz: \#(Z_)"#;
        }
        
        selectedContentController.renderer(renderer, didUpdate: contentNode, for: anchor)
        
        if channelReady {
            let pose = PoseMessage(x: x, y: y, z: z, rx: X, ry: Y, rz: Z)
            webRTCClient.sendData(pose.toJSONString()!.data(using: .ascii)!)
        }
    }
}

extension ViewController {
    func initializeSignal() {
        self.scClient.setBasicListener(onConnect: onConnect, onConnectError: onConnectError, onDisconnect: onDisconnect)
        self.scClient.setAuthenticationListener(onSetAuthentication: onSetAuthentication, onAuthentication: onAuthentication)
        self.scClient.connect()
    }
    
    func onConnect(client: ScClient) {
        print("Connected to signalling server")
    }
    
    func onConnectError(client: ScClient, error: Error?) {
        print("Failed to connect to signalling server:", error?.localizedDescription as Any)
    }
    
    func onDisconnect(client: ScClient, error: Error?) {
        print("Disconnected from signalling server:", error?.localizedDescription as Any)
    }
    
    func onSetAuthentication(client: ScClient, token: String?) {
        print("Authentication token:", token as Any)
    }
    func onAuthentication(client: ScClient, isAuthenticated: Bool?) {
        print("Authentication:", isAuthenticated as Any)
        self.readyToConnect = true
    }
    
    func resetWebRTCClient() {
        self.webRTCClient = WebRTCClient(iceServers: self.config.webRTCIceServers)
        self.webRTCClient.delegate = self
    }
    
    func handleChannel(channelName: String, data: AnyObject?) {
        if channelName.starts(with: "icecandidate") {
            remoteCandidates += 1
            if let c = (data as! NSDictionary)["candidate"] as! NSDictionary? {
                let candidate = IceCandidate(from: c);
                debugPrint("Received ICE candidate", remoteCandidates)
                self.webRTCClient.set(remoteCandidate: candidate.rtcIceCandidate)
            }
        }
    }
    
    func connectToWebRTC() {
        self.resetWebRTCClient()
        
        self.scClient.onChannel(channelName: "icecandidate:" + self.channelId, ack: handleChannel)
        self.scClient.subscribe(channelName: "icecandidate:" + self.channelId)
        
        self.scClient.emitAck(eventName: "signal", data: ["channelId": self.channelId] as AnyObject) { (eventName: String, error: AnyObject?, response: AnyObject?) in
            if !(error is NSNull) {
                debugPrint("Signal error:", error as AnyObject)
                return
            }
            
            if (response is NSNull) {
                fatalError("No existing offers")
            }
            
            debugPrint("Retrieved offer")
            let signal = response as! NSDictionary
            let existingOffer = signal["offer"] as! NSDictionary
            let sdp = existingOffer["sdp"] as! String
            let remoteSdp = RTCSessionDescription(type: .offer, sdp: sdp)
            
            self.webRTCClient.set(remoteSdp: remoteSdp) { (e: Error?) in
                if let e_ = e {
                    debugPrint("Error with remote SDP", e_ as AnyObject)
                    return
                }
                self.webRTCClient.answer { (localSdP: RTCSessionDescription) in
                    debugPrint("Sending answer")
                    var answer = Offer(rtcSdp: localSdP)
                    answer.type = "answer"
                    self.scClient.publish(channelName: "answer:" + self.channelId, data: ["answer": answer.toJSON()] as AnyObject)
                }
            }
        }
    }
}

extension ViewController: WebRTCClientDelegate {
    func webRTCClient(_ client: WebRTCClient, didDiscoverLocalCandidate candidate: RTCIceCandidate) {
        let c = IceCandidate(from: candidate)
        self.scClient.publish(channelName: "icecandidate:" + self.channelId, data: ["candidate" : c.toJSON()] as AnyObject)
    }
    
    func webRTCClient(_ client: WebRTCClient, didChangeConnectionState state: RTCIceConnectionState) {
        switch (state) {
        case .connected:
            self.channelReady = true
            break
        case .new:
            break
        case .checking:
            break
        case .completed:
            break
        case .failed:
            break
        case .disconnected:
            self.readyToConnect = true
            break
        case .closed:
            break
        case .count:
            break
        @unknown default:
            fatalError("Unknown state")
        }
        debugPrint("WebRTC connection state:", state as AnyObject)
    }
    
    func webRTCClient(_ client: WebRTCClient, didReceiveData data: Data) {
        debugPrint("data received", data)
    }
    
    
}
