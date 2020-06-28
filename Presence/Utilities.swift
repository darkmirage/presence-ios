/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Convenience extensions for system types.
*/

import ARKit
import SceneKit

extension SCNMatrix4 {
    /**
     Create a 4x4 matrix from CGAffineTransform, which represents a 3x3 matrix
     but stores only the 6 elements needed for 2D affine transformations.
     
     [ a  b  0 ]     [ a  b  0  0 ]
     [ c  d  0 ]  -> [ c  d  0  0 ]
     [ tx ty 1 ]     [ 0  0  1  0 ]
     .               [ tx ty 0  1 ]
     
     Used for transforming texture coordinates in the shader modifier.
     (Needs to be SCNMatrix4, not SIMD float4x4, for passing to shader modifier via KVC.)
     */
    init(_ affineTransform: CGAffineTransform) {
        self.init()
        m11 = Float(affineTransform.a)
        m12 = Float(affineTransform.b)
        m21 = Float(affineTransform.c)
        m22 = Float(affineTransform.d)
        m41 = Float(affineTransform.tx)
        m42 = Float(affineTransform.ty)
        m33 = 1
        m44 = 1
    }
}

extension SCNReferenceNode {
    convenience init(named resourceName: String, loadImmediately: Bool = true) {
        let url = Bundle.main.url(forResource: resourceName, withExtension: "scn", subdirectory: "Models.scnassets")!
        self.init(url: url)!
        if loadImmediately {
            self.load()
        }
    }
}

extension SCNQuaternion {
    func toEuler() -> SCNVector3 {
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
}
