//
//  GameViewController.swift
//  Hoops
//
//  Created by Kyle Rokita on 3/16/15.
//  Copyright (c) 2015 RokShop. All rights reserved.
//

let kCameraAngleRatio = 1.0 //1.0 is parallel to ground

let kBallLaunchAngleRatio = 0.6

let kCameraOffset = Float(2.0)

let kCameraYFOV = Double(55)

let kCourtLength = CGFloat(30)

let kBallRadius = CGFloat(0.119253) //diameter of bball is 9.38 inches

let kRimRadius = CGFloat(0.2286) //diameter of rim is 18 inches

let kBallMass = CGFloat(0.56699) //20 ounces in Kg

let kHoopDistanceFromWall = CGFloat(1.85)

import UIKit
import GLKit
import QuartzCore
import SceneKit

class GameViewController: UIViewController, SCNPhysicsContactDelegate {
    
    var scene : SCNScene!
    
    var basketballNode : SCNNode!
    var courtNode : SCNNode!
    
    var courtNodeSystem : SCNNode!
    
    var backWallNode : SCNNode!
    var frontWallNode : SCNNode!

    var hoopNode : SCNNode!
    var hoopNetNode : SCNNode!
    var hoopNetSpaceNode : SCNNode!

    var hoopPoleNode : SCNNode!
    var hoopPoleHorizontalNode : SCNNode!
    
    var backboardNode : SCNNode!
    var backboardRimGapNode : SCNNode!

    var rimPlaneNode : SCNNode!
    var rimNode: SCNNode!
    
    var cameraOrbitNode : SCNNode!
    var cameraNode : SCNNode!
    
    var ballCameraOrbitNode : SCNNode!
    var ballCameraNode : SCNNode!
    
    var ballPositions : [BallPosition]!
    
    var launchInfo : LaunchInfo!
    
    var ballYMin : Float!
    
    var rimPlaneCollided: Bool!
    
    var isOKToScoreBasket : Bool!
    
    @IBOutlet var scnView: SCNView!
    
    @IBOutlet var mapView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.scene = SCNScene(named: "Basketball.dae")!
        
        self.setupCourtNode()
        
        self.setupBallNode()
        
        self.setupBackWallNode()
        self.setupFrontWallNode()
        
        self.setupHoopNode()
        
        self.setupCamera()
        
        self.setupLighting()

        scnView.pointOfView = self.cameraNode
        
        // set the scene to the view
        scnView.scene = scene
        scnView.scene!.physicsWorld.speed = 1.0
        scnView.scene!.physicsWorld.contactDelegate = self
        
        // allows the user to manipulate the camera
        scnView.allowsCameraControl = false
        
        //scnView.antialiasingMode = SCNAntialiasingMode.Multisampling2X
        
        // show statistics such as fps and timing information
        scnView.showsStatistics = true
        
        // configure the view
        scnView.backgroundColor = UIColor.blackColor()
        
        // add a tap gesture recognizer
        let tapGesture = UILongPressGestureRecognizer(target: self, action: "handleLongTap:")
        tapGesture.minimumPressDuration = 0.01
        
        var gestureRecognizers = [AnyObject]()
        gestureRecognizers.append(tapGesture)
        if let existingGestureRecognizers = scnView.gestureRecognizers {
            gestureRecognizers.extend(existingGestureRecognizers)
        }
        scnView.gestureRecognizers = gestureRecognizers
        
        self.ballPositions = [BallPosition]()
        
        self.resetBasketMadeChecks()
        
        self.setBallStartPosition(SCNVector3(x: 1.0, y: ballYMin, z: 3.0))
        
        //self.basketballNode.position = SCNVector3(x: 0, y: 0, z: 10)
        
