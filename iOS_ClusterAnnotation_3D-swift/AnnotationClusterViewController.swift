//
//  AnnotationClusterViewController.swift
//  iOS_ClusterAnnotation_3D
//
//  Created by AutoNavi on 2016/12/16.
//  Copyright © 2016年 AutoNavi. All rights reserved.
//

import Foundation

let calloutViewMargin = -12.0
let buttonHeight = 70.0

class AnnotationClusterViewController: UIViewController, MAMapViewDelegate, AMapSearchDelegate, CustomCalloutViewTapDelegate {
    
    var mapView: MAMapView!
    var search: AMapSearchAPI!
    var refreshButton: UIButton!
    
    var coordinateQuadTree = CoordinateQuadTree()
    var customCalloutView = CustomCalloutView()
    var selectedPoiArray = Array<AMapPOI>()
    var shouldRegionChangeReCalculate = false
    var currentRequest: AMapPOIKeywordsSearchRequest?
    
    //MARK: - Update Annotation
    
    func updateMapViewAnnotations(annotations: Array<ClusterAnnotation>) {
        
        /* 用户滑动时，保留仍然可用的标注，去除屏幕外标注，添加新增区域的标注 */
        let before = NSMutableSet(array: mapView.annotations)
        before.remove(mapView.userLocation)
        let after: Set<NSObject> = NSSet(array: annotations) as Set<NSObject>
        
        /* 保留仍然位于屏幕内的annotation. */
        var toKeep: Set<NSObject> = NSMutableSet(set: before) as Set<NSObject>
        toKeep = toKeep.intersection(after)
        
        /* 需要添加的annotation. */
        let toAdd = NSMutableSet(set: after)
        toAdd.minus(toKeep)
        
        /* 删除位于屏幕外的annotation. */
        let toRemove = NSMutableSet(set: before)
        toRemove.minus(after)
        
        DispatchQueue.main.async(execute: { [weak self] () -> Void in
            self?.mapView.addAnnotations(toAdd.allObjects)
            self?.mapView.removeAnnotations(toRemove.allObjects)
        })
    }
    
    func addAnnotations(toMapView mapView: MAMapView) {
        synchronized(lock: self) { [weak self] in
            
            guard (self?.coordinateQuadTree.root != nil) || self?.shouldRegionChangeReCalculate != false else {
                NSLog("tree is not ready.")
                return
            }
            
            guard let aMapView = self?.mapView else {
                return
            }
            
            let visibleRect = aMapView.visibleMapRect
            let zoomScale = Double(aMapView.bounds.size.width) / visibleRect.size.width
            let zoomLevel = Double(aMapView.zoomLevel)
            
            DispatchQueue.global(qos: .default).async(execute: { [weak self] in
                
                let annotations = self?.coordinateQuadTree.clusteredAnnotations(within: visibleRect, withZoomScale: zoomScale, andZoomLevel: zoomLevel)
                
                self?.updateMapViewAnnotations(annotations: annotations as! Array<ClusterAnnotation>)
            })
        }
    }
    
    func synchronized(lock: AnyObject, closure: () -> ()) {
        objc_sync_enter(lock)
        closure()
        objc_sync_exit(lock)
    }
    
    //MARK: - CustomCalloutViewTapDelegate
    
    func didDetailButtonTapped(_ index: Int) {
        let detail = PoiDetailViewController()
        detail.poi = selectedPoiArray[index]
        
        navigationController?.pushViewController(detail, animated: true)
    }
    
    //MARK: - MAMapViewDelegate
    
    func mapView(_ mapView: MAMapView!, didSelect view: MAAnnotationView!) {
        let annotation = view.annotation as! ClusterAnnotation
        
        for poi in annotation.pois {
            selectedPoiArray.append(poi as! AMapPOI)
        }
        
        customCalloutView.poiArray = selectedPoiArray
        customCalloutView.delegate = self
        
        customCalloutView.center = CGPoint(x: Double(view.bounds.midX), y: -Double(customCalloutView.bounds.midY)-Double(view.bounds.midY)-calloutViewMargin)
        
        view.addSubview(customCalloutView)
    }
    
    func mapView(_ mapView: MAMapView!, didDeselect view: MAAnnotationView!) {
        selectedPoiArray.removeAll()
        customCalloutView.dismiss()
        customCalloutView.delegate = nil
    }
    
    func mapView(_ mapView: MAMapView!, regionDidChangeAnimated animated: Bool) {
        addAnnotations(toMapView: self.mapView)
    }
    
    func mapView(_ mapView: MAMapView!, viewFor annotation: MAAnnotation!) -> MAAnnotationView! {
        if annotation is ClusterAnnotation {
            let pointReuseIndetifier = "pointReuseIndetifier"
            
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: pointReuseIndetifier) as? ClusterAnnotationView
            
            if annotationView == nil {
                annotationView = ClusterAnnotationView(annotation: annotation, reuseIdentifier: pointReuseIndetifier)
            }
            
            annotationView?.annotation = annotation
            annotationView?.count = UInt((annotation as! ClusterAnnotation).count)
            
            return annotationView
        }
        
        return nil
    }
    
    //MARK: - Search POI
    
    func searchPoi(keywords: String) {
        let request = AMapPOIKeywordsSearchRequest()
        request.keywords = keywords
        request.city = "010"
        request.requireExtension = true
        
        currentRequest = request
        search.aMapPOIKeywordsSearch(request)
    }
    
    func onPOISearchDone(_ request: AMapPOISearchBaseRequest!, response: AMapPOISearchResponse!) {
        guard response.pois.count > 0 else {
            return
        }
        
        guard request == currentRequest else {
            return
        }
        
        synchronized(lock: self) { [weak self] in
            
            self?.shouldRegionChangeReCalculate = false
            
            self?.selectedPoiArray.removeAll()
            self?.customCalloutView.dismiss()
            self?.mapView.removeAnnotations(self?.mapView.annotations)
            
            DispatchQueue.global(qos: .default).async(execute: { [weak self] in
                
                self?.coordinateQuadTree.build(withPOIs: response.pois)
                self?.shouldRegionChangeReCalculate = true
                self?.addAnnotations(toMapView: (self?.mapView)!)
            })
        }
    }
    
    //MARK: - Button Action
    
    func refreshButtonAvtion() {
        searchPoi(keywords: "Apple")
    }
    
    //MARK: - Init
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        initMapView()
        
        initSearch()
        
        initRefreshButton()
        
        refreshButtonAvtion()
    }
    
    deinit {
        coordinateQuadTree.clean()
    }
    
    func initMapView() {
        mapView = MAMapView(frame: view.bounds)
        mapView.frame = CGRect(x: 0, y: 0, width: view.frame.size.width, height: view.frame.size.height-CGFloat(buttonHeight))
        mapView.delegate = self
        
        view.addSubview(mapView)
        
        mapView.visibleMapRect = MAMapRectMake(220880104, 101476980, 272496, 466656)
    }
    
    func initSearch() {
        search = AMapSearchAPI()
        search.delegate = self
    }
    
    func initRefreshButton() {
        refreshButton = UIButton(type: .custom)
        refreshButton.frame = CGRect(x: 0, y: Double(mapView.frame.origin.y+mapView.frame.size.height), width: Double(mapView.frame.size.width), height: buttonHeight)
        refreshButton.setTitle("重新加载数据", for: .normal)
        refreshButton.setTitleColor(UIColor.purple, for: .normal)
        
        refreshButton.addTarget(self, action: #selector(self.refreshButtonAvtion), for: .touchUpInside)
        
        view.addSubview(refreshButton)
    }
    
}
