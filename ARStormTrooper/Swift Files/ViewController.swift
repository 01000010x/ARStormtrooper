//
//  ViewController.swift
//  ARStormTrooper
//
//  Created by Baptiste Leguey on 10/12/2017.
//  Copyright © 2017 Baptiste Leguey. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController {

    // MARK: IBOutlets

    @IBOutlet weak var planeDetectedLabel: UILabel!
    @IBOutlet var sceneView: ARSCNView!

    // MARK: Properties

    var animations: [String: CAAnimation] = [:]
    var animationGroups: [String: CAAnimationGroup] = [:]
    var idle: Bool = true
    var isPlaneDetected: Bool = false
    var isCharacterPlaced = false
    let stormtrooperNode = SCNNode()
    var recordedCameraPosition = SCNVector3(0, 0, 0)
    var headTapCount = 0
    var torsoTapCount = 0

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        sceneView.delegate = self

        // Hide plane detected label until a plane is detected
        planeDetectedLabel.isHidden = true

        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene()
        
        // Set the scene to the view
        sceneView.scene = scene
        sceneView.autoenablesDefaultLighting = true
        sceneView.automaticallyUpdatesLighting = true

        sceneView.debugOptions = [ARSCNDebugOptions.showWorldOrigin, ARSCNDebugOptions.showFeaturePoints]

        // Add a tap gesture recognizer to place a character
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        let slideGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handleSlide))
        sceneView.addGestureRecognizer(tapGestureRecognizer)
        sceneView.addGestureRecognizer(slideGestureRecognizer)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        configuration.isLightEstimationEnabled = true

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
}

// MARK: ARKit SceneView delegate

extension ViewController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard anchor is ARPlaneAnchor else { return }
        DispatchQueue.main.async {
            self.planeDetectedLabel.isHidden = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.planeDetectedLabel.isHidden = true
        }
    }

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        manageModelRotation()
    }
}

// MARK: Gestures Helper

extension ViewController {
    @objc func handleTap(sender: UITapGestureRecognizer) {
        if isCharacterPlaced {
            // let's test if a 3d object was touched
            var hitTestOptions = [SCNHitTestOption: Any]()
            hitTestOptions[SCNHitTestOption.boundingBoxOnly] = false
            let hitResults: [SCNHitTestResult] = sceneView.hitTest(sender.location(in: sceneView), options: hitTestOptions)

            if hitResults.first != nil {
                switch headTapCount {
                case 0:
                    playAnimation(key: ModelAnimations.Punched.rawValue)
                    headTapCount = 1
                case 1:
                    playGroupAnimation(key: ModelAnimationGroups.TapHead.rawValue)
                    headTapCount = 2
                case 2:
                    playGroupAnimation(key: ModelAnimationGroups.TapHeadAgain.rawValue)
                    headTapCount = 0
                default: playAnimation(key: ModelAnimations.NeutralIdle.rawValue)
                }
            }
        } else {
            placeCharacter(atLocation: sender.location(in: sceneView))
        }
    }

    @objc func handleSlide(sender: UIPanGestureRecognizer) {
        guard let direction = sender.direction else { return }

        if direction.isVertical {
            playGroupAnimation(key: ModelAnimationGroups.Backflip.rawValue)
        } else {
            playAnimation(key: ModelAnimations.Spin.rawValue)
        }
    }

    func setAllGesturesStatus(onView view: UIView, withValue value: Bool) {
        if let gestures = view.gestureRecognizers {
            for gesture in gestures {
                gesture.isEnabled = value
            }
        }
    }
}

// MARK: Animation Helper

extension ViewController {
    func loadAnimation(withKey: String, sceneName: String, animationIdentifier: String) {
        guard let sceneURL = Bundle.main.url(forResource: sceneName, withExtension: "dae") else {
            print("impossible to create a scene url with that name: \(sceneName)")
            return
        }

        let sceneSource = SCNSceneSource(url: sceneURL, options: nil)

        if let animationObject = sceneSource?.entryWithIdentifier(animationIdentifier, withClass: CAAnimation.self) {
            // The animation will only play once except if it's an Idle animation
            if (withKey == ModelAnimations.AgitatedIdle.rawValue ||
                withKey == ModelAnimations.NeutralIdle.rawValue) {
                    animationObject.repeatCount = .greatestFiniteMagnitude
            } else {
                animationObject.repeatCount = 1
            }

            // To create smooth transition between animations
            animationObject.fadeInDuration = 0.3
            animationObject.fadeOutDuration = 0.5

            //animationObject.timingFunction = CAMediaTimingFunction(name: SCNActionTimingModeEaseInEaseOut)
            animationObject.delegate = self

            // Store the animation for later use
            animations[withKey] = animationObject
        }
    }

    func loadAnimationsGroup() {
        loadGroupTapHead()
        loadGroupTapHeadAgain()
        loadGroupBackflip()
    }

