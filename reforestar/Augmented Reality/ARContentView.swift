//
//  ContentView.swift
//  ARSwiftUI
//
//  Created by Matias Ariel Ortiz Luna on 19/04/2021.
//

import SwiftUI
import RealityKit
import ARKit
import UIKit
import Combine
import Firebase
import SceneKit
import Foundation

struct ARContentView: View {
    
    @StateObject var selectedModelManager = CurrentSessionSwiftUI()
    @StateObject var userFeedbackManager = UserFeedback()
    @StateObject var locationManager = LocationManager()
    
    var body: some View {
        ZStack(){
            //AR Custom Class.
            ARViewContainer()
            //AR Custom User Interface
            CustomARUserInterface()
                .environmentObject(selectedModelManager)
                .environmentObject(userFeedbackManager)
                .environmentObject(locationManager)
        }
    }
}

struct ARViewContainer: UIViewRepresentable {
    
    func makeUIView(context: Context) -> CustomARView {
        
        let arView  = CustomARView(frame: .zero)
        
        arView.setupARView()
        arView.setupGestures()
        
        return arView;
    }
    
    func updateUIView(_ uiView: CustomARView
                      , context: Context) {
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ARContentView().environmentObject(CurrentSessionSwiftUI()).environmentObject(UserFeedback()).environmentObject(LocationManager())
    }
}

public class CustomARView: ARView{
    
    private var reforestationSettingsManager = ReforestationSettings();
    private var locationManager = LocationManager()
    
    var currentSceneManager = CurrentSession.sharedInstance
    
    let notification_last_item_anchor = Notification.Name("last_item_anchor")
    var cancellable: AnyCancellable?
    
    let notification_delete_all_trees = Notification.Name("delete_all_trees")
    var cancellableAllTrees: AnyCancellable?
    let notification_delete_all_trees_confirmation = Notification.Name("delete_all_trees_confirmation")
    
    let notification_remove_last_anchor_confirmation = Notification.Name("last_anchor_confirmation")
    
    let notification_save_progress = Notification.Name("notification_save_progress")
    var cancellableSaveProgress: AnyCancellable?
    let notification_save_progress_confirmation = Notification.Name("notification_save_progress_confirmation")
    
    let notification_load_progress = Notification.Name("notification_load_progress")
    var cancellableLoadProgress: AnyCancellable?
    let notification_preparation_load_progress = Notification.Name("notification_preparation_load_progress")
    var cancellablePreparationLoadProgress: AnyCancellable?
    
    let notification_placed_tree_confirmation = Notification.Name("notification_placed_tree_confirmation")
    
    func setupARView(){
        
        self.session.delegate = self
        
        self.automaticallyConfigureSession = false;
        
        let configuration = ARWorldTrackingConfiguration();
        configuration.planeDetection = [.horizontal];
        configuration.environmentTexturing = .none;
        
        self.cancellable = NotificationCenter.default
            .publisher(for: self.notification_last_item_anchor)
            .sink { value in
                print("Notification received from a publisher! \(value) to delete last anchor.")
                if(self.scene.anchors.count>=1){
                    print("Removing \(self.scene.anchors[self.scene.anchors.endIndex-1])")
                    self.scene.removeAnchor(self.scene.anchors[self.scene.anchors.endIndex-1])
                    self.currentSceneManager.removeLast()
                    
                    NotificationCenter.default.post(name: self.notification_remove_last_anchor_confirmation, object: nil)
                    
                }else{
                    print("No items to delete")
                }
            }
        
        self.cancellableAllTrees = NotificationCenter.default
            .publisher(for: self.notification_delete_all_trees)
            .sink { value in
                print("Notification received from a publisher! \(value)\nto delete All Trees from Scene")
                if(self.scene.anchors.count>=1){
                    self.scene.anchors.removeAll()
                    self.currentSceneManager.removeAll()
                    
                    NotificationCenter.default.post(name: self.notification_delete_all_trees_confirmation, object: nil)
                    print("Sucessfully Deleted all Trees from Scene")
                }else{
                    print("No items to delete")
                }
            }
        
        self.cancellableSaveProgress = NotificationCenter.default
            .publisher(for: self.notification_save_progress)
            .sink { value in
                print("Notification received from a publisher! \(value)\nto Save The Progress")
                self.saveProject(project: self.currentSceneManager.getSelectedProject(), location: self.currentSceneManager.user_location)
            }
        
        self.cancellableLoadProgress = NotificationCenter.default
            .publisher(for: self.notification_load_progress)
            .sink { value in
                print("Notification received from a publisher! \(value)\nto Load The Progress from Project")
                self.loadProject(project: self.currentSceneManager.getSelectedProject())
                sleep(1)
                NotificationCenter.default.post(name: self.notification_preparation_load_progress, object: nil, userInfo: ["longitude": self.currentSceneManager.desired_location.longitude, "latitude" : self.currentSceneManager.desired_location.latitude])
            }
        
        self.session.run(configuration)
    }
    