        self.setupMapView()
    }
    
    func setupMapView () {
        self.mapView.backgroundColor = UIColor.greenColor()
    }
    
    func resetBasketMadeChecks () {
        
        self.isOKToScoreBasket = true
        
        self.rimPlaneCollided = false
    }
    
    func physicsWorld(world: SCNPhysicsWorld, didBeginContact contact: SCNPhysicsContact) {
        
        //self.checkRimPlaneCollisionForPhysicsContact(contact)
        
        self.checkBasketMadeForPhysicsContact(contact)
        
        self.checkBallBounceOffSurfaceForPhysicsContact(contact)
    }
    
    func checkBallBounceOffSurfaceForPhysicsContact(contact: SCNPhysicsContact) {
        
        let surfacesToShowBounceBitMask = Collisions.Backboard | Collisions.Wall | Collisions.Pole
        
        let contactMask =
            contact.nodeB.physicsBody!.categoryBitMask
        
        if ((contactMask & surfacesToShowBounceBitMask.rawValue) > 0) {
            
            //println("node A: \(contact.nodeA.name)")
            //println("node B: \(contact.nodeB.name)")

            self.addParticleForBounceAtCoordinates(contact.contactPoint)
        }
    }

    
    func checkBasketMadeForPhysicsContact(contact: SCNPhysicsContact) {
        
        let surfacesToShowBounceBitMask = Collisions.HoopNetSpace
        
        let contactMask =
        contact.nodeB.physicsBody!.categoryBitMask
        
        if ((contactMask & surfacesToShowBounceBitMask.rawValue) > 0) {
        
            
            // check that at least half of the ball is in the bucked and the rim plane was contacted
            if (contact.penetrationDistance >= kBallRadius && contact.contactNormal.y > 0 && self.isOKToScoreBasket == true) {
                
                self.highlightNode(self.backboardNode)
                
                self.isOKToScoreBasket = false

            }
            
        }
        
        
    }
    
    func checkRimPlaneCollisionForPhysicsContact(contact: SCNPhysicsContact) {
        
        let surfacesToCheck = Collisions.RimPlane
        
        let contactMask =
        contact.nodeB.physicsBody!.categoryBitMask
        
        if ((contactMask & surfacesToCheck.rawValue) > 0) {
            
            self.rimPlaneCollided = true
            
        }
    }
    
    func addParticleForBounceAtCoordinates(coordinates:SCNVector3) {
        
        let particles = SCNParticleSystem(named: "MyParticleSystem", inDirectory: "" )
        
        let transformMatrix = SCNMatrix4MakeTranslation(coordinates.x, coordinates.y, coordinates.z)
        
        self.scene.addParticleSystem(particles, withTransform: transformMatrix)
        
    }
    
    func highlightNode(node:SCNNode) {
        
        let material = node.geometry!.firstMaterial!
        
        // highlight it
        SCNTransaction.begin()
        SCNTransaction.setAnimationDuration(0.1)
        
        // on completion - unhighlight
        SCNTransaction.setCompletionBlock {
            SCNTransaction.begin()
            SCNTransaction.setAnimationDuration(0.5)
            
            material.emission.contents = UIColor.blackColor()
            
            SCNTransaction.commit()
        }
        
        material.emission.contents = UIColor.greenColor()
        
        SCNTransaction.commit()

    }
    
    func setupLighting () {
        
        let spotLight = SCNLight()
        spotLight.type = SCNLightTypeSpot
        spotLight.attenuationStartDistance = 0.0
        spotLight.attenuationEndDistance = 50.0
        spotLight.attenuationFalloffExponent = 2.0
        
        spotLight.spotInnerAngle = 150.0
        spotLight.spotOuterAngle = 150.0
        
        spotLight.castsShadow = true
        //spotLight.shadowColor = UIColor.blackColor().colorWithAlphaComponent(0.7)
        
        spotLight.categoryBitMask = 2
        
        //spotLight.shadowRadius = 5.0
        //spotLight.shadowSampleCount = 1
        
        let spotlightNode = SCNNode()
        spotlightNode.light = spotLight
        spotlightNode.position = SCNVector3(x: 0, y: 25, z: Float(kCourtLength / 4.0))
        spotlightNode.eulerAngles = SCNVector3(x: Float(M_PI_2 * 3.0), y: 0, z: 0)
        scene.rootNode.addChildNode(spotlightNode)
        
        let light = SCNLight()
        light.type = SCNLightTypeOmni
        light.attenuationStartDistance = 0.0
        light.attenuationEndDistance = 50.0
        light.attenuationFalloffExponent = 2.0
        
        let lightSpacing = Float(kCourtLength / 4.0)
        let lightHeight = Float(25)
        
        // create and add a light to the scene
        let lightNode = SCNNode()
        lightNode.light = light
        lightNode.position = SCNVector3(x: -lightSpacing, y: lightHeight, z: lightSpacing)
        lightNode.eulerAngles = SCNVector3(x: Float(M_PI_2 * 3.0), y: 0, z: 0)
        scene.rootNode.addChildNode(lightNode)
        
        let lightNode2 = SCNNode()
        lightNode2.light = light
        lightNode2.position = SCNVector3(x: lightSpacing, y: lightHeight, z: lightSpacing)
        lightNode2.eulerAngles = SCNVector3(x: Float(M_PI_2 * 3.0), y: 0, z: 0)
        scene.rootNode.addChildNode(lightNode2)
        
        let lightNode3 = SCNNode()
        lightNode3.light = light
        lightNode3.position = SCNVector3(x: lightSpacing, y: lightHeight, z: 3.0 * lightSpacing)
        lightNode3.eulerAngles = SCNVector3(x: Float(M_PI_2 * 3.0), y: 0, z: 0)
        scene.rootNode.addChildNode(lightNode3)
        
        let lightNode4 = SCNNode()
        lightNode4.light = light
        lightNode4.position = SCNVector3(x: -lightSpacing, y: lightHeight, z: 3.0 * lightSpacing)
        lightNode4.eulerAngles = SCNVector3(x: Float(M_PI_2 * 3.0), y: 0, z: 0)
        
        scene.rootNode.addChildNode(lightNode4)
        
        // create and add an ambient light to the scene
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light!.type = SCNLightTypeAmbient
        ambientLightNode.light!.color = UIColor(white: 0.5, alpha: 1.0)
        scene.rootNode.addChildNode(ambientLightNode)

    }
    
    func setupCamera () {
        
        let camera = SCNCamera()
        camera.usesOrthographicProjection = false
        camera.zNear = 0.01 // default is 1.0
        camera.zFar = 100.0
        camera.orthographicScale = 5.0
        camera.yFov = kCameraYFOV // default is 60
        //camera.xFov = 120
        
        self.cameraNode = SCNNode()
        self.cameraNode.camera = camera
        
        self.scene.rootNode.addChildNode(self.cameraNode)
        
        //let ballCamera = SCNCamera()
        //ballCamera.usesOrthographicProjection = false
        //ballCamera.zNear = 1.0 // default
        //ballCamera.zFar = 200.0 // default
        //ballCamera.orthographicScale = 5.0
        
        //self.ballCameraOrbitNode = SCNNode()
        //self.ballCameraOrbitNode.position = SCNVector3(x: 0, y: 0.0, z: 0.0)
        //self.ballCameraOrbitNode.eulerAngles = SCNVector3(x: Float(-M_PI_2 * (1 + kCameraAngleRatio) ), y: 0.0, z: 0.0)
        //self.basketballNode.addChildNode(self.ballCameraOrbitNode)
        //
        //self.ballCameraNode = SCNNode()
        //self.ballCameraNode.camera = ballCamera
        //self.ballCameraOrbitNode.addChildNode(self.ballCameraNode)
        
        // place the camera
        //self.ballCameraNode.position = SCNVector3(x: 0, y: 0.0, z: 0.0)
    }
    
    func setupBallNode () {
        
        self.basketballNode = scene.rootNode.childNodeWithName("Basketball", recursively: true)!
        
        
        let scale = Float(kBallRadius / 1.0)
        self.basketballNode.scale = SCNVector3(x: scale, y: scale, z: scale)
        
        self.ballYMin = 1.0 * scale
        
        
        var ballBody = SCNPhysicsBody(type: SCNPhysicsBodyType.Dynamic, shape: SCNPhysicsShape(geometry: SCNSphere(radius: CGFloat(1.0) * CGFloat(scale)), options:nil))
        
        ballBody.mass = kBallMass
        ballBody.damping = 0.0
        ballBody.angularDamping = 0.2
        ballBody.velocity = SCNVector3(x: 0.0, y: 0.0, z: 0.0)
        ballBody.angularVelocity = SCNVector4(x: 0.0, y: 0.0, z: 0.0, w: 0.0)
        ballBody.restitution = 1.1
        ballBody.friction = 0.2
        ballBody.rollingFriction = 1.0
        
        ballBody.categoryBitMask = Collisions.Ball.rawValue
        
        self.basketballNode.physicsBody = ballBody
        
        // self.basketballNode.removeFromParentNode()
        // self.courtNodeSystem.addChildNode(self.basketballNode)
        
    }
    
    func setBallStartPosition(position:SCNVector3) {
        
        self.basketballNode.position = SCNVector3(x: position.x, y: ballYMin, z: position.z)

        self.cameraNode.eulerAngles = self.cameraAngleRelativeToBallPosition(self.basketballNode.position)
        self.cameraNode.position = self.cameraPositionRelativeToBallPosition(self.basketballNode.position)

    }
    
    func angleRelativeToBallPosition(position:SCNVector3) -> Float {
        
        let x = position.x
        let z = position.z != 0 ? position.z : 0.00001
        
        var angle = atan(x/z)
        
        if (z<0) {
            angle += Float(M_PI)
        }
        
        return angle
    }
    
    func cameraPositionRelativeToBallPosition(position:SCNVector3) -> SCNVector3 {
        
        let angle = self.angleRelativeToBallPosition(position)
        
        let cameraAdditionalX = sin(angle) * kCameraOffset
        let cameraAdditionalZ = cos(angle) * kCameraOffset

        let cameraHeight = Float(1.75)
        
        return SCNVector3(x: position.x + cameraAdditionalX, y: cameraHeight, z: position.z + cameraAdditionalZ)
    }
    
    func cameraAngleRelativeToBallPosition(position:SCNVector3) -> SCNVector3 {
        
        let angle = self.angleRelativeToBallPosition(position) * -1.0
        
        return SCNVector3(x: Float(M_PI_2 - M_PI_2 * kCameraAngleRatio ), y: (0.0 - angle) , z: 0.0)
        
    }
    
    func setupCourtNode () {
     
        self.courtNode = scene.rootNode.childNodeWithName("Court", recursively: true)!
        self.courtNode.removeFromParentNode()
        
        let courtLength = self.courtLength()
        let courtWidth = self.courtWidth()
        let courtThickness = CGFloat(0.5)

        let courtGeometry = SCNBox(width: courtLength, height: courtThickness, length: courtWidth, chamferRadius: 0)
        
        courtGeometry.firstMaterial!.diffuse.contents = UIImage(contentsOfFile: NSBundle.mainBundle().pathForResource("basketballCourt", ofType: "png")!)
        
        self.courtNode = SCNNode(geometry: courtGeometry)
        self.courtNode.position = SCNVector3(x: 0.0, y: Float(-courtThickness / 2.0), z: Float(kCourtLength/2.0 - kHoopDistanceFromWall))
        self.courtNode.eulerAngles = SCNVector3(x: 0, y: Float(-M_PI_2), z: 0)
        
        self.courtNode.name = "Court"
        
        self.scene.rootNode.addChildNode(self.courtNode)
        
        self.courtNode.categoryBitMask = 2
        
        let bodyScaleVector = SCNVector3(x: 1.1, y: 1.0, z: 1.1)
        let vectorValue = NSValue(SCNVector3:bodyScaleVector)
        
        var courtBody = SCNPhysicsBody(type: SCNPhysicsBodyType.Static, shape: SCNPhysicsShape(geometry: self.courtNode.geometry!, options:[SCNPhysicsShapeTypeKey:SCNPhysicsShapeTypeBoundingBox, SCNPhysicsShapeScaleKey:vectorValue]))
        courtBody.friction = 1.0
        courtBody.rollingFriction = 1.0
        
        courtBody.categoryBitMask = Collisions.Floor.rawValue
        
        self.courtNode.physicsBody = courtBody
        
       /* let courtNodeGeo = SCNSphere(radius: 0.5)
        
        self.courtNodeSystem = SCNNode(geometry: courtNodeGeo)
        self.courtNodeSystem.position = SCNVector3(x: 0, y: 0, z: -15)
        
        self.scene.rootNode.addChildNode(self.courtNodeSystem)
        
        
        let testGeo = SCNSphere(radius: 0.5)
        
        let testNode = SCNNode(geometry: testGeo)
        testNode.position = SCNVector3(x: 0, y: 0, z: 10)
        
        self.courtNodeSystem.addChildNode(testNode)*/

    }
    
    func setupHoopNode () {
        
        let rimHeight = CGFloat(3.048)
        let rimRadius = kRimRadius
        let rimPipeRadius = CGFloat(0.0125)
        
        self.hoopNode = SCNNode()
        self.hoopNode.position = SCNVector3(x: 0.0, y: 0.0, z: Float(0.0))
        
        self.hoopNode.name = "Hoop"
        
        self.hoopNode.categoryBitMask = 0 // invisible to camera


        self.scene.rootNode.addChildNode(self.hoopNode)
        
        
        let rimGeometry = SCNTorus(ringRadius: rimRadius + rimPipeRadius, pipeRadius: rimPipeRadius)
        rimGeometry.firstMaterial!.diffuse.contents = UIColor.redColor()
        
        self.rimNode = SCNNode(geometry: rimGeometry)
        self.rimNode.position = SCNVector3(x: 0, y: Float(rimHeight), z: 0)
        self.hoopNode.addChildNode(self.rimNode)

        var rimBody = SCNPhysicsBody(type: SCNPhysicsBodyType.Static, shape: SCNPhysicsShape(geometry: self.rimNode.geometry!, options: [SCNPhysicsShapeTypeKey:SCNPhysicsShapeTypeConcavePolyhedron]))
        rimBody.friction = 0.0
        rimBody.rollingFriction = 0.0
        
        rimBody.categoryBitMask = Collisions.Rim.rawValue
        
        self.rimNode.physicsBody = rimBody

        let hoopNetHeight = CGFloat(0.4)
        
        let hoopNetGeometry = SCNTube(innerRadius: rimRadius, outerRadius: rimRadius + 0.02, height: hoopNetHeight)
        hoopNetGeometry.firstMaterial!.diffuse.contents = UIImage(contentsOfFile: NSBundle.mainBundle().pathForResource("net", ofType: "png")!)
        
        self.hoopNetNode = SCNNode(geometry: hoopNetGeometry)
        self.hoopNetNode.position = SCNVector3(x: 0, y: Float(rimHeight - hoopNetHeight / 2.0), z: 0)
        
        self.hoopNetNode.name = "HoopNet"

        self.hoopNode.addChildNode(self.hoopNetNode)
        
        var hoopNetBody = SCNPhysicsBody(type: SCNPhysicsBodyType.Static, shape: SCNPhysicsShape(geometry: self.hoopNetNode.geometry!, options: [SCNPhysicsShapeTypeKey:SCNPhysicsShapeTypeConcavePolyhedron]))
        
        hoopNetBody.friction = 1.0
        hoopNetBody.rollingFriction = 1.0

        hoopNetBody.categoryBitMask = Collisions.HoopNet.rawValue

        
        self.hoopNetNode.physicsBody = hoopNetBody
        
        
        // !!! lowering radius of hoopnet space so it does not run touch the hoopnet, which registers as contact and slows down processing
        let hoopNetSpaceGeometry = SCNCylinder(radius: rimRadius - 0.05, height: hoopNetHeight)
        
        self.hoopNetSpaceNode = SCNNode(geometry: hoopNetSpaceGeometry)
        self.hoopNetSpaceNode.position = SCNVector3(x: 0, y: Float(rimHeight - hoopNetHeight / 2.0), z: 0)
        
        self.hoopNetSpaceNode.name = "HoopNet"
        
        self.hoopNode.addChildNode(self.hoopNetSpaceNode)
        
        var hoopNetSpaceBody = SCNPhysicsBody(type: SCNPhysicsBodyType.Kinematic, shape: SCNPhysicsShape(geometry: self.hoopNetSpaceNode.geometry!, options: nil))
        
        hoopNetSpaceBody.mass = 0.00001
        hoopNetSpaceBody.categoryBitMask = Collisions.HoopNetSpace.rawValue
        
        
        self.hoopNetSpaceNode.physicsBody = hoopNetSpaceBody
        
        self.hoopNetSpaceNode.categoryBitMask = 0 //not visible to camera, but physics do work
        
        
        /*let rimPlaneGeometry = SCNPlane(width: rimRadius, height: rimRadius) //the plane will not extend out of the circle of the rim
        rimPlaneGeometry.firstMaterial!.diffuse.contents = UIColor.clearColor()
        
        self.rimPlaneNode = SCNNode(geometry: rimPlaneGeometry)
        self.rimPlaneNode.position = SCNVector3(x: 0, y: Float(rimHeight), z: 0)
        self.rimPlaneNode.eulerAngles = SCNVector3(x: Float(M_PI_2), y: 0, z: 0)
        
        self.rimPlaneNode.name = "RimPlane"

        self.hoopNode.addChildNode(self.rimPlaneNode)
        
        var rimPlaneBody = SCNPhysicsBody(type: SCNPhysicsBodyType.Kinematic, shape: SCNPhysicsShape(geometry: self.rimPlaneNode.geometry!, options: nil))
        
        rimPlaneBody.mass = 0.00001
        rimPlaneBody.categoryBitMask = Collisions.RimPlane.rawValue
        
        self.rimPlaneNode.physicsBody = rimPlaneBody
        */
        
        let backboardHeight = CGFloat(1.0)
        let backboardWidth = CGFloat(1.5)
        let backboardThickness = CGFloat(0.1)
        let backboardRimGap = CGFloat(0.125)
        
        let backboardGeometry = SCNBox(width: backboardWidth, height: backboardHeight, length: backboardThickness, chamferRadius: 0.05)
        backboardGeometry.firstMaterial!.diffuse.contents = UIImage(contentsOfFile: NSBundle.mainBundle().pathForResource("backboard", ofType: "png")!)
        
        self.backboardNode = SCNNode(geometry: backboardGeometry)
        self.backboardNode.position = SCNVector3(x: 0, y: Float(rimHeight + backboardHeight / 2.0) - 0.05, z: Float(-backboardThickness/2.0) - Float(rimRadius + rimPipeRadius * 2.0) - Float(backboardRimGap))
        
        self.backboardNode.name = "Backboard"
        
        self.backboardNode.categoryBitMask = 2
        
        self.hoopNode.addChildNode(self.backboardNode)
        
        var backboardBody = SCNPhysicsBody(type: SCNPhysicsBodyType.Static, shape: SCNPhysicsShape(geometry: self.backboardNode.geometry!, options: [SCNPhysicsShapeTypeKey:SCNPhysicsShapeTypeBoundingBox]))
        backboardBody.friction = 0.5
        backboardBody.rollingFriction = 0.5
        
        backboardBody.categoryBitMask = Collisions.Backboard.rawValue
        
        self.backboardNode.physicsBody = backboardBody
        
        let rimGapWidth = CGFloat(0.1)
        
        let backboardRimGapGeometry = SCNBox(width: rimGapWidth, height: rimPipeRadius * 2.0, length: backboardRimGap, chamferRadius: 0.0)
        backboardRimGapGeometry.firstMaterial!.diffuse.contents = UIColor.redColor()
        
        self.backboardRimGapNode = SCNNode(geometry: backboardRimGapGeometry)
        self.backboardRimGapNode.position = SCNVector3(x: 0, y: Float(rimHeight), z: -Float(rimRadius + rimPipeRadius * 2.0) - Float(backboardRimGap/2.0))
        
        self.backboardRimGapNode.name = "BackboardRimGap"
        
        self.hoopNode.addChildNode(self.backboardRimGapNode)
        
        var backboardRimGapBody = SCNPhysicsBody(type: SCNPhysicsBodyType.Static, shape: SCNPhysicsShape(geometry: self.backboardRimGapNode.geometry!, options: [SCNPhysicsShapeTypeKey:SCNPhysicsShapeTypeBoundingBox]))
        backboardRimGapBody.friction = 1.0
        backboardRimGapBody.rollingFriction = 1.0
        
        backboardRimGapBody.categoryBitMask = Collisions.Rim.rawValue
        
        self.backboardRimGapNode.physicsBody = backboardRimGapBody
        

        
        let poleRadius = CGFloat(0.05)
        let poleHeight = rimHeight + backboardHeight / 2.0
        
        let poleGeometry = SCNCylinder(radius: poleRadius, height: poleHeight)
        poleGeometry.firstMaterial!.diffuse.contents = UIColor.grayColor()
        
        self.hoopPoleNode = SCNNode(geometry: poleGeometry)
        self.hoopPoleNode.position = SCNVector3(x: 0, y: Float(poleHeight / CGFloat(2.0)), z: Float(-kHoopDistanceFromWall + 0.4))
        
        self.hoopPoleNode.name = "HoopPole"

        self.hoopNode.addChildNode(self.hoopPoleNode)
        
        var poleBody = SCNPhysicsBody(type: SCNPhysicsBodyType.Static, shape: SCNPhysicsShape(geometry: self.hoopPoleNode.geometry!, options: [SCNPhysicsShapeTypeKey:SCNPhysicsShapeTypeBoundingBox]))
        poleBody.friction = 1.0
        poleBody.rollingFriction = 1.0
        
        poleBody.categoryBitMask = Collisions.Pole.rawValue
        
        self.hoopPoleNode.physicsBody = poleBody
        
        
        let poleHorizontalGeometry = SCNCylinder(radius: poleRadius, height: CGFloat(self.backboardNode.position.z - self.hoopPoleNode.position.z + Float(poleRadius)))
        poleHorizontalGeometry.firstMaterial!.diffuse.contents = UIColor.grayColor()
        
        self.hoopPoleHorizontalNode = SCNNode(geometry: poleHorizontalGeometry)
        self.hoopPoleHorizontalNode.position = SCNVector3(x: 0, y: Float(poleHeight), z: (self.backboardNode.position.z - self.hoopPoleNode.position.z) / 2.0 + self.hoopPoleNode.position.z - Float(poleRadius) / 2.0)
        self.hoopPoleHorizontalNode.eulerAngles = SCNVector3(x: Float(M_PI_2), y: 0, z: 0)

        self.hoopPoleHorizontalNode.name = "HoopPoleHorizontal"
        
        self.hoopNode.addChildNode(self.hoopPoleHorizontalNode)
        
        var poleHorizontalBody = SCNPhysicsBody(type: SCNPhysicsBodyType.Static, shape: SCNPhysicsShape(geometry: self.hoopPoleHorizontalNode.geometry!, options: [SCNPhysicsShapeTypeKey:SCNPhysicsShapeTypeBoundingBox]))
        poleHorizontalBody.friction = 1.0
        poleHorizontalBody.rollingFriction = 1.0
        
        poleHorizontalBody.categoryBitMask = Collisions.Pole.rawValue
        
        self.hoopPoleHorizontalNode.physicsBody = poleHorizontalBody

    }
    
    func courtLength() -> CGFloat {
        return kCourtLength
    }
    
    func courtWidth() -> CGFloat {
        return self.courtLength() * 1251.0 / 2085.0
    }
    
    func setupBackWallNode () {
        
        let wallWidth = self.courtWidth()
        let wallHeight = CGFloat(50.0)
        let wallThickness = CGFloat(0.5)

        let backWallZPosition = -kHoopDistanceFromWall
        
        let wallGeometry = SCNBox(width: wallWidth, height: wallHeight, length: wallThickness, chamferRadius: 0)
        
        wallGeometry.firstMaterial!.diffuse.contents = UIColor.blueColor()
        
        self.backWallNode = SCNNode(geometry: wallGeometry)
        self.backWallNode.position = SCNVector3(x: 0.0, y: Float(backWallZPosition), z: Float(backWallZPosition))
        self.backWallNode.eulerAngles = SCNVector3(x: 0, y: 0, z: 0)
        
        self.backWallNode.name = "BackWall"

        self.scene.rootNode.addChildNode(self.backWallNode)
        
        let bodyScaleVector = SCNVector3(x: 1.1, y: 1.1, z: 1.0)
        let vectorValue = NSValue(SCNVector3:bodyScaleVector)
        
        var wallBody = SCNPhysicsBody(type: SCNPhysicsBodyType.Static, shape: SCNPhysicsShape(geometry: self.backWallNode.geometry!, options:[SCNPhysicsShapeTypeKey:SCNPhysicsShapeTypeBoundingBox,SCNPhysicsShapeScaleKey:vectorValue]))
        wallBody.friction = 1.0
        wallBody.rollingFriction = 1.0
        
        wallBody.categoryBitMask = Collisions.Wall.rawValue
        
        self.backWallNode.physicsBody = wallBody
        
        self.backWallNode.categoryBitMask = 2

    }
    
    func setupFrontWallNode () {
        
        
        let wallWidth = self.courtWidth()
        let wallHeight = CGFloat(50.0)
        let wallThickness = CGFloat(0.5)
        
        let backWallZPosition = kCourtLength - kHoopDistanceFromWall
        
        let wallGeometry = SCNBox(width: wallWidth, height: wallHeight, length: wallThickness, chamferRadius: 0)

        
        self.frontWallNode = SCNNode(geometry: wallGeometry)
        self.frontWallNode.position = SCNVector3(x: 0.0, y: Float(backWallZPosition), z: Float(backWallZPosition))
        self.frontWallNode.eulerAngles = SCNVector3(x: 0, y: 0, z: 0)
        
        self.frontWallNode.name = "FrontWall"
        
        self.scene.rootNode.addChildNode(self.frontWallNode)
        
        let bodyScaleVector = SCNVector3(x: 1.1, y: 1.1, z: 1.0)
        let vectorValue = NSValue(SCNVector3:bodyScaleVector)
        
        var wallBody = SCNPhysicsBody(type: SCNPhysicsBodyType.Static, shape: SCNPhysicsShape(geometry: self.backWallNode.geometry!, options:[SCNPhysicsShapeTypeKey:SCNPhysicsShapeTypeBoundingBox,SCNPhysicsShapeScaleKey:vectorValue]))
        wallBody.friction = 1.0
        wallBody.rollingFriction = 1.0
        
        wallBody.categoryBitMask = Collisions.FrontWall.rawValue
        
        self.frontWallNode.physicsBody = wallBody

        self.frontWallNode.categoryBitMask = 0 // invisible to camera
    }
    
    func handleTap(gestureRecognize: UIGestureRecognizer) {
        // check what nodes are tapped
        let p = gestureRecognize.locationInView(scnView)
        if let hitResults = scnView.hitTest(p, options: nil) {
            // check that we clicked on at least one object
            if hitResults.count > 0 {
                // retrieved the first clicked object
                let result: AnyObject! = hitResults[0]
                
                // get its material
                let material = result.node!.geometry!.firstMaterial!
                
                // highlight it
                SCNTransaction.begin()
                SCNTransaction.setAnimationDuration(0.5)
                
                // on completion - unhighlight
                SCNTransaction.setCompletionBlock {
                    SCNTransaction.begin()
                    SCNTransaction.setAnimationDuration(0.5)
                    
                    material.emission.contents = UIColor.blackColor()
                    
                    SCNTransaction.commit()
                }
                
                material.emission.contents = UIColor.greenColor()
                
                SCNTransaction.commit()
            }
        }
    }
    
    func handleLongTap(gestureRecognize: UILongPressGestureRecognizer) {
        // retrieve the SCNView
        
        if (gestureRecognize.state == UIGestureRecognizerState.Began ||
            gestureRecognize.state == UIGestureRecognizerState.Changed ) {
                
                self.moveBallNodeToRecognizer(gestureRecognize)
                self.activateGravity(false)
                

                
        } else if (gestureRecognize.state == UIGestureRecognizerState.Ended ||
            gestureRecognize.state == UIGestureRecognizerState.Cancelled ||
            gestureRecognize.state == UIGestureRecognizerState.Failed) {
                
                
            self.scene.removeAllParticleSystems()
            self.resetBasketMadeChecks()
        
            self.moveBallNodeToRecognizer(gestureRecognize)
                self.activateGravity(true)
                self.addBallVelocity()
                
            self.ballPositions = [BallPosition]()

            self.addBallAngularVelocity()
                

        }
    }
    
    func moveBallNodeToRecognizer(gestureRecognize: UILongPressGestureRecognizer) {
        
        let p = gestureRecognize.locationInView(scnView)
        let newPosition = self.positionForNode(self.basketballNode, locationInView: p)

        self.basketballNode.position = newPosition
        self.updateBallPositionsFor(self.basketballNode.position)
        
    }
    
    func addBallAngularVelocity () {
        
        let angleFromBasket = self.angleRelativeToBallPosition(self.basketballNode.position)
        
        let rotationVector = SCNVector4(x: 0, y: 1, z: 0, w: Float(angleFromBasket))
        
        let originalVector = SCNVector3(x: 1.0, y: 0.0, z: 0.0)
        let adjustedVector = self.rotateSCNVector3(originalVector, byRotationSCNVector4: rotationVector)
        
        self.basketballNode.physicsBody!.angularVelocity = SCNVector4(x: adjustedVector.x, y: adjustedVector.y, z: adjustedVector.z, w: 15.0)
    }
    
    
    func addBallVelocity () {
        
        var xDiff = Float(0)
        var yDiff = Float(0)
        var zDiff = Float(0)

        if (self.ballPositions.count == 2) {
            
            let ballPosition1 = self.ballPositions[1]
            let ballPosition2 = self.ballPositions[0]
            
            let time2 = ballPosition2.date
            let time1 = ballPosition1.date

            let timeElapsed = time2.timeIntervalSinceDate(time1)
            
            xDiff = (ballPosition2.position.x - ballPosition1.position.x) / Float(timeElapsed)
            yDiff = (ballPosition2.position.y - ballPosition1.position.y) / Float(timeElapsed)
            zDiff = (ballPosition2.position.z - ballPosition1.position.z) / Float(timeElapsed)
            
            
        }
        else if (self.ballPositions.count == 3) {
            
            let ballPosition1 = self.ballPositions[2]
            let ballPosition2 = self.ballPositions[1]
            
            let time2 = ballPosition2.date
            let time1 = ballPosition1.date
            
            let timeElapsed = time2.timeIntervalSinceDate(time1)
            
            xDiff = (ballPosition2.position.x - ballPosition1.position.x) / Float(timeElapsed)
            yDiff = (ballPosition2.position.y - ballPosition1.position.y) / Float(timeElapsed)
            zDiff = (ballPosition2.position.z - ballPosition1.position.z) / Float(timeElapsed)
            
        } else if (self.ballPositions.count > 3) {
            
            let ballPosition1 = self.ballPositions[3]
            let ballPosition2 = self.ballPositions[1]
            
            let time2 = ballPosition2.date
            let time1 = ballPosition1.date
            
            let timeElapsed = time2.timeIntervalSinceDate(time1)
            
            xDiff = (ballPosition2.position.x - ballPosition1.position.x) / Float(timeElapsed)
            yDiff = (ballPosition2.position.y - ballPosition1.position.y) / Float(timeElapsed)
            zDiff = (ballPosition2.position.z - ballPosition1.position.z) / Float(timeElapsed)
            
        }
        
        let slowAdjust = Float(1.0)
        
        xDiff /= slowAdjust
        yDiff /= slowAdjust
        zDiff /= slowAdjust
        
        //adjust for cameraAngle, want X to have all velocity
        let angleFromBasket = self.angleRelativeToBallPosition(self.cameraNode.position)
        let rotationVector = SCNVector4(x: 0, y: 1, z: 0, w: Float(angleFromBasket * -1.0))

        let originalVector = SCNVector3(x: xDiff, y: yDiff, z: zDiff)
        let adjustedVector = self.rotateSCNVector3(originalVector, byRotationSCNVector4: rotationVector)
        
        xDiff = adjustedVector.x
        yDiff = adjustedVector.y
        zDiff = adjustedVector.z
        
        let zVelocity = -zPositionFor(yDiff)
        
        //let xAdjVelocity = cos(angleFromBasket) * xDiff + sin(angleFromBasket) * zVelocity
        
        //let zAdjVelocity = sin(angleFromBasket) * xDiff + cos(angleFromBasket) * zVelocity
        
        let positionChangeVector = SCNVector3(x: xDiff, y: yDiff, z: zVelocity)
        
        let rotationVector2 = SCNVector4(x: 0, y: 1, z: 0, w: Float(angleFromBasket))
        
        var rotatedVector = self.rotateSCNVector3(positionChangeVector, byRotationSCNVector4: rotationVector2)
        
        let idealLaunchVector = self.idealLaunchVectorForBallLaunchPosition(self.basketballNode.position, actualLaunchVector: rotatedVector)
        
        if (!isnan(idealLaunchVector.y)) {
            let blendRatioVertical = Float(0.2) //ratio of real to ideal
            let blendRatioHorizontal = Float(0.2) //ratio of real to ideal

            
            let newX = rotatedVector.x * blendRatioHorizontal + idealLaunchVector.x * (1.0 - blendRatioHorizontal)
            let newY = rotatedVector.y * blendRatioVertical + idealLaunchVector.y * (1.0 - blendRatioVertical)
            let newZ = rotatedVector.z * blendRatioVertical + idealLaunchVector.z * (1.0 - blendRatioVertical)

            rotatedVector = SCNVector3(x: newX, y: newY, z: newZ)
        }

        self.basketballNode.physicsBody!.velocity = rotatedVector

        self.launchInfo = LaunchInfo(position: self.basketballNode.position, initialVelocity: self.basketballNode.physicsBody!.velocity)
    }
    
    func idealLaunchVectorForBallLaunchPosition (position: SCNVector3, actualLaunchVector:SCNVector3) -> SCNVector3 {
        
        //get ball distance from rim center
        let xDistance = self.rimNode.position.x - position.x
        let yDistance = self.rimNode.position.y - position.y
        let zDistance = self.rimNode.position.z - position.z - 0.1
        
        let totalDistance = sqrt(xDistance * xDistance + yDistance * yDistance + zDistance * zDistance)
        
        //get time by dividing total distance by total original velocity
        //let time = totalDistance / totalVelocity
        
        //y = actualLaunchVector.y * t - 4.9 * t^2
        
        let gravity = Float(4.9)
        
        let aa = Float(-gravity)
        let bb = actualLaunchVector.y
        let cc = -yDistance
        
        let d = ( -bb + sqrt( bb * bb - 4.0 * aa * cc ) ) / (2.0 * aa)
        let e = ( -bb - sqrt( bb * bb - 4.0 * aa * cc ) ) / (2.0 * aa)
        
        let time = e
        
        let yVector = (yDistance + gravity * time * time) / time
        
        return SCNVector3(x: xDistance / time, y: yVector , z: zDistance / time)
    }
    
    func rotateSCNVector3(startSCNVector3:SCNVector3, byRotationSCNVector4 rotationVector:SCNVector4) -> SCNVector3 {
        
        let matrix = SCNMatrix4MakeRotation(rotationVector.w, rotationVector.x, rotationVector.y, rotationVector.z)
        
        let GLKmatrix = SCNMatrix4ToGLKMatrix4(matrix)
        
        let GLKvector = GLKVector3Make(startSCNVector3.x, startSCNVector3.y, startSCNVector3.z)
        
        let GLKrotatedVector = GLKMatrix4MultiplyVector3(GLKmatrix, GLKvector)
        
        return SCNVector3FromGLKVector3(GLKrotatedVector)
    }
    
    func updateBallPositionsFor(position:SCNVector3) {
        
        if (self.ballPositions.count > 0) {
            self.ballPositions.insert(BallPosition(position: position), atIndex: 0)
            
            if (self.ballPositions.count > 5) {
                self.ballPositions.removeLast()
            }

        } else {
        
            self.ballPositions.append(BallPosition(position: position))
        }
    }
    
    func positionForNode(node:SCNNode, locationInView p:CGPoint) -> SCNVector3 {
        
        let projectedBall = scnView.projectPoint(self.basketballNode.position)
        
        var x = Float(p.x)
        var y = Float(p.y)
        var z = Float(projectedBall.z) //use Z of the ball since thats what we want to be able to interact with
        
        let viewCoordinates = SCNVector3(x: x, y: y, z: z)
        
        var unprojectedVector = scnView.unprojectPoint(viewCoordinates)
        
        let minY = ballYMin
        
        let angle = Float(0.0) // use camera node since it doesnt move
        
        let adustedX = cos(angle) * unprojectedVector.x + sin(angle) * unprojectedVector.z
        let adustedZ = cos(angle) * unprojectedVector.z + sin(angle) * unprojectedVector.x
        
        var newX = adustedX
        var newY = max(minY,unprojectedVector.y)
        var newZ = adustedZ
        
        var sceneCoordinates = SCNVector3(x: newX, y: newY, z: newZ)
        
        return sceneCoordinates
    }
    
    
    func zPositionFor(yPosition:Float) -> Float {
        
        let yHeight = yPosition
        
        //tan (angle) = opp / adj, opp is ball y position, adj is z
        
        let z = yHeight / Float(tan(kBallLaunchAngleRatio * M_PI_2))
        
        return z
    }
    
    func activateGravity(bool:Bool) {
        
        if (bool) {

            //self.scene.physicsWorld.gravity = SCNVector3(x: 0, y: -9.8, z: 0)
            self.basketballNode.physicsBody!.mass = kBallMass

        } else {
            
            //self.scene.physicsWorld.gravity = SCNVector3(x: 0, y: 0, z: 0)

            self.basketballNode.physicsBody!.mass = 0.0

        }
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return UIStatusBarStyle.LightContent
    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
    
    
    /*override func shouldAutorotate() -> Bool {
    return true
    }
    
    override func prefersStatusBarHidden() -> Bool {
    return true
    }
    
    override func supportedInterfaceOrientations() -> Int {
    if UIDevice.currentDevice().userInterfaceIdiom == .Phone {
    return Int(UIInterfaceOrientationMask.AllButUpsideDown.rawValue)
    } else {
    return Int(UIInterfaceOrientationMask.All.rawValue)
    }
    }*/
    
}
