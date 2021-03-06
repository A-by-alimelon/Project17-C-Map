//
//  AlertController.swift
//  InteractiveClusteringMap
//
//  Created by A on 2020/12/05.
//

import Foundation
import UIKit

typealias HandlerWithText = (String?) -> Void
typealias ActionHandler = (UIAlertAction) -> Void

final class MapAlertControllerFactory {
    
    static func createAddAlertController(_ okHandler: @escaping HandlerWithText, cancelHandler: ActionHandler? = nil) -> UIAlertController {
        let alert = UIAlertController(title: Name.addTitle, message: Name.addMessage, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default) { (_) in
            okHandler(alert.textFields?.first?.text)
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: cancelHandler)
        
        alert.addAction(okAction)
        alert.addAction(cancelAction)
        alert.addTextField { (textField) in
            textField.placeholder = "장소 이름"
        }
        
        return alert
    }
    
    static func createDeleteAlertController(_ okHandler: @escaping ActionHandler, cancelHandler: ActionHandler? = nil) -> UIAlertController {
        let alert = UIAlertController(title: Name.deleteTitle, message: Name.deleteMessage, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "Delete", style: .destructive, handler: okHandler)
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: cancelHandler)
        
        alert.addAction(okAction)
        alert.addAction(cancelAction)
        
        return alert
    }
    
}

extension MapAlertControllerFactory {
    
    private enum Name {
        static let deleteTitle: String = "마커 삭제"
        static let deleteMessage: String = "해당 위치의 마커를 삭제하시겠습니까?"
        static let addTitle: String = "마커 추가"
        static let addMessage: String = "해당 위치에 마커를 추가하시겠습니까? \n장소의 이름을 입력해 주세요."
    }
    
    enum AlertType {
        case add
        case delete
    }
}
