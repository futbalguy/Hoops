//
//  GameViewController.swift
//  Hoops
//
//  Created by Kyle Rokita on 3/16/15.
//  Copyright (c) 2015 RokShop. All rights reserved.
//

let kCameraAngleRatio = 1.0 //1.0 is parallel to ground
let kCameraOffset = Float(2.0)
let kCameraYFOV = Double(50)

let kHoopDistanceFromWall = CGFloat(1.85)
let kCourtFullLength = CGFloat(30.0)

let kBallMass = CGFloat(0.56699) //20 ounces in Kg
let kBallRadius = CGFloat(0.119253) //diameter of bball is 9.38 inches
let kRimRadius = CGFloat(0.2286) //diameter of rim is 18 inches
let kBallLaunchAngleRatio = 0.58

import UIKit
import GLKit
import QuartzCore
import SceneKit

class GameViewController: UIViewController, SCNPhysicsContactDelegate, SCNSceneRendererDelegate {
    
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
    
    var ballStartPosition : SCNVector3!
    var ballLastStartPosition : SCNVector3?
    
    var ballPositions : [BallPosition]!
    
    var ballPositionView : UIView?
    var ballStartPositionView : UIView?
    
    var launchInfo : LaunchInfo!
    
    var ballYMin : Float!
    
    var rimPlaneCollided: Bool!
    
    var isOKToScoreBasket : Bool!
    
    @IBOutlet var scnView: SCNView!
    
    @IBOutlet var mapView: UIView!
    
    var mapTitleLabel: UILabel!
    var mapImageView: UIImageView!
    var mapViewConfirmButton : UIButton!
    var mapViewCancelButton : UIButton!
    
    var isMapViewExpanded = false
    
    @IBOutlet var mapViewConstraintLeft : NSLayoutConstraint!
    @IBOutlet var mapViewConstraintTop : NSLayoutConstraint!
    @IBOutlet var mapViewConstraintWidth : NSLayoutConstraint!
    @IBOutlet var mapViewConstraintHeight : NSLayoutConstraint!
    
    var mapTitleHeightConstraint : NSLayoutConstraint!
    var mapImageHeightConstraint : NSLayoutConstraint!
    var buttonHeightConstraint : NSLayoutConstraint!
    
    var mapUpdateTimeInterval : TimeInterval?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // set the scene to the view
        self.scene = SCNScene(named: "Basketball.dae")!
        self.scene.physicsWorld.speed = 1.0
        self.scene.physicsWorld.timeStep = 1.0/180.0 //1/60 is default
        self.scene.physicsWorld.contactDelegate = self
        
        self.setupCourtNode()
        self.setupBallNode()
        self.setupBackWallNode()
        self.setupFrontWallNode()
        self.setupHoopNode()
        
        self.setupCamera()
        self.setupLighting()
        
        scnView.pointOfView = self.cameraNode
        scnView.delegate = self
        scnView.scene = scene
        
        // allows the user to manipulate the camera
        scnView.allowsCameraControl = false
        
        //scnView.antialiasingMode = SCNAntialiasingMode.Multisampling2X
        
        // show statistics such as fps and timing information
        scnView.showsStatistics = true
        
        // configure the view
        scnView.backgroundColor = UIColor.black
        
        // add a tap gesture recognizer
        let tapGesture = UILongPressGestureRecognizer(target: self, action: #selector(GameViewController.handleLongTap(_:)))
        tapGesture.minimumPressDuration = 0.01
        
        var gestureRecognizers = [UIGestureRecognizer]()
        gestureRecognizers.append(tapGesture)
        if let existingGestureRecognizers = scnView.gestureRecognizers {
            gestureRecognizers.append(contentsOf: existingGestureRecognizers)
        }
        scnView.gestureRecognizers = gestureRecognizers
        
        self.ballPositions = [BallPosition]()
        
        self.isMapViewExpanded = false
    }
    
    func renderer(_ aRenderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
        
        let mapUpdatesPerSec = 10.0
        
        if (mapUpdateTimeInterval == nil || (time - mapUpdateTimeInterval!) > (1.0 / mapUpdatesPerSec) ) {
            
            DispatchQueue.main.async(execute: {
                let basketballNode = scene.rootNode.childNode(withName: "Basketball", recursively: true)!
                let position = basketballNode.presentation.position
                
                self.updateMapBallPosition(position: position)
                self.updateMapBallStartPosition(position: self.ballStartPosition)
            })
            
            mapUpdateTimeInterval = time
        }

    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.view.layoutIfNeeded()
        
        self.setupMapView()
        
        self.setBallStartPosition(position: SCNVector3(x: 0.0, y: ballYMin, z: 3.0))
        
        self.resetBasketMadeChecks()
        
    }
    
    func setupMapView () {
        self.mapView.isUserInteractionEnabled = true
        self.mapView.backgroundColor = UIColor.black.withAlphaComponent(0.0)
        
        self.setupMapTitleView()
        self.setupMapImageView()
        self.setupMapViewButtons()
        
        self.setupMapViewConstraints()
    }
    
    func setupMapTitleView () {
        self.mapTitleLabel = UILabel(frame: CGRect.zero)
        self.mapTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let titleText = "\nBasketball Shooting Location"
        let titleText2 = "\n(Tap To Change)"
        
        let titleFont = UIFont.boldSystemFont(ofSize: 26.0)
        let titleFont2 = UIFont.systemFont(ofSize: 24.0)
        
        let titleAttributedText = NSMutableAttributedString(string: titleText, attributes: [NSFontAttributeName:titleFont, NSForegroundColorAttributeName:UIColor.white])
        let titleAttributedText2 = NSMutableAttributedString(string: titleText2, attributes: [NSFontAttributeName:titleFont2, NSForegroundColorAttributeName:UIColor.lightGray])
        
        titleAttributedText.append(titleAttributedText2)
        
        self.mapTitleLabel.attributedText = titleAttributedText
        self.mapTitleLabel.numberOfLines = 0
        self.mapTitleLabel.textAlignment = NSTextAlignment.center
        
        self.mapTitleLabel.alpha = 0
        
        self.mapView.addSubview(self.mapTitleLabel)
        
    }
    
