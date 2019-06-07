//
//  Fields.swift
//  FaunaDB
//
//  Created by JimLai on 2019/6/10.
//

import Foundation

typealias F = Fields
public enum Fields: String, JSONKey {
    case id, `class`, database, resource, ref, create_class, name, params, create, data
    public var jkey: String {
        return self.rawValue
    }
}
