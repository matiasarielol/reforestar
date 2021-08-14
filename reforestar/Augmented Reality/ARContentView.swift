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

struct ARContentView: View {
    
    @StateObject var selectedModelManager = CurrentSessionSwiftUI()
    @StateObject var userFeedbackManager = UserFeedback()
    
    var body: some View {
        ZStack(){
            //AR Custom Class.
            ARViewContainer()
            //AR Custom User Interface
            CustomARUserInterface()
                .environmentObject(selectedModelManager)
                .environmentObject(userFeedbackManager)
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
        ARContentView().environmentObject(CurrentSessionSwiftUI()).environmentObject(UserFeedback())
    }
}

public class CustomARView: ARView{
    
    private var reforestationSettingsManager = ReforestationSettings();
    
    var currentSceneManager = CurrentSession.sharedInstance
    
    let notification_name = Notification.Name("last_item_anchor")
    var cancellable: AnyCancellable?
    
    let notification_delete_all_trees = Notification.Name("delete_all_trees")
    var cancellableAllTrees: AnyCancellable?
    
    let notification_save_progress = Notification.Name("notification_save_progress")
    var cancellableSaveProgress: AnyCancellable?
    
    let notification_load_progress = Notification.Name("notification_load_progress")
    var cancellableLoadProgress: AnyCancellable?
    
    func setupARView(){
        
        self.session.delegate = self
        
        self.automaticallyConfigureSession = false;
        
        let configuration = ARWorldTrackingConfiguration();
        configuration.planeDetection = [.horizontal];
        configuration.environmentTexturing = .none;
        
        self.cancellable = NotificationCenter.default
            .publisher(for: self.notification_name)
            .sink { value in
                print("Notification received from a publisher! \(value)")
                if(self.scene.anchors.count>=1){
                    print("Removing \(self.scene.anchors[self.scene.anchors.endIndex-1])")
                    self.scene.removeAnchor(self.scene.anchors[self.scene.anchors.endIndex-1])
                    self.currentSceneManager.removeLast()
                    
                    let notification_removeLastAnchor = Notification.Name("removeLastAnchor")
                    NotificationCenter.default.post(name: notification_removeLastAnchor, object: nil)
                    
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
                    
                    let notification_removeAllAnchors = Notification.Name("removeAllAnchors")
                    NotificationCenter.default.post(name: notification_removeAllAnchors, object: nil)
                    print("Sucessfully Deleted all Trees from Scene")
                }else{
                    print("No items to delete")
                }
            }
        
        self.cancellableSaveProgress = NotificationCenter.default
            .publisher(for: self.notification_save_progress)
            .sink { value in
                print("Notification received from a publisher! \(value)\nto Save The Progress")
                self.saveProject(project: self.currentSceneManager.getSelectedProject())
            }
        
        self.cancellableLoadProgress = NotificationCenter.default
            .publisher(for: self.notification_load_progress)
            .sink { value in
                print("Notification received from a publisher! \(value)\nto Load The Progress from Project")
                self.loadProject(project: self.currentSceneManager.getSelectedProject())
            }
        
        self.session.run(configuration)
    }
    
    func loadProject(project: String) -> Int {
        
        var validation_code : Int = 0
        
        let ref = Database.database(url: "https://reforestar-database-default-rtdb.europe-west1.firebasedatabase.app/").reference()
        
        print("Project To Load")
        print(currentSceneManager.projects?[project])
        
        let project_database = ref.child("projects").child(project).getData { (error, snapshot) in
            if let error = error {
                print("Error getting data \(error)")
            }
            else if snapshot.exists() {
                print("Got data \(snapshot.value!)")
                
                guard let projects_information_retrieved = snapshot.value as? Dictionary<String, Dictionary<String, Any>> else {
                    return
                }
                
                //Se houver dados ....
                let anchors_saved : [ARAnchor]
                
                /*
                 for anchor in anchors_saved {
                 let anchor = ARAnchor(name: anchor.name, transform: anchor.positions);
                 self.session.add(anchor: anchor);
                 }
                 */
                
                //just if user has this location on his position
                
                
                //Se não houver dados ....
                validation_code = 1
            }
            else {
                print("No data available")
            }
        }
        
        return validation_code
    }
    
    func saveProject(project: String) -> Int {
        
        var validation_code : Int = 0
        var index = 0
        //
        var ref = Database.database(url: "https://reforestar-database-default-rtdb.europe-west1.firebasedatabase.app/").reference().ref.child("projects").child(self.currentSceneManager.getSelectedProject()).child("trees")
        
        ref.getData { [self] (error, snapshot) in
            if let error = error {
                print("Error getting data \(error)")
            }
            else if snapshot.exists() {
                print("Got data \(snapshot.value!)")
                let result = snapshot.value as! NSArray
                print("Project To Save")
                index = result.count
                print(index)
                
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
                        //save user's location
                        let result_location: Void = ref.child("\(index)").child("location").setValue("Location")
                        
                        index+=1
                    }
                    
                }else{
                    //Se não conseguir salvar dados ....
                    validation_code = 1
                    print("There is no elements to be saved to project \(self.currentSceneManager.getSelectedProject())")
                }
                
            }else{
                //Se não conseguir salvar dados ....
                validation_code = 1
                print("Can't be saved because no project has been selected")
            }
        })
        
        
        return validation_code
    }
    
    
    func setupGestures() {
        //tap gesture for placing trees
        self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap(recognizer:))))
    }
    
    @objc
    func handleTap(recognizer: UITapGestureRecognizer){
        
        let touchInView = recognizer.location(in: self)
        let results = self.raycast(from: touchInView, allowing: .estimatedPlane, alignment: .horizontal)
        
        if let firstResult = results.first{
            
            //At this point, the touch in the screen was recognized by the AR tecnhology to be considered a real surface.
            //Hello
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
                
                //If the array has not items, it means there was a problem, so either didn't find space to all the trees or the intial position wasn't available.
            }else{
                print("Coudn't find space")
            }
            
        }else{
            print("Object placement failed - coudn't find surface")
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
            }
            
        }
        
    }
}

extension SIMD4 {
    
    func getValueStringed()->String{
        return String("\(self.x);\(self.y);\(self.z);\(self.w)")
    }
    
}