    func loadGroupTapHead() {
        // First animation is being tapped and counter with a headbutt
        let animationGroup = CAAnimationGroup()
        if let animation1 = animations[ModelAnimations.Punched2.rawValue],
            let animation2 = animations[ModelAnimations.HeadButt.rawValue] {

            animation1.beginTime = 0
            animation1.fadeInDuration = 0.2
            animation1.fadeOutDuration = 0.3
            animation2.beginTime = animation1.duration
            animation1.fadeInDuration = 0.2
            animation1.fadeOutDuration = 0.3

            animationGroup.beginTime = 0
            animationGroup.duration = animation2.beginTime + animation2.duration
            animationGroup.fadeInDuration = 0.2
            animationGroup.fadeOutDuration = 0.3

            animationGroup.animations = [animation1, animation2]
            animationGroup.delegate = self
            animationGroups[ModelAnimationGroups.TapHead.rawValue] = animationGroup
        }
    }

    func loadGroupTapHeadAgain() {
        let animationGroup = CAAnimationGroup()
        if let animation1 = animations[ModelAnimations.BlockHit.rawValue],
            let animation2 = animations[ModelAnimations.Dancing.rawValue] {

            animation1.beginTime = 0
            animation1.fadeInDuration = 0.2
            animation1.fadeOutDuration = 0.3
            animation2.beginTime = animation1.duration
            animation1.fadeInDuration = 0.2
            animation1.fadeOutDuration = 0.3

            animationGroup.beginTime = 0
            animationGroup.duration = animation2.beginTime + animation2.duration
            animationGroup.fadeInDuration = 0.2
            animationGroup.fadeOutDuration = 0.3

            animationGroup.animations = [animation1, animation2]
            animationGroup.delegate = self
            animationGroups[ModelAnimationGroups.TapHeadAgain.rawValue] = animationGroup
        }
    }

    func loadGroupBackflip() {
        // First animation is being tapped and counter with a headbutt
        let animationGroup = CAAnimationGroup()
        if let animation1 = animations[ModelAnimations.BackFlip.rawValue],
            let animation2 = animations[ModelAnimations.ThumbUp.rawValue] {

            animation1.beginTime = 0
            animation1.fadeInDuration = 0.2
            animation1.fadeOutDuration = 0.3
            animation2.beginTime = animation1.duration
            animation1.fadeInDuration = 0.2
            animation1.fadeOutDuration = 0.3

            animationGroup.beginTime = 0
            animationGroup.duration = animation2.beginTime + animation2.duration
            animationGroup.fadeInDuration = 0.2
            animationGroup.fadeOutDuration = 0.3

            animationGroup.animations = [animation1, animation2]
            animationGroup.delegate = self
            animationGroups[ModelAnimationGroups.Backflip.rawValue] = animationGroup
        }
    }

    func loadAnimations(atPosition position: SCNVector3) {
        guard let idleScene = SCNScene(named: "animations.scnassets/AgitatedIdle") else {
            print("impossible to load the neutral Idle")
            return
        }

        for child in idleScene.rootNode.childNodes {
            stormtrooperNode.addChildNode(child)
        }

        // Scale the stormtrooper to a medium human size
        stormtrooperNode.position = position
        stormtrooperNode.scale = SCNVector3(0.5, 0.5, 0.5)

        // Get the stormtrooper to face the camera when placed
        guard let currentFrame = sceneView.session.currentFrame else { return }
        let camera = currentFrame.camera
        let cameraAngle = camera.eulerAngles
        stormtrooperNode.eulerAngles.y = cameraAngle.y

        sceneView.scene.rootNode.addChildNode(stormtrooperNode)
        isCharacterPlaced = true

        // Load every animations
        for animation in ModelAnimations.allValues {
            let key = animation.rawValue
            let sceneName = "animations.scnassets/\(key)"
            let identifier = "\(key)-1"

            loadAnimation(withKey: key, sceneName: sceneName, animationIdentifier: identifier)
        }

        loadAnimationsGroup()
    }

    func placeCharacter(atLocation touchLocation: CGPoint) {
        let hitTestResults = sceneView.hitTest(touchLocation, types: [.existingPlaneUsingExtent])
        if !hitTestResults.isEmpty && !isCharacterPlaced {
            guard let hitTestResult = hitTestResults.first else {
                return
            }

            recordCameraPosition()
            let positionOfPlane = getPlanePosition(withHitResult: hitTestResult)
            loadAnimations(atPosition: positionOfPlane)
        }
    }

    func getPlanePosition(withHitResult hitTestResult: ARHitTestResult) -> SCNVector3 {
        let positionOfPlane = hitTestResult.worldTransform.columns.3
        let xPosition = positionOfPlane.x
        let yPosition = positionOfPlane.y
        let zPosition = positionOfPlane.z

        return SCNVector3(xPosition, yPosition, zPosition)
    }

