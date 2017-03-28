//
//  MKMapRectExtension.swift
//  iNear
//
//  Created by Сергей Сейтов on 04.03.17.
//  Copyright © 2017 Сергей Сейтов. All rights reserved.
//

import MapKit

extension MKMapRect {
    init(coordinates: [CLLocationCoordinate2D]) {
        self = coordinates.map({ MKMapPointForCoordinate($0) }).map({ MKMapRect(origin: $0, size: MKMapSize(width: 0, height: 0)) }).reduce(MKMapRectNull, MKMapRectUnion)
    }
}
