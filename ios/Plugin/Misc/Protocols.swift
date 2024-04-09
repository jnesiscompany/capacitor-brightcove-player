//
//  Protocols.swift
//  OfflinePlayer
//
//  Copyright © 2020 Brightcove, Inc. All rights reserved.
//

import Foundation
import BrightcovePlayerSDK

protocol ReloadDelegate: AnyObject {
    func reloadData()
    func reloadRow(forVideo video: BCOVVideo)
}