    func loadProject(project: String) -> Int {
        self.locationManager.locationManager.requestLocation()
        
        var validation_code : Int = 0
        let ref = Database.database(url: "https://reforestar-database-default-rtdb.europe-west1.firebasedatabase.app/").reference().ref.child("projects").child(self.currentSceneManager.getSelectedProject()).child("trees")
        ref.getData { [self] (error, snapshot) in
            if let error = error {
                print("Error getting data \(error)")
            }
            else if snapshot.exists() {
                let result = snapshot.value as! NSArray
                var object : Dictionary<String, Any>? = nil
                for tree in result {
                    object = (tree as! Dictionary<String, Any>)
                    var name : String = "Eucalyptus globulus"
                    if(object?["name"] != nil){
                        name = object?["name"] as! String
                    }
                    let first = object?["first"] as! String
                    let second = object!["second"] as! String
                    let third = object!["third"] as! String
                    let forth = object!["forth"] as! String
                    let matrix = self.createNewMatrix(first: first, second: second, third: third, forth: forth)
                    currentSceneManager.addLoadAnchor(anchor: ARAnchor(name: name, transform: matrix))
                }
                
                let _: Void = ref.parent!.child("location").getData { [self] (error, snapshot) in
                    if let error = error {
                        print("Error getting data \(error)")
                    }
                    else if snapshot.exists() {
                        let location = snapshot.value as! Dictionary<String, Any>
                        self.currentSceneManager.desired_location = CLLocationCoordinate2D(latitude: location["latitude"] as! CLLocationDegrees, longitude: location["longitude"] as! CLLocationDegrees)
                        self.currentSceneManager.user_location = self.locationManager.locationManager.location?.coordinate ?? CLLocationCoordinate2D()
                    }
                    else {
                        print("No data available")
                    }
                }
                
            }
            else {
                print("No data available")
            }
        }
        
        //Se n??o houver dados ....
        validation_code = 1
        
        return validation_code
    }
    
    private func createNewMatrix(first: String, second: String, third: String, forth: String) -> simd_float4x4{
        let first_splitted = first.components(separatedBy: ";")
        let second_splitted = second.components(separatedBy: ";")
        let third_splitted = third.components(separatedBy: ";")
        let forth_splitted = forth.components(separatedBy: ";")
        
        guard let first_1 = Float(first_splitted[0]) else { return simd_float4x4()}
        guard let first_2 = Float(first_splitted[1]) else { return simd_float4x4()}
        guard let first_3 = Float(first_splitted[2]) else { return simd_float4x4()}
        guard let first_4 = Float(first_splitted[3]) else { return simd_float4x4()}
        
        let first_column = SIMD4(first_1, first_2, first_3, first_4)
        
        guard let second_1 = Float(second_splitted[0]) else { return simd_float4x4()}
        guard let second_2 = Float(second_splitted[1]) else { return simd_float4x4()}
        guard let second_3 = Float(second_splitted[2]) else { return simd_float4x4()}
        guard let second_4 = Float(second_splitted[3]) else { return simd_float4x4()}
        
        let second_column = SIMD4(second_1, second_2, second_3, second_4)
        
        guard let third_1 = Float(third_splitted[0]) else { return simd_float4x4()}
        guard let third_2 = Float(third_splitted[1]) else { return simd_float4x4()}
        guard let third_3 = Float(third_splitted[2]) else { return simd_float4x4()}
        guard let third_4 = Float(third_splitted[3]) else { return simd_float4x4()}
        
        let third_column = SIMD4(third_1, third_2, third_3, third_4)
        
        guard let forth_1 = Float(forth_splitted[0]) else { return simd_float4x4()}
        guard let forth_2 = Float(forth_splitted[1]) else { return simd_float4x4()}
        guard let forth_3 = Float(forth_splitted[2]) else { return simd_float4x4()}
        guard let forth_4 = Float(forth_splitted[3]) else { return simd_float4x4()}
        
        let forth_column = SIMD4(forth_1, forth_2, forth_3, forth_4)
        
        return simd_float4x4(first_column, second_column, third_column, forth_column)
    }
    
