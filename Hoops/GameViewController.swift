//
//  GameViewController.swift
//  Hoops
//
//  Created by Kyle Rokita on 3/16/15.
//  Copyright (c) 2015 RokShop. All rights reserved.
//

let kCameraAngleRatio = 1.0 //1.0 is parallel to ground

let kBallLaunchAngleRatio = 0.58

let kCameraOffset = Float(2.0)

let kCameraYFOV = Double(50)

let kCourtFullLength = CGFloat(30.0)

let kBallRadius = CGFloat(0.119253) //diameter of bball is 9.38 inches

let kRimRadius = CGFloat(0.2286) //diameter of rim is 18 inches

let kBallMass = CGFloat(0.56699) //20 ounces in Kg

let kHoopDistanceFromWall = CGFloat(1.85)

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
    
    var isMapViewExpanded : Bool!
    
    @IBOutlet var mapViewConstraintLeft : NSLayoutConstraint!
    @IBOutlet var mapViewConstraintTop : NSLayoutConstraint!
    @IBOutlet var mapViewConstraintWidth : NSLayoutConstraint!
    @IBOutlet var mapViewConstraintHeight : NSLayoutConstraint!
    
    var mapTitleHeightConstraint : NSLayoutConstraint!
    var mapImageHeightConstraint : NSLayoutConstraint!
    var buttonHeightConstraint : NSLayoutConstraint!
    
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
        scnView.delegate = self
        scnView.scene!.physicsWorld.speed = 1.0
        scnView.scene!.physicsWorld.timeStep = 1.0/180.0 //1/60 is default
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
        
        self.isMapViewExpanded = false
    }
    
    func renderer(aRenderer: SCNSceneRenderer, willRenderScene scene: SCNScene, atTime time: NSTimeInterval) {
        
        
    }
    
    func renderer(aRenderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: NSTimeInterval) {
        
        let dispatchDelay = 0.0
        let dispatchTime: dispatch_time_t = dispatch_time(DISPATCH_TIME_NOW, Int64(dispatchDelay * Double(NSEC_PER_SEC)))
        dispatch_after(dispatchTime, dispatch_get_main_queue(), {
            
            
            
            let basketballNode = scene.rootNode.childNodeWithName("Basketball", recursively: true)!
            let position = basketballNode.presentationNode().position
            
            self.updateMapBallPositionForPosition(position)
            self.updateMapBallStartPositionForPosition(self.ballStartPosition)
        })
    }
    
    func renderer(aRenderer: SCNSceneRenderer, didSimulatePhysicsAtTime time: NSTimeInterval) {
        
        
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        self.view.layoutIfNeeded()
        
        self.setupMapView()
        
        self.setBallStartPosition(SCNVector3(x: 0.0, y: ballYMin, z: 3.0))
        
        self.resetBasketMadeChecks()
        
    }
    
    func setupMapView () {
        self.mapView.userInteractionEnabled = true
        self.mapView.backgroundColor = UIColor.blackColor().colorWithAlphaComponent(0.0)
        
        self.setupMapTitleView()
        self.setupMapImageView()
        self.setupMapViewButtons()
        
        self.setupMapViewConstraints()
    }
    
    func setupMapTitleView () {
        self.mapTitleLabel = UILabel(frame: CGRectZero)
        self.mapTitleLabel.setTranslatesAutoresizingMaskIntoConstraints(false)
        
        let titleText = "\nBasketball Shooting Location"
        let titleText2 = "\n(Tap To Change)"
        
        let titleFont = UIFont.boldSystemFontOfSize(26.0)
        let titleFont2 = UIFont.systemFontOfSize(24.0)
        
        let titleAttributedText = NSMutableAttributedString(string: titleText, attributes: [NSFontAttributeName:titleFont, NSForegroundColorAttributeName:UIColor.whiteColor()])
        let titleAttributedText2 = NSMutableAttributedString(string: titleText2, attributes: [NSFontAttributeName:titleFont2, NSForegroundColorAttributeName:UIColor.lightGrayColor()])
        
        titleAttributedText.appendAttributedString(titleAttributedText2)
        
        self.mapTitleLabel.attributedText = titleAttributedText
        self.mapTitleLabel.numberOfLines = 0
        self.mapTitleLabel.textAlignment = NSTextAlignment.Center
        
        self.mapTitleLabel.alpha = 0
        
        self.mapView.addSubview(self.mapTitleLabel)
        
    }
    
    func setupMapViewConstraints () {
        
        //title constraints
        
        let leftTitleConstraint = NSLayoutConstraint(item: self.mapView, attribute: .Left, relatedBy: .Equal, toItem: self.mapTitleLabel, attribute: .Left, multiplier: 1.0, constant: 0.0)
        
        let rightTitleConstraint = NSLayoutConstraint(item: self.mapView, attribute: .Right, relatedBy: .Equal, toItem: self.mapTitleLabel, attribute: .Right, multiplier: 1.0, constant: 0.0)
        
        let topTitleConstraint = NSLayoutConstraint(item: self.mapView, attribute: .Top, relatedBy: .Equal, toItem: self.mapTitleLabel, attribute: .Top, multiplier: 1.0, constant: 0.0)
        
        self.mapTitleHeightConstraint = NSLayoutConstraint(item: self.mapTitleLabel, attribute: NSLayoutAttribute.Height, relatedBy: NSLayoutRelation.Equal, toItem: nil, attribute: NSLayoutAttribute.NotAnAttribute, multiplier: 1.0, constant: 0.0)
        
        self.mapView.addConstraints([leftTitleConstraint, rightTitleConstraint,topTitleConstraint,self.mapTitleHeightConstraint])
        
        
        //image constraints
        
        let leftImageConstraint = NSLayoutConstraint(item: self.mapView, attribute: .Left, relatedBy: .Equal, toItem: self.mapImageView, attribute: .Left, multiplier: 1.0, constant: 0.0)
        
        let rightImageConstraint = NSLayoutConstraint(item: self.mapView, attribute: .Right, relatedBy: .Equal, toItem: self.mapImageView, attribute: .Right, multiplier: 1.0, constant: 0.0)
        
        let topImageConstraint = NSLayoutConstraint(item: self.mapTitleLabel, attribute: .Bottom, relatedBy: .Equal, toItem: self.mapImageView, attribute: .Top, multiplier: 1.0, constant: 0.0)
        
        let height = self.mapView.bounds.size.height
        self.mapImageHeightConstraint = NSLayoutConstraint(item: self.mapImageView, attribute: NSLayoutAttribute.Height, relatedBy: NSLayoutRelation.Equal, toItem: nil, attribute: NSLayoutAttribute.NotAnAttribute, multiplier: 1.0, constant: height)
        
        self.mapView.addConstraints([leftImageConstraint, rightImageConstraint,topImageConstraint,self.mapImageHeightConstraint])
        
        //button constraints
        
        let leftConfirmButtonConstraint = NSLayoutConstraint(item: self.mapView, attribute: .Left, relatedBy: .Equal, toItem: self.mapViewConfirmButton, attribute: .Left, multiplier: 1.0, constant: -10.0)
        
        let topConfirmButtonConstraint = NSLayoutConstraint(item: self.mapViewConfirmButton, attribute: .Top, relatedBy: .Equal, toItem: self.mapImageView, attribute: .Bottom, multiplier: 1.0, constant: 10.0)
        
        let topCancelButtonConstraint = NSLayoutConstraint(item: self.mapViewCancelButton, attribute: .Top, relatedBy: .Equal, toItem: self.mapImageView, attribute: .Bottom, multiplier: 1.0, constant: 10.0)
        
        let middleButtonConstraint = NSLayoutConstraint(item: self.mapViewConfirmButton, attribute: .Right, relatedBy: .Equal, toItem: self.mapViewCancelButton, attribute: .Left, multiplier: 1.0, constant: -10.0)
        
        let rightCancelButtonConstraint = NSLayoutConstraint(item: self.mapView, attribute: .Right, relatedBy: .Equal, toItem: self.mapViewCancelButton, attribute: .Right, multiplier: 1.0, constant: 10.0)
        
        let buttonEqualWidth = NSLayoutConstraint(item: self.mapViewConfirmButton, attribute: .Width, relatedBy: .Equal, toItem: self.mapViewCancelButton, attribute: .Width, multiplier: 1.0, constant: 0.0)
        
        let buttonEqualHeight = NSLayoutConstraint(item: self.mapViewConfirmButton, attribute: .Height, relatedBy: .Equal, toItem: self.mapViewCancelButton, attribute: .Height, multiplier: 1.0, constant: 0.0)
        
        self.buttonHeightConstraint = NSLayoutConstraint(item: self.mapViewConfirmButton, attribute: NSLayoutAttribute.Height, relatedBy: NSLayoutRelation.Equal, toItem: nil, attribute: NSLayoutAttribute.NotAnAttribute, multiplier: 1.0, constant: 0.0)
        
        self.mapView.addConstraints([leftConfirmButtonConstraint,topConfirmButtonConstraint,topCancelButtonConstraint,middleButtonConstraint,rightCancelButtonConstraint,buttonEqualWidth,buttonEqualHeight, self.buttonHeightConstraint])
        
        
    }
    
    func setupMapImageView () {
        self.mapImageView = UIImageView(image: UIImage(contentsOfFile: NSBundle.mainBundle().pathForResource("basketballHalfCourt", ofType: "png")!))
        self.mapImageView.setTranslatesAutoresizingMaskIntoConstraints(false)
        
        self.mapImageView.contentMode = UIViewContentMode.ScaleAspectFit
        self.mapView.addSubview(self.mapImageView)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: "handleMapTap:")
        tapGesture.numberOfTapsRequired = 1
        self.mapImageView.userInteractionEnabled = true
        
        self.mapImageView.addGestureRecognizer(tapGesture)
    }
    
    func setupMapViewButtons () {
        
        self.mapViewConfirmButton = UIButton(frame: CGRectZero)
        self.mapViewConfirmButton.setTranslatesAutoresizingMaskIntoConstraints(false)
        
        self.mapViewConfirmButton.setTitle("Confirm Change", forState: UIControlState.Normal)
        
        self.mapViewConfirmButton.backgroundColor = UIColor.blueColor()
        self.mapViewConfirmButton.layer.cornerRadius = 15.0
        self.mapViewConfirmButton.layer.borderWidth = 1.0
        self.mapViewConfirmButton.layer.borderColor = UIColor.blackColor().CGColor
        
        self.mapViewConfirmButton.addTarget(self, action: "mapViewConfirmTapped:", forControlEvents: UIControlEvents.TouchUpInside)
        
        self.mapView.addSubview(self.mapViewConfirmButton)
        
        
        self.mapViewCancelButton = UIButton(frame: CGRectZero)
        self.mapViewCancelButton.setTranslatesAutoresizingMaskIntoConstraints(false)
        
        self.mapViewCancelButton.setTitle("Cancel", forState: UIControlState.Normal)
        
        self.mapViewCancelButton.backgroundColor = UIColor.blueColor()
        self.mapViewCancelButton.layer.cornerRadius = 15.0
        self.mapViewCancelButton.layer.borderWidth = 1.0
        self.mapViewCancelButton.layer.borderColor = UIColor.blackColor().CGColor
        
        self.mapViewCancelButton.addTarget(self, action: "mapViewCancelTapped:", forControlEvents: UIControlEvents.TouchUpInside)
        
        self.mapView.addSubview(self.mapViewCancelButton)
        
        self.mapViewConfirmButton.alpha = 0.0
        self.mapViewCancelButton.alpha = 0.0
        
        self.mapView.layoutIfNeeded()
        
    }
    
    func mapViewConfirmTapped(recognizer:UIButton) {
        println("confirm tapped")
        
        self.ballLastStartPosition = nil
        
        self.animateMapViewExpand(false)
        self.isMapViewExpanded = false
    }
    
    func mapViewCancelTapped(recognizer:UIButton) {
        println("cancel tapped")
        
        self.setBallStartPosition(self.ballLastStartPosition!)
        
        
        self.animateMapViewExpand(false)
        self.isMapViewExpanded = false
    }
    
    func animateMapViewExpand(expandBool : Bool) {
        
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
        
        UIView.animateWithDuration(0.5, delay: 0, options: UIViewAnimationOptions.AllowAnimatedContent, animations: { () -> Void in
            
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
                
                self.mapView.backgroundColor = UIColor.blackColor().colorWithAlphaComponent(0.8)
                
            } else {
                self.buttonHeightConstraint.constant = 0.0
                self.mapViewConfirmButton.alpha = 0.0
                self.mapViewCancelButton.alpha = 0.0
                self.mapTitleLabel.alpha = 0.0
                
                self.mapView.backgroundColor = UIColor.blackColor().colorWithAlphaComponent(0.0)
                
            }
            
            self.mapView.layoutIfNeeded()
            
            
            }) { (finished:Bool) -> Void in
                
                self.ballStartPositionView!.alpha = 1
                
                if expandBool == false {
                    self.ballPositionView!.alpha = 1
                    
                }
        }
        
    }
    
    
    func updateMapBallPositionForPosition(position:SCNVector3) {
        
        if ( self.ballPositionView == nil ) {
            
            self.ballPositionView = self.makeBallPositionView()
            self.mapImageView.addSubview(self.ballPositionView!)
            self.mapImageView.sendSubviewToBack(self.ballPositionView!)
            
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
    
    func updateMapBallStartPositionForPosition(position:SCNVector3) {
        
        if ( self.ballStartPositionView == nil ) {
            
            self.ballStartPositionView = self.makeBallStartPositionView()
            self.mapImageView.addSubview(self.ballStartPositionView!)
            self.mapImageView.bringSubviewToFront(self.ballStartPositionView!)
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
        view.setTranslatesAutoresizingMaskIntoConstraints(false)
        
        view.backgroundColor = UIColor.orangeColor()
        view.layer.cornerRadius = view.frame.size.height / 2.0
        view.layer.borderColor = UIColor.blackColor().CGColor
        view.layer.borderWidth = 1.0
        
        return view
    }
    
    func makeBallStartPositionView () -> UIView {
        
        let viewFrame = CGRect(x: 0, y: 0, width: 10, height: 10)
        let view = UIView(frame: viewFrame)
        view.setTranslatesAutoresizingMaskIntoConstraints(false)
        
        view.backgroundColor = UIColor.greenColor()
        view.layer.cornerRadius = view.frame.size.height / 2.0
        view.layer.borderColor = UIColor.blackColor().CGColor
        view.layer.borderWidth = 1.0
        
        return view
    }
    
    func mapBallPositionFromBallPosition(position:SCNVector3) -> CGPoint {
        
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
    
    func ballPositionFromMapPosition(position:CGPoint) -> SCNVector3 {
        
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
        
        return SCNVector3(x: adjustedX, y: adjustedY, z: adjustedZ)
        
    }
    
    func handleMapTap(recognizer:UIGestureRecognizer) {
        println("map tapped")
        
        //stop ball from rolling because it just looks weird
        self.basketballNode.physicsBody!.angularVelocity = SCNVector4(x: 0, y: 0, z: 0, w: 0)
        
        if (self.isMapViewExpanded == false) {
            
            if (self.ballLastStartPosition == nil) {
                self.ballLastStartPosition = self.ballStartPosition
            }
            
            self.animateMapViewExpand(true)
            self.isMapViewExpanded = true
            
        } else {
            
            let newBallPoint = recognizer.locationInView(self.mapImageView)
            let newBallPosition = self.ballPositionFromMapPosition(newBallPoint)
            
            self.setBallStartPosition(newBallPosition)
            
        }
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
                self.highlightNode(self.hoopNetNode)
                
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
        spotLight.attenuationEndDistance = 55.0
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
        spotlightNode.position = SCNVector3(x: 0, y: 30, z: Float(courtLength() / 2.0))
        spotlightNode.eulerAngles = SCNVector3(x: Float(M_PI_2 * 3.0), y: 0, z: 0)
        scene.rootNode.addChildNode(spotlightNode)
        
        let light = SCNLight()
        light.type = SCNLightTypeOmni
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
        ambientLightNode.light!.type = SCNLightTypeAmbient
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
        ballBody.restitution = 1.0
        ballBody.friction = 0.2
        ballBody.rollingFriction = 1.0
        
        ballBody.categoryBitMask = Collisions.Ball.rawValue
        
        self.basketballNode.physicsBody = ballBody
        
        // self.basketballNode.removeFromParentNode()
        // self.courtNodeSystem.addChildNode(self.basketballNode)
        
    }
    
    func setBallStartPosition(position:SCNVector3) {
        
        self.basketballNode.position = SCNVector3(x: position.x, y: ballYMin, z: position.z)
        self.basketballNode.physicsBody!.resetTransform()
        
        self.cameraNode.eulerAngles = self.cameraAngleRelativeToBallPosition(self.basketballNode.position)
        self.cameraNode.position = self.cameraPositionRelativeToBallPosition(self.basketballNode.position)
        
        self.ballStartPosition = position
        
        self.updateMapBallPositionForPosition(self.ballStartPosition)
        self.updateMapBallStartPositionForPosition(self.ballStartPosition)
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
        
        let cameraHeight = Float(2.0)
        
        return SCNVector3(x: position.x + cameraAdditionalX, y: cameraHeight, z: position.z + cameraAdditionalZ)
    }
    
    func cameraAngleRelativeToBallPosition(position:SCNVector3) -> SCNVector3 {
        
        let angle = self.angleRelativeToBallPosition(position) * -1.0
        
        return SCNVector3(x: Float(M_PI_2 - M_PI_2 * kCameraAngleRatio ), y: (0.0 - angle) , z: 0.0)
        
    }
    
    func setupCourtNode () {
        
        self.courtNode = scene.rootNode.childNodeWithName("Court", recursively: true)!
        self.courtNode.removeFromParentNode()
        self.courtNode.castsShadow = false

        let courtLength = self.courtLength()
        let courtWidth = self.courtWidth()
        let courtThickness = CGFloat(0.5)
        
        let courtGeometry = SCNBox(width: courtWidth, height: courtThickness, length: courtLength, chamferRadius: 0)
        
        courtGeometry.firstMaterial!.diffuse.contents = UIImage(contentsOfFile: NSBundle.mainBundle().pathForResource("basketballHalfCourt", ofType: "png")!)
        
        self.courtNode = SCNNode(geometry: courtGeometry)
        self.courtNode.position = SCNVector3(x: 0.0, y: Float(-courtThickness / 2.0), z: Float(courtLength / 2.0 - kHoopDistanceFromWall))
        self.courtNode.eulerAngles = SCNVector3(x: 0, y: 0, z: 0)
        
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
        self.rimNode.castsShadow = false

        self.hoopNode.addChildNode(self.rimNode)
        
        var rimBody = SCNPhysicsBody(type: SCNPhysicsBodyType.Static, shape: SCNPhysicsShape(geometry: self.rimNode.geometry!, options: [SCNPhysicsShapeTypeKey:SCNPhysicsShapeTypeConcavePolyhedron]))
        rimBody.friction = 0.5
        rimBody.rollingFriction = 0.5
        
        rimBody.categoryBitMask = Collisions.Rim.rawValue
        
        self.rimNode.physicsBody = rimBody
        
        let hoopNetHeight = CGFloat(0.45)
        
        let hoopNetGeometry = SCNTube(innerRadius: rimRadius, outerRadius: rimRadius + 0.02, height: hoopNetHeight)
        hoopNetGeometry.firstMaterial!.diffuse.contents = UIImage(contentsOfFile: NSBundle.mainBundle().pathForResource("net", ofType: "png")!)
        
        self.hoopNetNode = SCNNode(geometry: hoopNetGeometry)
        self.hoopNetNode.position = SCNVector3(x: 0, y: Float(rimHeight - hoopNetHeight / 2.0), z: 0)
        
        self.hoopNetNode.name = "HoopNet"
        self.hoopNetNode.castsShadow = false

        self.hoopNode.addChildNode(self.hoopNetNode)
        
        var hoopNetBody = SCNPhysicsBody(type: SCNPhysicsBodyType.Static, shape: SCNPhysicsShape(geometry: self.hoopNetNode.geometry!, options: [SCNPhysicsShapeTypeKey:SCNPhysicsShapeTypeConcavePolyhedron]))
        
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
        self.backboardNode.position = SCNVector3(x: 0, y: Float(rimHeight + backboardHeight / 2.0) - 0.075, z: Float(-backboardThickness/2.0) - Float(rimRadius + rimPipeRadius * 2.0) - Float(backboardRimGap))
        
        self.backboardNode.name = "Backboard"
        
        self.backboardNode.categoryBitMask = 2
        self.backboardNode.castsShadow = false
        
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
        self.backboardRimGapNode.castsShadow = false

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
        self.hoopPoleNode.castsShadow = false

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
        self.hoopPoleHorizontalNode.castsShadow = false

        self.hoopNode.addChildNode(self.hoopPoleHorizontalNode)
        
        var poleHorizontalBody = SCNPhysicsBody(type: SCNPhysicsBodyType.Static, shape: SCNPhysicsShape(geometry: self.hoopPoleHorizontalNode.geometry!, options: [SCNPhysicsShapeTypeKey:SCNPhysicsShapeTypeBoundingBox]))
        poleHorizontalBody.friction = 1.0
        poleHorizontalBody.rollingFriction = 1.0
        
        poleHorizontalBody.categoryBitMask = Collisions.Pole.rawValue
        
        self.hoopPoleHorizontalNode.physicsBody = poleHorizontalBody
        
    }
    
    func courtLength() -> CGFloat {
        return kCourtFullLength * 1251.0 / 2085.0 //adjust for half court
    }
    
    func courtWidth() -> CGFloat {
        // return self.courtLength() * 1251.0 / 2085.0
        
        //half coourt is same width as length = 1251 pixels
        return self.courtLength()
        
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
        self.backWallNode.castsShadow = false

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
        
        let backWallZPosition = courtLength() - kHoopDistanceFromWall
        
        let wallGeometry = SCNBox(width: wallWidth, height: wallHeight, length: wallThickness, chamferRadius: 0)
        
        
        self.frontWallNode = SCNNode(geometry: wallGeometry)
        self.frontWallNode.position = SCNVector3(x: 0.0, y: Float(backWallZPosition), z: Float(backWallZPosition))
        self.frontWallNode.eulerAngles = SCNVector3(x: 0, y: 0, z: 0)
        self.frontWallNode.castsShadow = false

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
        
        //let xAdjVelocity = cos(angleFromBasket) * xDiff + sin(angleFromBasket) * zVelocity
        
        //let zAdjVelocity = sin(angleFromBasket) * xDiff + cos(angleFromBasket) * zVelocity
        
        let positionChangeVector = SCNVector3(x: xDiff, y: yDiff, z: zVelocity)
        
        let rotationVector2 = SCNVector4(x: 0, y: 1, z: 0, w: Float(angleFromBasket))
        
        var rotatedVector = self.rotateSCNVector3(positionChangeVector, byRotationSCNVector4: rotationVector2)
        
        let ballLandingSpot = self.landingSpotForBallLaunchPosition(self.basketballNode.position, actualLaunchVector: rotatedVector)
        
        let idealLaunchVector = self.idealLaunchVectorForBallLaunchPosition(self.basketballNode.position, actualLaunchVector: rotatedVector)
        
        if (!isnan(ballLandingSpot.x) && !isnan(ballLandingSpot.z)) {
            
            let landingSpotDistanceFromBasket = sqrt( ballLandingSpot.x * ballLandingSpot.x + ballLandingSpot.z * ballLandingSpot.z )
            
            if (!isnan(idealLaunchVector.y) ) {
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
                
                println("blended ratio: \(blendRatioHorizontal)")
                
                let newX = rotatedVector.x * blendRatioHorizontal + idealLaunchVector.x * (1.0 - blendRatioHorizontal)
                let newY = rotatedVector.y * blendRatioVertical + idealLaunchVector.y * (1.0 - blendRatioVertical)
                let newZ = rotatedVector.z * blendRatioVertical + idealLaunchVector.z * (1.0 - blendRatioVertical)
                
                rotatedVector = SCNVector3(x: newX, y: newY, z: newZ)
            
            }
            
        }
        
        self.basketballNode.physicsBody!.velocity = rotatedVector
        
        self.launchInfo = LaunchInfo(position: self.basketballNode.position, initialVelocity: self.basketballNode.physicsBody!.velocity)
    }
    
    func idealLaunchVectorForBallLaunchPosition (position: SCNVector3, actualLaunchVector:SCNVector3) -> SCNVector3 {
        
        //get ball distance from rim center
        let xDistance = self.rimNode.position.x - position.x
        let yDistance = self.rimNode.position.y - position.y
        let zDistance = self.rimNode.position.z - position.z
        
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
    
    func landingSpotForBallLaunchPosition (position: SCNVector3, actualLaunchVector:SCNVector3) -> SCNVector3 {
        
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
        
        let yLandingSpot = position.y - cc
        let xLandingSpot = position.x + actualLaunchVector.x * time
        let zLandingSpot = position.z + actualLaunchVector.z * time
        
        return SCNVector3(x: xLandingSpot, y: yLandingSpot , z: zLandingSpot)
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