    func playAnimation(key: String) {
        guard let animation = animations[key] else {
            print("animation with key \(key) doesn't exist")
            return
        }

        sceneView.scene.rootNode.addAnimation(animation, forKey: nil)
    }

    func playGroupAnimation(key: String) {
        guard let animationGroup = animationGroups[key] else {
            print("group with key \(key) doesn't exist")
            return
        }

        sceneView.scene.rootNode.addAnimation(animationGroup, forKey: nil)
    }

    func pivotModel(withDegree degrees: CGFloat) {
        let rotation = SCNAction.rotateBy(x: 0, y: degrees, z: 0, duration: 2)
        let forever = SCNAction.repeat(rotation, count: 1)
        stormtrooperNode.runAction(forever)
    }

    /// Rotate the 3d model on itself to keep facing the camera by pi/2 step
    func manageModelRotation() {
        // Get the angle made by the previous recorded position and the current position with the stormtrooper position
        let angleWithStormtrooper = Double(getAngle(v1: recordedCameraPosition, v2: getCameraPosition(), v3: stormtrooperNode.position))

        // As the angle will never be exactly pi/2, define ranges around pi/2 and -pi/2
        let aroundHalfPiPositive = (.pi/2 * 0.9)...(.pi/2 * 1.1)
        let aroundHalfPiNegative = (-.pi/2 * 1.1)...(-.pi/2 * 0.9)

        if aroundHalfPiPositive.contains(angleWithStormtrooper) {
            recordCameraPosition()
            pivotModel(withDegree: .pi/2)
            let key = ModelAnimations.LeftTurn.rawValue
            playAnimation(key: key)
        } else if aroundHalfPiNegative.contains(angleWithStormtrooper) {
            recordCameraPosition()
            pivotModel(withDegree: -.pi/2)
            let key = ModelAnimations.RightTurn.rawValue
            playAnimation(key: key)
        }
    }
}

// MARK: Camera Helpers

extension ViewController {
    func getCameraPosition() -> SCNVector3 {
        guard let currentFrame = sceneView.session.currentFrame else { return SCNVector3(x: 0, y: 0, z: 0) }

        let camera = currentFrame.camera
        let transform = camera.transform

        return SCNVector3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
    }

    func recordCameraPosition() {
        recordedCameraPosition = getCameraPosition()
    }
}

// MARK: Geometry Helpers

extension ViewController {
    /// Get an angle with a direction from 3 SCNVector3 in the 3d world
    ///
    /// - Parameters:
    ///   - v1: camera initial position (reset to each pi/2 rotation of the 3d model
    ///   - v2: camera current position
    ///   - v3: 3d model position
    /// - Returns: the current angle of the camera position based on the initial position. If that angle get = pi/2 -> rotate the 3d model to face the camera
    func getAngle(v1: SCNVector3, v2: SCNVector3, v3: SCNVector3) -> Float {
        if v1 == v2 {
            return 0.0
        }

        if v1 == SCNVector3(x: 0, y:0, z:0) {
            return 0.0
        }

        let vec1 = CGPoint(x: CGFloat(v1.x - v3.x), y: CGFloat(v1.z - v3.z))
        let vec2 = CGPoint(x: CGFloat(v2.x - v3.x), y: CGFloat(v2.z - v3.z))

        let angle = Float(atan2(vec1.y, vec1.x) - atan2(vec2.y, vec2.x))
        var newAngle: Float = 0.0

        if angle > 0 && angle < 1.5*1.1 {
            newAngle = angle
        }

        if angle < 0 && angle > -1.5*1.1 {
            newAngle = angle
        }

        if angle > 0 && angle > (1.5 * 1.1) {
            newAngle = (angle - Float.pi*2).truncatingRemainder(dividingBy: Float.pi*2)
        }

        if angle < 0 && angle < -(1.5 * 1.1) {
            newAngle = (angle + Float.pi*2).truncatingRemainder(dividingBy: Float.pi*2)
        }

        return newAngle
    }
}

// MARK: CAAnimation Delegate

extension ViewController: CAAnimationDelegate {
    func animationDidStart(_ anim: CAAnimation) {
        setAllGesturesStatus(onView: sceneView, withValue: false)
    }

    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        setAllGesturesStatus(onView: sceneView, withValue: true)
    }
}

// MARK: SCNVector3 operators

func +(rhs: SCNVector3, lhs: SCNVector3) -> SCNVector3 {
    return SCNVector3(rhs.x + lhs.x, rhs.y + lhs.y, rhs.z + lhs.z)
}

func -(rhs: SCNVector3, lhs: SCNVector3) -> SCNVector3 {
    return SCNVector3(rhs.x - lhs.x, rhs.y - lhs.y, rhs.z - lhs.z)
}

func ==(rhs: SCNVector3, lhs: SCNVector3) -> Bool {
    if rhs.x == lhs.x && rhs.y == lhs.y && rhs.z == lhs.z {
        return true
    } else {
        return false
    }
}

