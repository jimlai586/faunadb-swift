//
//  JsonTests.swift
//  FaunaDBTests
//
//  Created by JimLai on 2019/6/10.
//

import XCTest
@testable import FaunaDB

class JsonTests: XCTestCase {
    let client = FaunaDB.Client(secret: "client secret")
    var exp = XCTestExpectation(description: "async")
    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        exp = expectation(description: "async")
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testMJWrite() {
        var mj = ["1": ["2": ["3": 4]]] as MJ
        mj["1"]["2"] = "123"
        dp(mj)
    }
    
    func testEncode() {
        //let mj = create(RefV("Post"), ObjV(mj: ["data": ["test": 123]]))
        //dp(mj)
    }
    
    func testClient() {
        client.query (
            //create(ref(id: "classes/Fall"), dataObj(["test": 123]))
            clazz("Fall")
        ).onSuccess { mj in
            self.exp.fulfill()
            dp(mj)
        }
        _ = XCTWaiter.wait(for: [exp], timeout: 5)
    }
    
    
}