    func setupMapViewConstraints () {
        
        //title constraints
        
        let leftTitleConstraint = NSLayoutConstraint(item: self.mapView, attribute: .left, relatedBy: .equal, toItem: self.mapTitleLabel, attribute: .left, multiplier: 1.0, constant: 0.0)
        let rightTitleConstraint = NSLayoutConstraint(item: self.mapView, attribute: .right, relatedBy: .equal, toItem: self.mapTitleLabel, attribute: .right, multiplier: 1.0, constant: 0.0)
        let topTitleConstraint = NSLayoutConstraint(item: self.mapView, attribute: .top, relatedBy: .equal, toItem: self.mapTitleLabel, attribute: .top, multiplier: 1.0, constant: 0.0)
        
        self.mapTitleHeightConstraint = NSLayoutConstraint(item: self.mapTitleLabel, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1.0, constant: 0.0)
        self.mapView.addConstraints([leftTitleConstraint, rightTitleConstraint,topTitleConstraint,self.mapTitleHeightConstraint])
        
        
        //image constraints
        
        let leftImageConstraint = NSLayoutConstraint(item: self.mapView, attribute: .left, relatedBy: .equal, toItem: self.mapImageView, attribute: .left, multiplier: 1.0, constant: 0.0)
        let rightImageConstraint = NSLayoutConstraint(item: self.mapView, attribute: .right, relatedBy: .equal, toItem: self.mapImageView, attribute: .right, multiplier: 1.0, constant: 0.0)
        let topImageConstraint = NSLayoutConstraint(item: self.mapTitleLabel, attribute: .bottom, relatedBy: .equal, toItem: self.mapImageView, attribute: .top, multiplier: 1.0, constant: 0.0)
        let height = self.mapView.bounds.size.height
        
        self.mapImageHeightConstraint = NSLayoutConstraint(item: self.mapImageView, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1.0, constant: height)
        
        self.mapView.addConstraints([leftImageConstraint, rightImageConstraint,topImageConstraint,self.mapImageHeightConstraint])
        
        //button constraints
        
        let leftConfirmButtonConstraint = NSLayoutConstraint(item: self.mapView, attribute: .left, relatedBy: .equal, toItem: self.mapViewConfirmButton, attribute: .left, multiplier: 1.0, constant: -10.0)
        let topConfirmButtonConstraint = NSLayoutConstraint(item: self.mapViewConfirmButton, attribute: .top, relatedBy: .equal, toItem: self.mapImageView, attribute: .bottom, multiplier: 1.0, constant: 10.0)
        let topCancelButtonConstraint = NSLayoutConstraint(item: self.mapViewCancelButton, attribute: .top, relatedBy: .equal, toItem: self.mapImageView, attribute: .bottom, multiplier: 1.0, constant: 10.0)
        let middleButtonConstraint = NSLayoutConstraint(item: self.mapViewConfirmButton, attribute: .right, relatedBy: .equal, toItem: self.mapViewCancelButton, attribute: .left, multiplier: 1.0, constant: -10.0)
        let rightCancelButtonConstraint = NSLayoutConstraint(item: self.mapView, attribute: .right, relatedBy: .equal, toItem: self.mapViewCancelButton, attribute: .right, multiplier: 1.0, constant: 10.0)
        let buttonEqualWidth = NSLayoutConstraint(item: self.mapViewConfirmButton, attribute: .width, relatedBy: .equal, toItem: self.mapViewCancelButton, attribute: .width, multiplier: 1.0, constant: 0.0)
        let buttonEqualHeight = NSLayoutConstraint(item: self.mapViewConfirmButton, attribute: .height, relatedBy: .equal, toItem: self.mapViewCancelButton, attribute: .height, multiplier: 1.0, constant: 0.0)
        
        self.buttonHeightConstraint = NSLayoutConstraint(item: self.mapViewConfirmButton, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1.0, constant: 0.0)
        self.mapView.addConstraints([leftConfirmButtonConstraint,topConfirmButtonConstraint,topCancelButtonConstraint,middleButtonConstraint,rightCancelButtonConstraint,buttonEqualWidth,buttonEqualHeight, self.buttonHeightConstraint])
        
        
    }
    
