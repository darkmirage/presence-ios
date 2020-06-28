/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Main view controller for the AR experience.
*/

import ARKit
import SceneKit
import UIKit
import WebRTC

class ViewController: UIViewController, ARSessionDelegate {
    
    // MARK: Outlets

    @IBOutlet var debugText: UITextView!
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var tabBar: UITabBar!

    // MARK: Properties

    @IBAction func handleClick(_ sender: UIButton) {
        resetTracking();
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
    
    // MARK: - View Controller Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.automaticallyUpdatesLighting = true
        
        // Set the initial face content.
        tabBar.selectedItem = tabBar.items![1];
        selectedVirtualContent = VirtualContentType(rawValue: tabBar.selectedItem!.tag)
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
    
    func quaternionToEuler(_ quaternion: SCNQuaternion) -> SCNVector3 {
        let x = quaternion.x;
        let y = quaternion.y;
        let z = quaternion.z;
        let w = quaternion.w;
        let t0 = +2.0 * (w * x + y * z)
        let t1 = +1.0 - 2.0 * (x * x + y * y)
        let X = atan2(t0, t1)

        var t2 = +2.0 * (w * y - z * x)
        t2 = t2 > +1.0 ? +1.0 : t2
        t2 = t2 < -1.0 ? -1.0 : t2
        let Y = asin(t2)

        let t3 = +2.0 * (w * z + x * y)
        let t4 = +1.0 - 2.0 * (y * y + z * z)
        let Z = atan2(t3, t4)

        return SCNVector3(X, Y, Z);
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
        
        let rotation = quaternionToEuler(orientation);
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
    }
}