    func saveProject(project: String, location : CLLocationCoordinate2D) -> Int {
        
        var validation_code : Int = 0
        var index = 0
        
        var ref = Database.database(url: "https://reforestar-database-default-rtdb.europe-west1.firebasedatabase.app/").reference().ref.child("projects").child(self.currentSceneManager.getSelectedProject()).child("trees")
        
        ref.getData { [self] (error, snapshot) in
            if let error = error {
                print("Error getting data \(error)")
            }
            else if snapshot.exists() {
                //print("Got data \(snapshot.value!)")
                let result = snapshot.value as! NSArray
                index = result.count
            }
            else {
                index=0
                print("No data available")
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1), execute: {
            if(self.currentSceneManager.getSelectedProject() != "No project Associated"){
                if(self.currentSceneManager.getPositions().count>0){
                    
                    for anchor in self.currentSceneManager.getSceneAnchors() {
                        
                        let result_name: Void = ref.child("\(index)").setValue(["name": anchor.name])
                        let result1: Void = ref.child("\(index)").child("first").setValue( anchor.transform.columns.0.getValueStringed())
                        let result2: Void = ref.child("\(index)").child("second").setValue( anchor.transform.columns.1.getValueStringed())
                        let result3: Void = ref.child("\(index)").child("third").setValue( anchor.transform.columns.2.getValueStringed())
                        let result4: Void = ref.child("\(index)").child("forth").setValue( anchor.transform.columns.3.getValueStringed())
                        
                        index+=1
                    }
                    
                    //save user's location
                    let project_location : Dictionary<String, Any> = ["longitude" : location.longitude , "latitude" : location.latitude]
                    let result_longitude: Void = ref.parent!.child("location").setValue(project_location)
                    
                    //Success at Saving Progress
                    NotificationCenter.default.post(name: self.notification_save_progress_confirmation, object: nil, userInfo: ["code": 1])
                    
                    
                }else{
                    //Se n??o conseguir salvar dados ....
                    validation_code = 1
                    print("There is no elements to be saved to project \(self.currentSceneManager.getSelectedProject())")
                    NotificationCenter.default.post(name: self.notification_save_progress_confirmation, object: nil, userInfo: ["code": 2])
                    //There are no elements to be saved.
                }
                
            }else{
                //Se n??o conseguir salvar dados ....
                validation_code = 1
                print("Can't be saved because no project has been selected")
                NotificationCenter.default.post(name: self.notification_save_progress_confirmation, object: nil, userInfo: ["code": 3])
                //There is no project selected
            }
        })
        
        
        return validation_code
    }
    
    
    func setupGestures() {
        //tap gesture for placing trees
        self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap(recognizer:))))
    }
    
    private func getEditedAnchor(anchor: ARAnchor, first_touch: simd_float4x4) -> ARAnchor {
        var new_position : simd_float4x4 = anchor.transform
        //new_position.columns.3.x += first_touch.columns.3.x
        new_position.columns.3.y = first_touch.columns.3.y
        new_position.columns.3.z += first_touch.columns.3.z
        return ARAnchor(name: anchor.name ?? "Quercus suber", transform: new_position)
    }
    
    @objc
    func handleTap(recognizer: UITapGestureRecognizer){
        self.locationManager.locationManager.requestLocation()
        
        let touchInView = recognizer.location(in: self)
        let results = self.raycast(from: touchInView, allowing: .estimatedPlane, alignment: .horizontal)
        
        let desired_coordinate = CLLocation(latitude: self.currentSceneManager.desired_location.latitude, longitude: self.currentSceneManager.desired_location.longitude)
        
        self.currentSceneManager.user_location = self.locationManager.locationManager.location?.coordinate ?? CLLocationCoordinate2D()
        
        let users_coordinate = CLLocation(latitude: self.currentSceneManager.user_location.latitude, longitude: self.currentSceneManager.user_location.longitude)
        
        
        if let firstResult = results.first{
            
            //se tem objetos na memoria para carregar e colocar, coloca ...
            if(currentSceneManager.hasLoadAnchors()){
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1), execute: {
                    //if user is less than 5 meters away from saved position
                    if (self.currentSceneManager.getReforestationPlanOption() == true){
                        let distance = users_coordinate.distance(from: desired_coordinate)
                        if (distance <= 10){
                            for anchor in self.currentSceneManager.getLoadAnchors() {
                                self.session.add(anchor: self.getEditedAnchor(anchor: anchor, first_touch: firstResult.worldTransform));
                                NotificationCenter.default.post(name: self.notification_placed_tree_confirmation, object: nil, userInfo: ["code": 5])
                            }
                            self.currentSceneManager.cleanLoadAnchors()
                        }else{
                            //Get closer to position
                            NotificationCenter.default.post(name: self.notification_placed_tree_confirmation, object: nil, userInfo: ["code": 6, "distance": distance])
                        }
                    }else{
                        for anchor in self.currentSceneManager.getLoadAnchors() {
                            self.session.add(anchor: self.getEditedAnchor(anchor: anchor, first_touch: firstResult.worldTransform));
                            NotificationCenter.default.post(name: self.notification_placed_tree_confirmation, object: nil, userInfo: ["code": 5])
                        }
                        self.currentSceneManager.cleanLoadAnchors()
                    }
                    
                })
                
            }else{
                
                //At this point, the touch in the screen was recognized by the AR tecnhology to be considered a real surface.
                //Now, we'll call this method to create all the positions needed.
                //It is send, the initial position of the first touch in the screen.
                //It is also send, the number of trees that the user selected.
                //It is also send, the scale desired by the user.
                //It is also send, the anchors already existing in the scene.
                
                var positions = self.reforestationSettingsManager.getPositionsThreeDimension(from: firstResult.worldTransform, for: self.currentSceneManager.getNumberOfTrees(),known_positions: self.currentSceneManager.getPositions(), scale_compensation: Float(self.currentSceneManager.getScaleCompensation()))
                
                //If the array has more than 1 item, it means it created sucessfully new positions, at least 1.
                if(positions.count>0){
                    
                    //Iterate the array of the positions to compare. Because the first position is 0, the last has to be, the amount of elements - 1
                    for index in 0...(positions.count-1) {
                        
                        //To add a little randomness, the unpair index elements are rotated. Also, the scale needs to be this, because if is lower, it looks weird. hehe
                        if (index%2 == 0 && self.currentSceneManager.getScaleCompensation() > 0.8){
                            positions[index] = self.reforestationSettingsManager.rotateObject(old_matrix: positions[index])
                        }
                        
                        //All the items are added a scale randomness
                        positions[index] = self.reforestationSettingsManager.scaleObjectWithScale(old_matrix: positions[index],scale_compensation: self.currentSceneManager.getScaleCompensation())
                        
                        //Finally here, is created the new 3D object, anchor and added to the scene, with all the modifications made by us.
                        let anchor = ARAnchor(name: self.currentSceneManager.getSelectedModelName(), transform: positions[index]);
                        self.session.add(anchor: anchor);
                    }
                    NotificationCenter.default.post(name: notification_placed_tree_confirmation, object: nil, userInfo: ["code": 1])
                    
                    //If the array has not items, it means there was a problem, so either didn't find space to all the trees or the intial position wasn't available.
                }else{
                    print("Coudn't find space")
                    NotificationCenter.default.post(name: notification_placed_tree_confirmation, object: nil, userInfo: ["code": 2])
                }
            }
            
        }else{
            print("Object placement failed - coudn't find surface")
            NotificationCenter.default.post(name: notification_placed_tree_confirmation, object: nil, userInfo: ["code": 3])
        }
        
    }
    
    func placeObject(named entityName: String, for anchor: ARAnchor){
        
        let notification_numberOfAnchors = Notification.Name("numberOfAnchors")
        
        let entity = try! ModelEntity.load(named: entityName)
        
        let anchorEntity = AnchorEntity(anchor: anchor)
        anchorEntity.addChild(entity);
        
        self.scene.addAnchor(anchorEntity)
        self.currentSceneManager.setLastAnchor(anchor: anchor)
        self.currentSceneManager.appendSceneAnchor(scene_anchor: anchor)
        NotificationCenter.default.post(name: notification_numberOfAnchors, object: nil)
        
        entity.generateCollisionShapes(recursive: true)
        
    }
    
}

extension CustomARView: ARSessionDelegate{
    
    public func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors{
            if let anchorName = anchor.name{
                placeObject(named: anchorName, for: anchor)
            }else{
                print("Error placing: \(anchor.name) model")
                NotificationCenter.default.post(name: notification_placed_tree_confirmation, object: nil, userInfo: ["code": 4])
            }
            
        }
        
    }
}

extension SIMD4 {
    
    func getValueStringed()->String{
        return String("\(self.x);\(self.y);\(self.z);\(self.w)")
    }
    
    
}