    func setupMapImageView () {
        self.mapImageView = UIImageView(image: UIImage(contentsOfFile: Bundle.main.path(forResource: "basketballHalfCourt", ofType: "png")!))
        self.mapImageView.translatesAutoresizingMaskIntoConstraints = false
        self.mapImageView.contentMode = UIViewContentMode.scaleAspectFit
        self.mapView.addSubview(self.mapImageView)
        self.mapImageView.isUserInteractionEnabled = true

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(GameViewController.handleMapTap(_:)))
        tapGesture.numberOfTapsRequired = 1
        self.mapImageView.addGestureRecognizer(tapGesture)
    }
    
    func setupMapViewButtons () {
        
        self.mapViewConfirmButton = UIButton(frame: CGRect.zero)
        self.mapViewConfirmButton.translatesAutoresizingMaskIntoConstraints = false
        self.mapViewConfirmButton.setTitle("Confirm Change", for: UIControlState())
        self.mapViewConfirmButton.backgroundColor = UIColor.blue
        self.mapViewConfirmButton.layer.cornerRadius = 15.0
        self.mapViewConfirmButton.layer.borderWidth = 1.0
        self.mapViewConfirmButton.layer.borderColor = UIColor.black.cgColor
        self.mapViewConfirmButton.addTarget(self, action: #selector(GameViewController.mapViewConfirmTapped(_:)), for: UIControlEvents.touchUpInside)
        
        self.mapView.addSubview(self.mapViewConfirmButton)
        
        
        self.mapViewCancelButton = UIButton(frame: CGRect.zero)
        self.mapViewCancelButton.translatesAutoresizingMaskIntoConstraints = false
        self.mapViewCancelButton.setTitle("Cancel", for: UIControlState())
        self.mapViewCancelButton.backgroundColor = UIColor.blue
        self.mapViewCancelButton.layer.cornerRadius = 15.0
        self.mapViewCancelButton.layer.borderWidth = 1.0
        self.mapViewCancelButton.layer.borderColor = UIColor.black.cgColor
        self.mapViewCancelButton.addTarget(self, action: #selector(GameViewController.mapViewCancelTapped(_:)), for: UIControlEvents.touchUpInside)
        
        self.mapView.addSubview(self.mapViewCancelButton)
        
        self.mapViewConfirmButton.alpha = 0.0
        self.mapViewCancelButton.alpha = 0.0
        
        self.mapView.layoutIfNeeded()
        
    }
    
    func mapViewConfirmTapped(_ recognizer:UIButton) {
        print("confirm tapped")
        
        self.ballLastStartPosition = nil
        
        self.animateMapViewExpand(false)
        self.isMapViewExpanded = false
    }
    
    func mapViewCancelTapped(_ recognizer:UIButton) {
        print("cancel tapped")
        
        self.setBallStartPosition(position: self.ballLastStartPosition!)
        
        self.animateMapViewExpand(false)
        self.isMapViewExpanded = false
    }
    
    func animateMapViewExpand(_ expandBool : Bool) {
        
        var width = CGFloat(0.0)
        var height = CGFloat(0.0)
        var left = CGFloat(0.0)
        var top = CGFloat(0.0)
        var titleHeight = CGFloat(0.0)
        
        if (expandBool) {
            
            left = 0.0
            width = self.view.bounds.size.width
            height = self.view.bounds.size.height
            top = 0
            titleHeight = 120
            
        } else {
            
            width = 75.0
            height = 75.0
            top = 30.0  //20.0 for top guide and then 10 more for space
            left = 10.0
            titleHeight = 0
            
        }
        
        self.ballPositionView!.alpha = 0
        self.ballStartPositionView!.alpha = 0
        
        self.mapView.layoutIfNeeded()
        
        UIView.animate(withDuration: 0.5, delay: 0, options: UIViewAnimationOptions.allowAnimatedContent, animations: { () -> Void in
            
            self.mapViewConstraintWidth.constant = width
            self.mapViewConstraintHeight.constant = height
            self.mapViewConstraintLeft.constant = left
            self.mapViewConstraintTop.constant = top
            self.mapImageHeightConstraint.constant = width
            self.mapTitleHeightConstraint.constant = titleHeight
            
            if (expandBool) {
                self.buttonHeightConstraint.constant = 40.0
                self.mapViewConfirmButton.alpha = 1.0
                self.mapViewCancelButton.alpha = 1.0
                self.mapTitleLabel.alpha = 1.0
                self.mapView.backgroundColor = UIColor.black.withAlphaComponent(0.8)
                
            } else {
                self.buttonHeightConstraint.constant = 0.0
                self.mapViewConfirmButton.alpha = 0.0
                self.mapViewCancelButton.alpha = 0.0
                self.mapTitleLabel.alpha = 0.0
                self.mapView.backgroundColor = UIColor.black.withAlphaComponent(0.0)
            }
            
            self.mapView.layoutIfNeeded()
            
            }) { (finished:Bool) -> Void in
                
                self.ballStartPositionView!.alpha = 1
                
                if expandBool == false {
                    self.ballPositionView!.alpha = 1
                }
        }
        
    }
    
    
    func updateMapBallPosition(position:SCNVector3) {
        
        if ( self.ballPositionView == nil ) {
            self.ballPositionView = self.makeBallPositionView()
            self.mapImageView.addSubview(self.ballPositionView!)
            self.mapImageView.sendSubview(toBack: self.ballPositionView!)
        }
        
        if (self.isMapViewExpanded == true) {
            self.ballPositionView!.frame.size = CGSize(width: 20, height: 20)
        } else {
            self.ballPositionView!.frame.size = CGSize(width: 10, height: 10)
        }
        self.ballPositionView!.layer.cornerRadius = self.ballPositionView!.frame.size.height / 2.0
        
        let mapBallPosition = self.mapBallPositionFromBallPosition(position)
        self.ballPositionView!.center = mapBallPosition
        
    }
    
    func updateMapBallStartPosition(position:SCNVector3) {
        
        if ( self.ballStartPositionView == nil ) {
            
            self.ballStartPositionView = self.makeBallStartPositionView()
            self.mapImageView.addSubview(self.ballStartPositionView!)
            self.mapImageView.bringSubview(toFront: self.ballStartPositionView!)
        }
        
        if (self.isMapViewExpanded == true) {
            self.ballStartPositionView!.frame.size = CGSize(width: 20, height: 20)
            
        } else {
            self.ballStartPositionView!.frame.size = CGSize(width: 10, height: 10)
        }
        self.ballStartPositionView!.layer.cornerRadius = self.ballStartPositionView!.frame.size.height / 2.0
        
        
        let mapBallStartPosition = self.mapBallPositionFromBallPosition(position)
        self.ballStartPositionView!.center = mapBallStartPosition
        
    }
    
    func makeBallPositionView () -> UIView {
        
        let viewFrame = CGRect(x: 0, y: 0, width: 10, height: 10)
        let view = UIView(frame: viewFrame)
        view.translatesAutoresizingMaskIntoConstraints = false
        
        view.backgroundColor = UIColor.orange
        view.layer.cornerRadius = view.frame.size.height / 2.0
        view.layer.borderColor = UIColor.black.cgColor
        view.layer.borderWidth = 1.0
        
        return view
    }
    
    func makeBallStartPositionView () -> UIView {
        let viewFrame = CGRect(x: 0, y: 0, width: 10, height: 10)
        let view = UIView(frame: viewFrame)
        view.translatesAutoresizingMaskIntoConstraints = false
        
        view.backgroundColor = UIColor.green
        view.layer.cornerRadius = view.frame.size.height / 2.0
        view.layer.borderColor = UIColor.black.cgColor
        view.layer.borderWidth = 1.0
        
        return view
    }
    
    func mapBallPositionFromBallPosition(_ position:SCNVector3) -> CGPoint {
        let ballPosition = position
        
        let mapWidth = self.mapImageView.frame.size.width
        let mapHeight = self.mapImageView.frame.size.height
        
        let widthRatio = Float(mapWidth / courtWidth())
        let heightRatio = Float(mapHeight / courtLength())
        
        let adjustedX = ballPosition.x * widthRatio
        let adjustedY = ballPosition.y
        let adjustedZ = (ballPosition.z + Float(kHoopDistanceFromWall)) * heightRatio
        
        let adjustedPosition = SCNVector3(x: adjustedX, y: adjustedY, z: adjustedZ)
        
        let mappedX = Float(mapWidth) / 2.0 + adjustedPosition.x
        let mappedY = adjustedPosition.z
        
        return CGPoint(x: CGFloat(mappedX), y: CGFloat(mappedY))
    }
    
    func ballPositionFromMapPosition(_ position:CGPoint) -> SCNVector3 {
        let mapPosition = position
        
        let mapWidth = self.mapImageView.frame.size.width
        let mapHeight = self.mapImageView.frame.size.height
        
        let x = Float(mapPosition.x) - Float(mapWidth) / 2.0
        let z = Float(mapPosition.y)
        let y = self.ballYMin
        
        let widthRatio = Float(mapWidth / courtWidth())
        let heightRatio = Float(mapHeight / courtLength())
        
        let adjustedX = x / widthRatio
        let adjustedY = y
        let adjustedZ = z / heightRatio - Float(kHoopDistanceFromWall)
        
        return SCNVector3(x: adjustedX, y: adjustedY!, z: adjustedZ)
        
    }
    
    func handleMapTap(_ recognizer:UIGestureRecognizer) {
        print("map tapped")
        
        //stop ball from rolling because it just looks weird
        self.basketballNode.physicsBody!.angularVelocity = SCNVector4(x: 0, y: 0, z: 0, w: 0)
        
        if (self.isMapViewExpanded == false) {
            
            if (self.ballLastStartPosition == nil) {
                self.ballLastStartPosition = self.ballStartPosition
            }
            
            self.animateMapViewExpand(true)
            self.isMapViewExpanded = true
            
        } else {
            
            let newBallPoint = recognizer.location(in: self.mapImageView)
            let newBallPosition = self.ballPositionFromMapPosition(newBallPoint)
            
            self.setBallStartPosition(position: newBallPosition)
        }
    }
    
    func resetBasketMadeChecks () {
        
        self.isOKToScoreBasket = true
        
        self.rimPlaneCollided = false
    }
    
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        self.checkBasketMade(contact:contact)
        self.checkBallBounceOffSurface(contact:contact)
    }
    
    func checkBallBounceOffSurface(contact: SCNPhysicsContact) {
        
        let surfacesToShowBounceBitMask = [Collisions.Backboard, Collisions.Wall, Collisions.Pole]
        
        let contactMask =
        contact.nodeB.physicsBody!.categoryBitMask
        
        if (contactMask > 0 && surfacesToShowBounceBitMask.contains(Collisions.None)) {
            self.addParticleForBounceAtCoordinates(contact.contactPoint)
        }
    }
    
    
    func checkBasketMade(contact: SCNPhysicsContact) {
        
        let surfacesToShowBounceBitMask = Collisions.HoopNetSpace
        
        let contactMask =
        contact.nodeB.physicsBody!.categoryBitMask
        
        if ((contactMask & surfacesToShowBounceBitMask.rawValue) > 0) {
            // check that at least half of the ball is in the bucked and the rim plane was contacted
            if (contact.penetrationDistance >= kBallRadius && contact.contactNormal.y > 0 && self.isOKToScoreBasket == true) {
                
                self.highlightNode(self.backboardNode)
                self.highlightNode(self.hoopNetNode)
                
                self.isOKToScoreBasket = false
            }
        }
    }
    
    func checkRimPlaneCollisionForPhysicsContact(_ contact: SCNPhysicsContact) {
        let surfacesToCheck = Collisions.RimPlane
        let contactMask = contact.nodeB.physicsBody!.categoryBitMask
        
        if ((contactMask & surfacesToCheck.rawValue) > 0) {
            
            self.rimPlaneCollided = true
            
        }
    }
    
    func addParticleForBounceAtCoordinates(_ coordinates:SCNVector3) {
        let particles = SCNParticleSystem(named: "MyParticleSystem", inDirectory: "" )
        let transformMatrix = SCNMatrix4MakeTranslation(coordinates.x, coordinates.y, coordinates.z)
        
        self.scene.addParticleSystem(particles!, transform: transformMatrix)
    }
    
    func highlightNode(_ node:SCNNode) {
        
        let material = node.geometry!.firstMaterial!
        
        // highlight it
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.1
        
        // on completion - unhighlight
        SCNTransaction.completionBlock = {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.5
            
            material.emission.contents = UIColor.black
            
            SCNTransaction.commit()
        }
        
        material.emission.contents = UIColor.green
        
        SCNTransaction.commit()
        
    }
    
    func setupLighting () {
        
        let spotLight = SCNLight()
        spotLight.type = SCNLight.LightType.spot
        spotLight.attenuationStartDistance = 0.0
        spotLight.attenuationEndDistance = 55.0
        spotLight.attenuationFalloffExponent = 2.0
        
        spotLight.spotInnerAngle = 150.0
        spotLight.spotOuterAngle = 150.0

        spotLight.castsShadow = true
        spotLight.categoryBitMask = 2
        
        let spotlightNode = SCNNode()
        spotlightNode.light = spotLight
        spotlightNode.position = SCNVector3(x: 0, y: 30, z: Float(courtLength() / 2.0))
        spotlightNode.eulerAngles = SCNVector3(x: Float(M_PI_2 * 3.0), y: 0, z: 0)
        scene.rootNode.addChildNode(spotlightNode)
        
        let light = SCNLight()
        light.type = SCNLight.LightType.omni
        light.attenuationStartDistance = 0.0
        light.attenuationEndDistance = 55.0
        light.attenuationFalloffExponent = 2.0
        
        let lightSpacing = Float(courtLength() / 2.0)
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
        
        // create and add an ambient light to the scene
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light!.type = SCNLight.LightType.ambient
        ambientLightNode.light!.color = UIColor(white: 0.50, alpha: 1.0)
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
    }
    
    func setupBallNode () {
        
        self.basketballNode = scene.rootNode.childNode(withName: "Basketball", recursively: true)!
        
        
        let scale = Float(kBallRadius / 1.0)
        self.basketballNode.scale = SCNVector3(x: scale, y: scale, z: scale)
        
        self.ballYMin = 1.0 * scale
        
        
        let ballBody = SCNPhysicsBody(type: SCNPhysicsBodyType.dynamic, shape: SCNPhysicsShape(geometry: SCNSphere(radius: CGFloat(1.0) * CGFloat(scale)), options:nil))
        
        ballBody.mass = kBallMass
        ballBody.damping = 0.0
        ballBody.angularDamping = 0.2
        ballBody.velocity = SCNVector3(x: 0.0, y: 0.0, z: 0.0)
        ballBody.angularVelocity = SCNVector4(x: 0.0, y: 0.0, z: 0.0, w: 0.0)
        ballBody.restitution = 1.0
        ballBody.friction = 0.2
        ballBody.rollingFriction = 1.0
        
        ballBody.categoryBitMask = Collisions.Ball.rawValue
        
        self.basketballNode.physicsBody = ballBody
    }
    
    func setBallStartPosition(position:SCNVector3) {
        
        self.basketballNode.position = SCNVector3(x: position.x, y: ballYMin, z: position.z)
        self.basketballNode.physicsBody!.resetTransform()
        
        self.cameraNode.eulerAngles = self.cameraAngleRelativeToBallPosition(self.basketballNode.position)
        self.cameraNode.position = self.cameraPositionRelativeToBallPosition(self.basketballNode.position)
        
        self.ballStartPosition = position
        
        self.updateMapBallPosition(position:self.ballStartPosition)
        self.updateMapBallStartPosition(position:self.ballStartPosition)
    }
    
    func angleRelativeToBallPosition(_ position:SCNVector3) -> Float {
        
        let x = position.x
        let z = position.z != 0 ? position.z : 0.00001
        
        var angle = atan(x/z)
        
        if (z<0) {
            angle += Float(M_PI)
        }
        
        return angle
    }
    
    func cameraPositionRelativeToBallPosition(_ position:SCNVector3) -> SCNVector3 {
        
        let angle = self.angleRelativeToBallPosition(position)
        
        let cameraAdditionalX = sin(angle) * kCameraOffset
        let cameraAdditionalZ = cos(angle) * kCameraOffset
        
        let cameraHeight = Float(2.0)
        
        return SCNVector3(x: position.x + cameraAdditionalX, y: cameraHeight, z: position.z + cameraAdditionalZ)
    }
    
    func cameraAngleRelativeToBallPosition(_ position:SCNVector3) -> SCNVector3 {
        
        let angle = self.angleRelativeToBallPosition(position) * -1.0
        
        return SCNVector3(x: Float(M_PI_2 - M_PI_2 * kCameraAngleRatio ), y: (0.0 - angle) , z: 0.0)
    }
    
    func setupCourtNode () {
        
        self.courtNode = scene.rootNode.childNode(withName: "Court", recursively: true)!
        self.courtNode.removeFromParentNode()
        self.courtNode.castsShadow = false

        let courtLength = self.courtLength()
        let courtWidth = self.courtWidth()
        let courtThickness = CGFloat(0.5)
        
        let courtGeometry = SCNBox(width: courtWidth, height: courtThickness, length: courtLength, chamferRadius: 0)
        
        courtGeometry.firstMaterial!.diffuse.contents = UIImage(contentsOfFile: Bundle.main.path(forResource: "basketballHalfCourt", ofType: "png")!)
        
        self.courtNode = SCNNode(geometry: courtGeometry)
        self.courtNode.position = SCNVector3(x: 0.0, y: Float(-courtThickness / 2.0), z: Float(courtLength / 2.0 - kHoopDistanceFromWall))
        self.courtNode.eulerAngles = SCNVector3(x: 0, y: 0, z: 0)
        
        self.courtNode.name = "Court"
        
        self.scene.rootNode.addChildNode(self.courtNode)
        
        self.courtNode.categoryBitMask = 2
        
        let bodyScaleVector = SCNVector3(x: 1.1, y: 1.0, z: 1.1)
        let vectorValue = NSValue(scnVector3:bodyScaleVector)
        
        let courtBody = SCNPhysicsBody(type: SCNPhysicsBodyType.static, shape: SCNPhysicsShape(geometry: self.courtNode.geometry!, options:[SCNPhysicsShape.Option.type:SCNPhysicsShape.ShapeType.boundingBox, SCNPhysicsShape.Option.scale:vectorValue]))
        courtBody.friction = 1.0
        courtBody.rollingFriction = 1.0
        
        courtBody.categoryBitMask = Collisions.Floor.rawValue
        
        self.courtNode.physicsBody = courtBody
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
        rimGeometry.firstMaterial!.diffuse.contents = UIColor.red
        
        self.rimNode = SCNNode(geometry: rimGeometry)
        self.rimNode.position = SCNVector3(x: 0, y: Float(rimHeight), z: 0)
        self.rimNode.castsShadow = false

        self.hoopNode.addChildNode(self.rimNode)
        
        let rimBody = SCNPhysicsBody(type: SCNPhysicsBodyType.static, shape: SCNPhysicsShape(geometry: self.rimNode.geometry!, options: [SCNPhysicsShape.Option.type:SCNPhysicsShape.ShapeType.concavePolyhedron]))
        rimBody.friction = 0.5
        rimBody.rollingFriction = 0.5
        
        rimBody.categoryBitMask = Collisions.Rim.rawValue
        
        self.rimNode.physicsBody = rimBody
        
        let hoopNetHeight = CGFloat(0.45)
        
        let hoopNetGeometry = SCNTube(innerRadius: rimRadius, outerRadius: rimRadius + 0.02, height: hoopNetHeight)
        hoopNetGeometry.firstMaterial!.diffuse.contents = UIImage(contentsOfFile: Bundle.main.path(forResource: "net", ofType: "png")!)
        
        self.hoopNetNode = SCNNode(geometry: hoopNetGeometry)
        self.hoopNetNode.position = SCNVector3(x: 0, y: Float(rimHeight - hoopNetHeight / 2.0), z: 0)
        
        self.hoopNetNode.name = "HoopNet"
        self.hoopNetNode.castsShadow = false

        self.hoopNode.addChildNode(self.hoopNetNode)
        
        let hoopNetBody = SCNPhysicsBody(type: SCNPhysicsBodyType.static, shape: SCNPhysicsShape(geometry: self.hoopNetNode.geometry!, options: [SCNPhysicsShape.Option.type:SCNPhysicsShape.ShapeType.concavePolyhedron]))
        
        hoopNetBody.friction = 1.0
        hoopNetBody.rollingFriction = 0.0
        
        hoopNetBody.categoryBitMask = Collisions.HoopNet.rawValue
        
        
        self.hoopNetNode.physicsBody = hoopNetBody
    
        // !!! lowering radius of hoopnet space so it does not run touch the hoopnet, which registers as contact and slows down processing
        let hoopNetSpaceGeometry = SCNCylinder(radius: rimRadius - 0.05, height: hoopNetHeight)
        
        self.hoopNetSpaceNode = SCNNode(geometry: hoopNetSpaceGeometry)
        self.hoopNetSpaceNode.position = SCNVector3(x: 0, y: Float(rimHeight - hoopNetHeight / 2.0), z: 0)
        
        self.hoopNetSpaceNode.name = "HoopNet"
        self.hoopNetSpaceNode.castsShadow = false

        self.hoopNode.addChildNode(self.hoopNetSpaceNode)
        
        let hoopNetSpaceBody = SCNPhysicsBody(type: SCNPhysicsBodyType.kinematic, shape: SCNPhysicsShape(geometry: self.hoopNetSpaceNode.geometry!, options: nil))
        
        hoopNetSpaceBody.mass = 0.00001
        hoopNetSpaceBody.categoryBitMask = Collisions.HoopNetSpace.rawValue
        
        if #available(iOS 9.0, *) {
            hoopNetSpaceBody.contactTestBitMask = Collisions.Ball.rawValue
        }
        
        self.hoopNetSpaceNode.physicsBody = hoopNetSpaceBody
        self.hoopNetSpaceNode.categoryBitMask = 0 //not visible to camera, but physics do work
        
        let backboardHeight = CGFloat(1.0)
        let backboardWidth = CGFloat(1.5)
        let backboardThickness = CGFloat(0.1)
        let backboardRimGap = CGFloat(0.125)
        
        let backboardGeometry = SCNBox(width: backboardWidth, height: backboardHeight, length: backboardThickness, chamferRadius: 0.05)
        backboardGeometry.firstMaterial!.diffuse.contents = UIImage(contentsOfFile: Bundle.main.path(forResource: "backboard", ofType: "png")!)
        
        self.backboardNode = SCNNode(geometry: backboardGeometry)
        self.backboardNode.position = SCNVector3(x: 0, y: Float(rimHeight + backboardHeight / 2.0) - 0.075, z: Float(-backboardThickness/2.0) - Float(rimRadius + rimPipeRadius * 2.0) - Float(backboardRimGap))
        
        self.backboardNode.name = "Backboard"
        
        self.backboardNode.categoryBitMask = 2
        self.backboardNode.castsShadow = false
        
        self.hoopNode.addChildNode(self.backboardNode)
        
        let backboardBody = SCNPhysicsBody(type: SCNPhysicsBodyType.static, shape: SCNPhysicsShape(geometry: self.backboardNode.geometry!, options: [SCNPhysicsShape.Option.type:SCNPhysicsShape.ShapeType.boundingBox]))
        backboardBody.friction = 0.5
        backboardBody.rollingFriction = 0.5
        
        backboardBody.categoryBitMask = Collisions.Backboard.rawValue
        
        self.backboardNode.physicsBody = backboardBody
        
        let rimGapWidth = CGFloat(0.1)
        
        let backboardRimGapGeometry = SCNBox(width: rimGapWidth, height: rimPipeRadius * 2.0, length: backboardRimGap, chamferRadius: 0.0)
        backboardRimGapGeometry.firstMaterial!.diffuse.contents = UIColor.red
        
        self.backboardRimGapNode = SCNNode(geometry: backboardRimGapGeometry)
        self.backboardRimGapNode.position = SCNVector3(x: 0, y: Float(rimHeight), z: -Float(rimRadius + rimPipeRadius * 2.0) - Float(backboardRimGap/2.0))
        
        self.backboardRimGapNode.name = "BackboardRimGap"
        self.backboardRimGapNode.castsShadow = false

        self.hoopNode.addChildNode(self.backboardRimGapNode)
        
        let backboardRimGapBody = SCNPhysicsBody(type: SCNPhysicsBodyType.static, shape: SCNPhysicsShape(geometry: self.backboardRimGapNode.geometry!, options: [SCNPhysicsShape.Option.type:SCNPhysicsShape.ShapeType.boundingBox]))
        backboardRimGapBody.friction = 1.0
        backboardRimGapBody.rollingFriction = 1.0
        
        backboardRimGapBody.categoryBitMask = Collisions.Rim.rawValue
        
        self.backboardRimGapNode.physicsBody = backboardRimGapBody
        
        let poleRadius = CGFloat(0.05)
        let poleHeight = rimHeight + backboardHeight / 2.0
        
        let poleGeometry = SCNCylinder(radius: poleRadius, height: poleHeight)

        poleGeometry.firstMaterial!.diffuse.contents = UIColor.gray
        
        self.hoopPoleNode = SCNNode(geometry: poleGeometry)
        self.hoopPoleNode.position = SCNVector3(x: 0, y: Float(poleHeight / CGFloat(2.0)), z: Float(-kHoopDistanceFromWall + 0.4))
        self.hoopPoleNode.castsShadow = false

        self.hoopPoleNode.name = "HoopPole"
        
        self.hoopNode.addChildNode(self.hoopPoleNode)
        
        let poleBody = SCNPhysicsBody(type: SCNPhysicsBodyType.static, shape: SCNPhysicsShape(geometry: self.hoopPoleNode.geometry!, options: [SCNPhysicsShape.Option.type:SCNPhysicsShape.ShapeType.boundingBox]))
        poleBody.friction = 1.0
        poleBody.rollingFriction = 1.0
        
        poleBody.categoryBitMask = Collisions.Pole.rawValue
        
        self.hoopPoleNode.physicsBody = poleBody
        
        
        let poleHorizontalGeometry = SCNCylinder(radius: poleRadius, height: CGFloat(self.backboardNode.position.z - self.hoopPoleNode.position.z + Float(poleRadius)))
        poleHorizontalGeometry.firstMaterial!.diffuse.contents = UIColor.gray
        
        self.hoopPoleHorizontalNode = SCNNode(geometry: poleHorizontalGeometry)
        self.hoopPoleHorizontalNode.position = SCNVector3(x: 0, y: Float(poleHeight), z: (self.backboardNode.position.z - self.hoopPoleNode.position.z) / 2.0 + self.hoopPoleNode.position.z - Float(poleRadius) / 2.0)
        self.hoopPoleHorizontalNode.eulerAngles = SCNVector3(x: Float(M_PI_2), y: 0, z: 0)
        
        self.hoopPoleHorizontalNode.name = "HoopPoleHorizontal"
        self.hoopPoleHorizontalNode.castsShadow = false

        self.hoopNode.addChildNode(self.hoopPoleHorizontalNode)
        
        let poleHorizontalBody = SCNPhysicsBody(type: SCNPhysicsBodyType.static, shape: SCNPhysicsShape(geometry: self.hoopPoleHorizontalNode.geometry!, options: [SCNPhysicsShape.Option.type:SCNPhysicsShape.ShapeType.boundingBox]))
        poleHorizontalBody.friction = 1.0
        poleHorizontalBody.rollingFriction = 1.0
        
        poleHorizontalBody.categoryBitMask = Collisions.Pole.rawValue
        
        self.hoopPoleHorizontalNode.physicsBody = poleHorizontalBody
        
    }
    
    func courtLength() -> CGFloat {
        return kCourtFullLength * 1251.0 / 2085.0 //adjust for half court
    }
    
    func courtWidth() -> CGFloat {
        //half coourt is same width as length = 1251 pixels
        return self.courtLength()
        
    }
    
    func setupBackWallNode () {
        
        let wallWidth = self.courtWidth()
        let wallHeight = CGFloat(50.0)
        let wallThickness = CGFloat(0.5)
        
        let backWallZPosition = -kHoopDistanceFromWall
        
        let wallGeometry = SCNBox(width: wallWidth, height: wallHeight, length: wallThickness, chamferRadius: 0)
        
        wallGeometry.firstMaterial!.diffuse.contents = UIColor.blue
        
        self.backWallNode = SCNNode(geometry: wallGeometry)
        self.backWallNode.position = SCNVector3(x: 0.0, y: Float(backWallZPosition), z: Float(backWallZPosition))
        self.backWallNode.eulerAngles = SCNVector3(x: 0, y: 0, z: 0)
        self.backWallNode.castsShadow = false

        self.backWallNode.name = "BackWall"
        
        self.scene.rootNode.addChildNode(self.backWallNode)
        
        let bodyScaleVector = SCNVector3(x: 1.1, y: 1.1, z: 1.0)
        let vectorValue = NSValue(scnVector3:bodyScaleVector)
        
        let wallBody = SCNPhysicsBody(type: SCNPhysicsBodyType.static, shape: SCNPhysicsShape(geometry: self.backWallNode.geometry!, options:[SCNPhysicsShape.Option.type:SCNPhysicsShape.ShapeType.boundingBox,SCNPhysicsShape.Option.scale:vectorValue]))
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
        
        let backWallZPosition = courtLength() - kHoopDistanceFromWall
        
        let wallGeometry = SCNBox(width: wallWidth, height: wallHeight, length: wallThickness, chamferRadius: 0)
        
        self.frontWallNode = SCNNode(geometry: wallGeometry)
        self.frontWallNode.position = SCNVector3(x: 0.0, y: Float(backWallZPosition), z: Float(backWallZPosition))
        self.frontWallNode.eulerAngles = SCNVector3(x: 0, y: 0, z: 0)
        self.frontWallNode.castsShadow = false
        self.frontWallNode.name = "FrontWall"
        
        self.scene.rootNode.addChildNode(self.frontWallNode)
        
        let bodyScaleVector = SCNVector3(x: 1.1, y: 1.1, z: 1.0)
        let vectorValue = NSValue(scnVector3:bodyScaleVector)
        
        let wallBody = SCNPhysicsBody(type: SCNPhysicsBodyType.static, shape: SCNPhysicsShape(geometry: self.backWallNode.geometry!, options:[SCNPhysicsShape.Option.type:SCNPhysicsShape.ShapeType.boundingBox,SCNPhysicsShape.Option.scale:vectorValue]))
        wallBody.friction = 1.0
        wallBody.rollingFriction = 1.0
        
        wallBody.categoryBitMask = Collisions.FrontWall.rawValue
        
        self.frontWallNode.physicsBody = wallBody
        
        self.frontWallNode.categoryBitMask = 0 // invisible to camera
    }
    
    func handleTap(_ gestureRecognize: UIGestureRecognizer) {
        // check what nodes are tapped
        let p = gestureRecognize.location(in: scnView)
        let hitResults = scnView.hitTest(p, options: nil)
        // check that we clicked on at least one object
        if hitResults.count > 0 {
            // retrieved the first clicked object
            let result: AnyObject! = hitResults[0]
            
            // get its material
            let material = result.node!.geometry!.firstMaterial!
            
            // highlight it
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.5
            
            // on completion - unhighlight
            SCNTransaction.completionBlock = {
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.5
                
                material.emission.contents = UIColor.black
                
                SCNTransaction.commit()
            }
            
            material.emission.contents = UIColor.green
            
            SCNTransaction.commit()
        }
    }
    
    func handleLongTap(_ gestureRecognize: UILongPressGestureRecognizer) {
        // retrieve the SCNView
        
        if (gestureRecognize.state == UIGestureRecognizerState.began ||
            gestureRecognize.state == UIGestureRecognizerState.changed ) {
                
                self.moveBallNodeToRecognizer(gestureRecognize)
                self.activateGravity(false)
                
                
                
        } else if (gestureRecognize.state == UIGestureRecognizerState.ended ||
            gestureRecognize.state == UIGestureRecognizerState.cancelled ||
            gestureRecognize.state == UIGestureRecognizerState.failed) {
            
                self.scene.removeAllParticleSystems()
                self.resetBasketMadeChecks()
                
                self.moveBallNodeToRecognizer(gestureRecognize)
                self.activateGravity(true)
                self.addBallVelocity()
                
                self.ballPositions = [BallPosition]()
                
                self.addBallAngularVelocity()
        }
    }
    
    func moveBallNodeToRecognizer(_ gestureRecognize: UILongPressGestureRecognizer) {
        
        let p = gestureRecognize.location(in: scnView)
        let newPosition = self.positionForNode(self.basketballNode, locationInView: p)
        
        self.basketballNode.position = newPosition
        self.basketballNode.physicsBody!.resetTransform()
        
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
            
            let timeElapsed = time2.timeIntervalSince(time1)
            
            xDiff = (ballPosition2.position.x - ballPosition1.position.x) / Float(timeElapsed)
            yDiff = (ballPosition2.position.y - ballPosition1.position.y) / Float(timeElapsed)
            zDiff = (ballPosition2.position.z - ballPosition1.position.z) / Float(timeElapsed)
            
            
        }
        else if (self.ballPositions.count == 3) {
            
            let ballPosition1 = self.ballPositions[2]
            let ballPosition2 = self.ballPositions[1]
            
            let time2 = ballPosition2.date
            let time1 = ballPosition1.date
            
            let timeElapsed = time2.timeIntervalSince(time1)
            
            xDiff = (ballPosition2.position.x - ballPosition1.position.x) / Float(timeElapsed)
            yDiff = (ballPosition2.position.y - ballPosition1.position.y) / Float(timeElapsed)
            zDiff = (ballPosition2.position.z - ballPosition1.position.z) / Float(timeElapsed)
            
        } else if (self.ballPositions.count > 3) {
            
            let ballPosition1 = self.ballPositions[3]
            let ballPosition2 = self.ballPositions[1]
            
            let time2 = ballPosition2.date
            let time1 = ballPosition1.date
            
            let timeElapsed = time2.timeIntervalSince(time1)
            
            xDiff = (ballPosition2.position.x - ballPosition1.position.x) / Float(timeElapsed)
            yDiff = (ballPosition2.position.y - ballPosition1.position.y) / Float(timeElapsed)
            zDiff = (ballPosition2.position.z - ballPosition1.position.z) / Float(timeElapsed)
            
        }
        
        let slowAdjust = Float(1.1)
        
        xDiff /= slowAdjust
        yDiff /= slowAdjust
        zDiff /= slowAdjust
        
        let maxDiff = Float(12.0)
        
        xDiff = min(xDiff,maxDiff)
        yDiff = min(yDiff,maxDiff)
        zDiff = min(zDiff,maxDiff)
        
        //adjust for cameraAngle, want X to have all velocity
        let angleFromBasket = self.angleRelativeToBallPosition(self.cameraNode.position)
        let rotationVector = SCNVector4(x: 0, y: 1, z: 0, w: Float(angleFromBasket * -1.0))
        
        let originalVector = SCNVector3(x: xDiff, y: yDiff, z: zDiff)
        let adjustedVector = self.rotateSCNVector3(originalVector, byRotationSCNVector4: rotationVector)
        
        xDiff = adjustedVector.x
        yDiff = adjustedVector.y
        zDiff = adjustedVector.z
        
        let zVelocity = -zPositionFor(yDiff)
        
        let positionChangeVector = SCNVector3(x: xDiff, y: yDiff, z: zVelocity)
        
        let rotationVector2 = SCNVector4(x: 0, y: 1, z: 0, w: Float(angleFromBasket))
        
        var rotatedVector = self.rotateSCNVector3(positionChangeVector, byRotationSCNVector4: rotationVector2)
        
        let ballLandingSpot = self.landingSpotForBallLaunchPosition(self.basketballNode.position, actualLaunchVector: rotatedVector)
        
        let idealLaunchVector = self.idealLaunchVectorForBallLaunchPosition(self.basketballNode.position, actualLaunchVector: rotatedVector)
        
        if (!ballLandingSpot.x.isNaN && !ballLandingSpot.z.isNaN) {
            
            let landingSpotDistanceFromBasket = sqrt( ballLandingSpot.x * ballLandingSpot.x + ballLandingSpot.z * ballLandingSpot.z )
            
            if (!idealLaunchVector.y.isNaN ) {
                var blendRatioVertical = Float(0) //ratio of real to ideal
                var blendRatioHorizontal = Float(0) //ratio of real to ideal
                
                if (landingSpotDistanceFromBasket < 0.5) {
                    
                    blendRatioVertical = Float(0.15)
                    blendRatioHorizontal = Float(0.15)
                    
                }
                else if (landingSpotDistanceFromBasket < 1.0) {
                    
                    blendRatioVertical = Float(0.2)
                    blendRatioHorizontal = Float(0.2)
                    
                } else if (landingSpotDistanceFromBasket < 2.0) {
                    
                    blendRatioVertical = Float(0.3)
                    blendRatioHorizontal = Float(0.3)
                    
                } else if (landingSpotDistanceFromBasket < 3.0) {
                    
                    blendRatioVertical = Float(0.4)
                    blendRatioHorizontal = Float(0.4)
                    
                } else if (landingSpotDistanceFromBasket < 5.0) {
                    
                    blendRatioVertical = Float(0.6)
                    blendRatioHorizontal = Float(0.6)
                    
                } else {
                    
                    blendRatioVertical = Float(1.0)
                    blendRatioHorizontal = Float(1.0)
                }
                
                print("blended ratio: \(blendRatioHorizontal)")
                
                let newX = rotatedVector.x * blendRatioHorizontal + idealLaunchVector.x * (1.0 - blendRatioHorizontal)
                let newY = rotatedVector.y * blendRatioVertical + idealLaunchVector.y * (1.0 - blendRatioVertical)
                let newZ = rotatedVector.z * blendRatioVertical + idealLaunchVector.z * (1.0 - blendRatioVertical)
                
                rotatedVector = SCNVector3(x: newX, y: newY, z: newZ)
            
            }
            
        }
        
        self.basketballNode.physicsBody!.velocity = rotatedVector
        
        self.launchInfo = LaunchInfo(position: self.basketballNode.position, initialVelocity: self.basketballNode.physicsBody!.velocity)
    }
    
    func idealLaunchVectorForBallLaunchPosition (_ position: SCNVector3, actualLaunchVector:SCNVector3) -> SCNVector3 {
        
        //get ball distance from rim center
        let xDistance = self.rimNode.position.x - position.x
        let yDistance = self.rimNode.position.y - position.y
        let zDistance = self.rimNode.position.z - position.z
        
        //let totalDistance = sqrt(xDistance * xDistance + yDistance * yDistance + zDistance * zDistance)
        
        //get time by dividing total distance by total original velocity
        //let time = totalDistance / totalVelocity
        
        //y = actualLaunchVector.y * t - 4.9 * t^2
        
        let gravity = Float(4.9)
        
        let aa = Float(-gravity)
        let bb = actualLaunchVector.y
        let cc = -yDistance
        
        //let d = ( -bb + sqrt( bb * bb - 4.0 * aa * cc ) ) / (2.0 * aa)
        let e = ( -bb - sqrt( bb * bb - 4.0 * aa * cc ) ) / (2.0 * aa)
        
        let time = e
        
        let yVector = (yDistance + gravity * time * time) / time
        
        return SCNVector3(x: xDistance / time, y: yVector , z: zDistance / time)
    }
    
    func landingSpotForBallLaunchPosition (_ position: SCNVector3, actualLaunchVector:SCNVector3) -> SCNVector3 {
        
        //get ball distance from rim center
        //let xDistance = self.rimNode.position.x - position.x
        let yDistance = self.rimNode.position.y - position.y
        //let zDistance = self.rimNode.position.z - position.z - 0.1
        
        //let totalDistance = sqrt(xDistance * xDistance + yDistance * yDistance + zDistance * zDistance)
        
        //get time by dividing total distance by total original velocity
        //let time = totalDistance / totalVelocity
        
        //y = actualLaunchVector.y * t - 4.9 * t^2
        
        let gravity = Float(4.9)
        
        let aa = Float(-gravity)
        let bb = actualLaunchVector.y
        let cc = -yDistance
        
        //let d = ( -bb + sqrt( bb * bb - 4.0 * aa * cc ) ) / (2.0 * aa)
        let e = ( -bb - sqrt( bb * bb - 4.0 * aa * cc ) ) / (2.0 * aa)
        
        let time = e
        
        let yLandingSpot = position.y - cc
        let xLandingSpot = position.x + actualLaunchVector.x * time
        let zLandingSpot = position.z + actualLaunchVector.z * time
        
        return SCNVector3(x: xLandingSpot, y: yLandingSpot , z: zLandingSpot)
    }
    
    func rotateSCNVector3(_ startSCNVector3:SCNVector3, byRotationSCNVector4 rotationVector:SCNVector4) -> SCNVector3 {
        
        let matrix = SCNMatrix4MakeRotation(rotationVector.w, rotationVector.x, rotationVector.y, rotationVector.z)
        
        let GLKmatrix = SCNMatrix4ToGLKMatrix4(matrix)
        
        let GLKvector = GLKVector3Make(startSCNVector3.x, startSCNVector3.y, startSCNVector3.z)
        
        let GLKrotatedVector = GLKMatrix4MultiplyVector3(GLKmatrix, GLKvector)
        
        return SCNVector3FromGLKVector3(GLKrotatedVector)
    }
    
    func updateBallPositionsFor(_ position:SCNVector3) {
        
        if (self.ballPositions.count > 0) {
            self.ballPositions.insert(BallPosition(position: position), at: 0)
            
            if (self.ballPositions.count > 5) {
                self.ballPositions.removeLast()
            }
            
        } else {
            
            self.ballPositions.append(BallPosition(position: position))
        }
    }
    
    func positionForNode(_ node:SCNNode, locationInView p:CGPoint) -> SCNVector3 {
        
        let projectedBall = scnView.projectPoint(self.basketballNode.position)
        
        let x = Float(p.x)
        let y = Float(p.y)
        let z = Float(projectedBall.z) //use Z of the ball since thats what we want to be able to interact with
        
        let viewCoordinates = SCNVector3(x: x, y: y, z: z)
        
        let unprojectedVector = scnView.unprojectPoint(viewCoordinates)
        
        let minY = ballYMin
        
        let angle = Float(0.0) // use camera node since it doesnt move
        
        let adustedX = cos(angle) * unprojectedVector.x + sin(angle) * unprojectedVector.z
        let adustedZ = cos(angle) * unprojectedVector.z + sin(angle) * unprojectedVector.x
        
        let newX = adustedX
        let newY = max(minY!,unprojectedVector.y)
        let newZ = adustedZ
        
        let sceneCoordinates = SCNVector3(x: newX, y: newY, z: newZ)
        
        return sceneCoordinates
    }
    
    func zPositionFor(_ yPosition:Float) -> Float {
        
        let yHeight = yPosition
        let z = yHeight / Float(tan(kBallLaunchAngleRatio * M_PI_2))
        
        return z
    }
    
    func activateGravity(_ bool:Bool) {
        
        if (bool) {
            self.basketballNode.physicsBody!.mass = kBallMass
        } else {
            self.basketballNode.physicsBody!.mass = 0.0
        }
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
}
