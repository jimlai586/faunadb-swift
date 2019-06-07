//
//  Future.swift
//  FaunaDB
//
//  Created by JimLai on 2019/6/1.
//

import Foundation

public typealias QueryResult<T> = Promise<T>

public final class Promise<T> {
    public typealias Callback = (Result<T, Error>) -> Void
    public var cbComplete: Callback?
    public var cbSuccess: ((T) -> Void)?
    public var cbFailure: ((Error) -> Void)?
    public var value: Result<T, Error>? {
        didSet {
            guard let v = value else {return}
            cbComplete?(v)
            switch v {
            case .success(let r):
                cbSuccess?(r)
            case .failure(let e):
                cbFailure?(e)
            }
        }
    }

    public func map<V>(_ transform: @escaping (Promise<T>) -> Promise<V>) -> Promise<V> {
        return transform(self)
    }

    public func then<V>(_ fulfill: @escaping (T, Promise<V>) -> Void) -> Promise<V> {
        let pv = Promise<V>()
        let cb: Callback = { result in
            switch result {
            case .success(let t):
                fulfill(t, pv)
            case .failure(let e):
                pv.value = .failure(e)
            }
        }
        cbComplete = cb
        return pv
    }
    public func onComplete(_ cls: @escaping Callback) {
        cbComplete = cls
    }
    public func onSuccess(_ cls: @escaping (T) -> Void) {
        cbSuccess = cls
    }
    public func onFailure(_ cls: @escaping (Error) -> Void) {
        cbFailure = cls
    }
}
