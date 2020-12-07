//
//  ViewController.swift
//  InteractiveClusteringMap
//
//  Created by Oh Donggeon on 2020/11/16.
//

import UIKit
import CoreLocation
import NMapsMap

final class MapViewController: UIViewController {
    @IBOutlet private weak var interactiveMapView: InteractiveMapView!
    private let locationManager = CLLocationManager()
    private var mapController: MapController?
    private var dataManager: DataManagable?
    internal var transparentLayer: TransparentLayer?
    private let infoWindowForDelete = NMFInfoWindow()
    private let dataSourceForDelete = NMFInfoWindowDefaultTextSource.data()
    internal let infoWindowForAdd = NMFInfoWindow()
    private let dataSourceForAdd = NMFInfoWindowDefaultTextSource.data()
    private var presentedLeafNodeMarkers: [LeafNodeMarker] = []
    
    init?(coder: NSCoder, dataManager: DataManagable) {
        super.init(coder: coder)
        self.dataManager = dataManager
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        locationManager.requestWhenInUseAuthorization()
        dependencyInject()
        configureMap()
    }
    
    private func dependencyInject() {
        guard let dataManager = dataManager else { return }
        
        let poiService = POIService(dataManager: dataManager)
        let presenter: ClusterPresentationLogic = MapPresenter(createMarkerHandler: create, removeMarkerHandler: remove)
        let mapInteractor: ClusterBusinessLogic = MapInteractor(poiService: poiService, presenter: presenter)
        mapController = MapController(mapView: interactiveMapView, interactor: mapInteractor)
    }
    
    private func configureInfoWindow() {
        
        dataSourceForDelete.title = "삭제"
        infoWindowForDelete.dataSource = dataSourceForDelete
        dataSourceForAdd.title = "추가"
        infoWindowForAdd.dataSource = dataSourceForAdd
        
        infoWindowForDelete.touchHandler = { [weak self] (_) -> Bool in
            self?.infoWindowForDelete.close()
            let alert = MapAlertController(alertType: .delete) { _ in
                
            }
            self?.present(alert.createAlertController(), animated: true)
            return true
        }
        
        infoWindowForAdd.touchHandler = { [weak self] (_) -> Bool in
            let alert = MapAlertController(alertType: .add, okHandler: nil)
            self?.present(alert.createAlertController(), animated: true)
            return true
        }
    }
    
    private func configureMap() {
        interactiveMapView?.mapView.touchDelegate = self
        
        interactiveMapView.mapView.moveCamera(NMFCameraUpdate(scrollTo: NMGLatLng(lat: 37.56825785, lng: 126.9930027), zoomTo: 15))
        
        let coords1 = [NMGLatLng(lat: 37.5764792, lng: 126.9956437),
                       NMGLatLng(lat: 37.5600365, lng: 126.9956437),
                       NMGLatLng(lat: 37.5600365, lng: 126.9903617),
                       NMGLatLng(lat: 37.5764792, lng: 126.9903617),
                       NMGLatLng(lat: 37.5764792, lng: 126.9956437)]
        
        let polygon = NMGPolygon(ring: NMGLineString(points: coords1)) as NMGPolygon<AnyObject>
        let polygonOverlay = NMFPolygonOverlay(polygon)
        polygonOverlay?.fillColor = UIColor(red: 25.0/255.0, green: 192.0/255.0, blue: 46.0/255.0, alpha: 31.0/255.0)
        polygonOverlay?.outlineWidth = 3
        polygonOverlay?.mapView = interactiveMapView.mapView
        
        interactiveMapView.mapView.addCameraDelegate(delegate: self)
        
        transparentLayer = TransparentLayer(bounds: view.bounds)
        guard let transparentLayer = transparentLayer else { return }
        
        interactiveMapView.mapView.layer.addSublayer(transparentLayer)
        let gestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        gestureRecognizer.minimumPressDuration = 0.7
        interactiveMapView.addGestureRecognizer(gestureRecognizer)
    }
    
    @objc func handleLongPress(gesture: UILongPressGestureRecognizer) {
        guard gesture.state != .began else {
            return
        }
        if isMarkerLongPressed(gesture: gesture) {
            showMarkerEditMode()
        }
    }
    
    private func isMarkerLongPressed(gesture: UILongPressGestureRecognizer) -> Bool {
        for marker in presentedLeafNodeMarkers {
            let markerScreenCoordinate = interactiveMapView.projectPoint(from: marker.position)
            let markerMinX = markerScreenCoordinate.x - (marker.iconImage.imageWidth / 2) - 5
            let markerMaxX = markerScreenCoordinate.x + (marker.iconImage.imageWidth / 2) + 5
            let markerMinY = markerScreenCoordinate.y - (marker.iconImage.imageHeight / 2) - 30
            let markerMaxY = markerScreenCoordinate.y
            
            let containX = (markerMinX..<markerMaxX).contains(gesture.location(in: interactiveMapView).x)
            let containY = (markerMinY..<markerMaxY).contains(gesture.location(in: interactiveMapView).y)
            if containX && containY {
                let generator = UIImpactFeedbackGenerator(style: .heavy)
                generator.impactOccurred()
                
                return true
            }
        }
        return false
    }
    
    private func showMarkerEditMode() {
        unableGestures()
        
        presentedLeafNodeMarkers.forEach { marker in
            marker.hidden = true
            let leafNodeMarkerLayer = LeafNodeMarkerLayer(marker: marker)
            transparentLayer?.addSublayer(leafNodeMarkerLayer)
            leafNodeMarkerLayer.position = self.interactiveMapView.projectPoint(from: NMGLatLng(lat: marker.coordinate.y, lng: marker.coordinate.x))
            leafNodeMarkerLayer.editLayer.position = CGPoint(x: 8, y: 8)
        }
    }
    
    internal func setMarkerPosition(marker: CALayer) {
        guard let marker = marker as? ClusteringMarkerLayer else { return }
        
        let latLng = NMGLatLng(lat: marker.coordinate.y, lng: marker.coordinate.x)
        marker.updatePosition(position: interactiveMapView.projectPoint(from: latLng))
    }
    
    private func create(markers: [NMFMarker]) {
        markers.forEach { marker in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                marker.mapView = self.interactiveMapView.mapView
                marker.hidden = true
                
                if let leafNodeMarker = marker as? LeafNodeMarker {
                    self.animate(marker: leafNodeMarker)
                    self.presentedLeafNodeMarkers.append(leafNodeMarker)
                } else if let interactiveMarker = marker as? InteractiveMarker {
                    interactiveMarker.touchHandler = { [weak self] (_) -> Bool in
                        self?.infoWindowForAdd.close()
                        self?.infoWindowForDelete.open(with: interactiveMarker)
                        return true
                    }
                    self.animate(marker: interactiveMarker)
                }
            }
        }
    }
    
    private func remove(markers: [NMFMarker]) {
        markers.forEach { marker in
            DispatchQueue.main.async {
                marker.mapView = nil
            }
            if let leafNodeMarker = marker as? LeafNodeMarker {
                self.presentedLeafNodeMarkers.removeAll { $0 == leafNodeMarker }
            }
        }
    }
    
    private func animate(marker: NMFMarker) {
        var markerLayer: CALayer?
        var markerAnimation: CAAnimation?
        
        if let leafNodeMarker = marker as? LeafNodeMarker {
            markerLayer = leafNodeMarker.markerLayer
            guard let markerLayer = markerLayer else { return }
            
            markerLayer.anchorPoint = CGPoint(x: 0.5, y: 1)
            markerLayer.position = interactiveMapView.projectPoint(from: NMGLatLng(lat: leafNodeMarker.coordinate.y,
                                                                                    lng: leafNodeMarker.coordinate.x))
            markerAnimation = AnimationController.leafNodeAnimation(position: markerLayer.position)
        
        } else if let interactiveMarker = marker as? InteractiveMarker {
            markerLayer = interactiveMarker.markerLayer
            markerLayer?.position = interactiveMapView.projectPoint(from: NMGLatLng(lat: interactiveMarker.coordinate.y,
                                                                                lng: interactiveMarker.coordinate.x))
            markerAnimation = AnimationController.transformScale(option: .increase)
        }
        guard let layer = markerLayer,
              let animation = markerAnimation else { return }
        
        transparentLayer?.addSublayer(layer)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        CATransaction.setCompletionBlock {
            markerLayer?.removeFromSuperlayer()
            marker.hidden = false
        }
        markerLayer?.add(animation, forKey: "markerAnimation")
        CATransaction.commit()
    }
    
    private func enableGestures() {
        interactiveMapView.mapView.allowsScrolling = true
        interactiveMapView.mapView.allowsRotating = true
        interactiveMapView.mapView.allowsZooming = true
        interactiveMapView.showZoomControls = true
        
    }
    
    private func unableGestures() {
        interactiveMapView.mapView.allowsScrolling = false
        interactiveMapView.mapView.allowsRotating = false
        interactiveMapView.mapView.allowsZooming = false
        interactiveMapView.showZoomControls = false
    }
    
}

extension MapViewController: NMFMapViewTouchDelegate {
    func mapView(_ mapView: NMFMapView, didTapMap latlng: NMGLatLng, point: CGPoint) {
        enableGestures()
        
        self.transparentLayer!.sublayers?.forEach { $0.removeFromSuperlayer() }
        
        presentedLeafNodeMarkers.forEach {
            $0.hidden = false
        }
//  머지 후 삭제 예정
//        infoWindowForAdd.close()
//        infoWindowForDelete.close()
//        infoWindowForAdd.position = latlng
//        infoWindowForAdd.open(with: mapView)
    }
}
