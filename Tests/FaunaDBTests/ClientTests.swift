import XCTest
import FaunaDB

fileprivate let dbName = String.random(startingWith: "faunadb-swift-test-")

fileprivate let endpoint: URL? = {
    guard let url = env("FAUNA_ENDPOINT") else { return nil }
    return URL(string: url)
}()

fileprivate let secret: String = {
    guard let key = env("FAUNA_ROOT_KEY") else {
        fatalError(
            "Environment variable FAUNA_ROOT_KEY not defined. " +
            "Check your scheme run configuration. " +
            "Tip: You can also set FAUNA_ENDPOINT if you want to run " +
            "the tests against a different Fauna instance. Fauna Cloud is used by default."
        )
    }
    return key
}()

fileprivate let adminClient: Client = {
    guard let endpoint = endpoint else { return Client(secret: secret) }
    return Client(secret: secret, endpoint: endpoint)
}()

fileprivate let client: Client = {
    return try!
        adminClient.query(
            CreateDatabase(Obj("name" => dbName))
        )
        .flatMap {
            adminClient.query(
                CreateKey(Obj(
                    "database" => try $0.get("ref"),
                    "role" => "server"
                ))
            )
        }
        .map {
            adminClient.newSessionClient(
                secret: try $0.get("secret")!
            )
        }
        .await()
}()

class ClientTests: XCTestCase {

    private typealias `Self` = ClientTests

    private static var
        randomClass,
        characters,
        spells,
        spellbook,
        allSpells,
        spellsByElement,
        elementsOfSpells,
        spellbookByOwner,
        spellsBySpellbook,
        magicMissile,
        fireball,
        faerieFire,
        thor,
        thorsSpellbook: RefV!

    override class func setUp() {
        super.setUp()

        randomClass = queryForRef(CreateClass(Obj("name" => "some_random_class")))
        spells = queryForRef(CreateClass(Obj("name" => "spells")))
        spellbook = queryForRef(CreateClass(Obj("name" => "spellbook")))
        characters = queryForRef(CreateClass(Obj("name" => "characters")))

        allSpells = queryForRef(CreateIndex(Obj(
            "name" => "all_spells",
            "source" => spells
        )))

        spellsByElement = queryForRef(CreateIndex(Obj(
            "name" => "spells_by_element",
            "source" => spells,
            "terms" => Arr(Obj("field" => Arr("data", "elements")))
        )))

        elementsOfSpells = queryForRef(CreateIndex(Obj(
            "name" => "elements_of_spells",
            "source" => spells,
            "values" => Arr(Obj("field" => Arr("data", "elements")))
        )))

        spellbookByOwner = queryForRef(CreateIndex(Obj(
            "name" => "spellbook_by_owner",
            "source" => spellbook,
            "terms" => Arr(Obj("field" => Arr("data", "owner")))
        )))

        spellsBySpellbook = queryForRef(CreateIndex(Obj(
            "name" => "spells_by_spellbook",
            "source" => spells,
            "terms" => Arr(Obj("field" => Arr("data", "book")))
        )))

        thor = queryForRef(
            Create(at: characters, Obj(
                "data" => Obj(
                    "name" => "thor"
                )
            ))
        )

        thorsSpellbook = queryForRef(
            Create(at: spellbook, Obj("data" => Obj("owner" => thor)))
        )

        magicMissile = queryForRef(
            Create(at: spells, Obj(
                "data" => Obj(
                    "name" => "Magic Missile",
                    "elements" => Arr("arcane"),
                    "cost" => 10
                )
            ))
        )

        fireball = queryForRef(
            Create(at: spells, Obj(
                "data" => Obj(
                    "name" => "Fireball",
                    "elements" => Arr("fire"),
                    "cost" => 10,
                    "book" => thorsSpellbook
                )
            ))
        )

        faerieFire = queryForRef(
            Create(at: spells, Obj(
                "data" => Obj(
                    "name" => "Faerie Fire",
                    "elements" => Arr("arcane", "nature"),
                    "cost" => 10
                )
            ))
        )
    }

    override class func tearDown() {
        super.tearDown()
        try! adminClient
            .query(Delete(ref: Database(dbName)))
            .await()
    }

    func testReturnUnauthorizedOnInvalidSecret() {
        let invalidClient = client.newSessionClient(secret: "invalid-secret")
        let query = invalidClient.query(Get(Ref("classes/spells/42")))

        XCTAssertThrowsError(try query.await()) { error in
            XCTAssert(error is Unauthorized)
        }
    }

    func testReturnNotFoundOnNonExistingInstance() {
        let res = client.query(
            Get(Ref(class: Self.randomClass, id: String.random()))
        )

        XCTAssertThrowsError(try res.await()) { error in
            XCTAssert(error is NotFound)
        }
    }

    func testPermissionDeniedWhenAccessingRestrictedResource() {
        let key = try! adminClient.query(
            CreateKey(Obj(
                "database" => Database(dbName),
                "role" => "client"
            ))
        ).await()

        let client = adminClient.newSessionClient(secret: try! key.get("secret")!)
        let restrictedQuery = client.query(Paginate(Ref("databases")))

        XCTAssertThrowsError(try restrictedQuery.await()) { error in
            XCTAssert(error is PermissionDenied)
        }
    }

    func testCreateAComplexInstance() {
        let instance = try! client.query(
            Create(at: Self.randomClass, Obj(
                "data" => Obj(
                    "string" => "a string",
                    "int" => 42,
                    "double" => 42.2,
                    "bool" => true,
                    "arr" => Arr(
                        1,
                        true,
                        Obj("key" => "value")
                    ),
                    "obj" => Obj("nested" => "obj")
                )
            ))
        ).await()

        XCTAssertEqual(try instance.get("data", "string"), "a string")
        XCTAssertEqual(try instance.get("data", "int"), 42)
        XCTAssertEqual(try instance.get("data", "double"), 42.2)
        XCTAssertEqual(try instance.get("data", "bool"), true)
        XCTAssertEqual(try instance.get("data", "arr", 0), 1)
        XCTAssertEqual(try instance.get("data", "arr", 1), true)
        XCTAssertEqual(try instance.get("data", "arr", 2, "key"), "value")
        XCTAssertEqual(try instance.get("data", "obj", "nested"), "obj")
    }

    func testGetAnInstance() {
        assert(
            query: Get(Self.magicMissile),
            toReturn: "Magic Missile",
            atPath: "data", "name"
        )
    }

    func testBatchQuery() {
        let instances = try! client.query(batch: [
            Get(Self.magicMissile),
            Get(Self.thor)
        ]).await()

        XCTAssertEqual(instances.count, 2)
    }

    func testUpdateAnInstance() {
        let instance = try! client.query(
            Create(at: Self.randomClass, Obj(
                "data" => Obj("name" => "bob", "age" => 21)
            ))
        ).await()

        let updated = try! client.query(
            Update(ref: try! instance.get("ref")!, to: Obj(
                "data" => Obj("name" => "jhon")
            ))
        ).await()

        XCTAssertEqual(try! updated.get("data", "name"), "jhon")
        XCTAssertEqual(try! updated.get("data", "age"), 21)
    }

    func testReplaceAnInstance() {
        let instance = try! client.query(
            Create(at: Self.randomClass, Obj(
                "data" => Obj("name" => "bob", "age" => 21)
            ))
        ).await()

        let replaced = try! client.query(
            Replace(ref: try! instance.get("ref")!, with: Obj(
                "data" => Obj("name" => "jhon")
            ))
        ).await()

        XCTAssertEqual(try! replaced.get("data", "name"), "jhon")
        XCTAssertNil(try! replaced.get("data", "age"))
    }

    func testDeleteAnInstance() {
        let instance: RefV! = try! client.query(
            Create(
                at: Self.randomClass,
                Obj("data" => Obj("name" => "jhon"))
            )
        )
        .await()
        .get("ref")

        try! client.query(Delete(ref: instance)).await()
        assert(query: Exists(instance), toReturn: false)
    }

    func testLet() {
        assert(
            query: Let(1, 2) { a, b in
                Arr(b, a)
            },
            toReturn: [2, 1]
        )
    }

    func testDo() {
        let refToCreate = RefV(String.random(startingWith: Self.randomClass.value + "/"))

        assert(
            query: Do(
                Create(at: refToCreate, Obj("data" => Obj())),
                Get(refToCreate)
            ),
            toReturn: refToCreate,
            atPath: "ref"
        )
    }

    func testMapOverACollection() {
        assert(
            query: Map(Arr(1, 2, 3)) { Add(1, $0) },
            toReturn: [2, 3, 4]
        )
    }

    func testExecuteForeach() {
        assert(
            query: Foreach(Arr("Fireball level 1", "Fireball level 2")) { name in
                Create(at: Self.randomClass, Obj(
                    "data" => Obj("name" => name)
                ))
            },
            toReturn: ["Fireball level 1", "Fireball level 2"]
        )
    }

    func testFilterACollection() {
        assert(
            query: Filter(Arr(1, 2, 3)) { Equals(0, Modulo($0, 2)) },
            toReturn: [2]
        )
    }

    func testTakeElementsFromCollection() {
        assert(
            query: Take(count: 2, from: Arr(1, 2, 3)),
            toReturn: [1, 2]
        )
    }

    func testDropElementsFromCollection() {
        assert(
            query: Drop(count: 2, from: Arr(1, 2, 3)),
            toReturn: [3]
        )
    }

    func testPrependElementsToCollection() {
        assert(
            query: Prepend(elements: Arr(1, 2), to: Arr(3, 4)),
            toReturn: [1, 2, 3, 4]
        )
    }

    func testAppendElementsToCollection() {
        assert(
            query: Append(elements: Arr(1, 2), to: Arr(3, 4)),
            toReturn: [3, 4, 1, 2]
        )
    }

    func testPaginateOverAnIndex() {
        var page = try! client.query(
            Paginate(
                Match(index: Self.allSpells),
                size: 1
            )
        ).await()

        XCTAssertEqual(try page.get("data"), [Self.magicMissile])

        page = try! client.query(
            Paginate(
                Match(index: Self.allSpells),
                after: page.get("after"),
                size: 1
            )
        ).await()

        XCTAssertEqual(try page.get("data"), [Self.fireball])

        page = try! client.query(
            Paginate(
                Match(index: Self.allSpells),
                before: page.get("before"),
                size: 1
            )
        ).await()

        XCTAssertEqual(try page.get("data"), [Self.magicMissile])
    }

    func testFindSingleInstanceOnAnIndex() {
        assert(query:
            Paginate(
                Match(
                    index: Self.spellsByElement,
                    terms: "fire"
                )
            ),
            toReturn: [Self.fireball],
            atPath: "data"
        )
    }

    func testUnion() {
        assert(
            query: Paginate(
                Union(
                    Match(index: Self.spellsByElement, terms: "arcane"),
                    Match(index: Self.spellsByElement, terms: "fire")
                )
            ),
            toReturn: [Self.magicMissile, Self.fireball, Self.faerieFire],
            atPath: "data"
        )
    }

    func testIntersection() {
        assert(
            query: Paginate(
                Intersection(
                    Match(index: Self.spellsByElement, terms: "arcane"),
                    Match(index: Self.spellsByElement, terms: "nature")
                )
            ),
            toReturn: [Self.faerieFire],
            atPath: "data"
        )
    }

    func testDifference() {
        assert(
            query: Paginate(
                Difference(
                    Match(index: Self.spellsByElement, terms: "arcane"),
                    Match(index: Self.spellsByElement, terms: "nature")
                )
            ),
            toReturn: [Self.magicMissile],
            atPath: "data"
        )
    }

    func testDistinct() {
        assert(
            query: Paginate(
                Distinct(
                    Match(index: Self.elementsOfSpells)
                )
            ),
            toReturn: ["arcane", "fire", "nature"],
            atPath: "data"
        )
    }

    func testJoin() {
        assert(
            query: Paginate(
                Join(Match(index: Self.spellbookByOwner, terms: Self.thor)) { book in
                    Match(index: Self.spellsBySpellbook, terms: book)
                }
            ),
            toReturn: [Self.fireball],
            atPath: "data"
        )
    }

    func testConcat() {
        assert(query: Concat("Hellow", "World"), toReturn: "HellowWorld")
        assert(query: Concat("Hellow", "World", separator: " " ), toReturn: "Hellow World")
    }

    func testCasefold() {
        assert(query: Casefold("GET DOWN"), toReturn: "get down")
    }

    func testTime() {
        assert(
            query: Time(fromString: "1970-01-01T00:00:00-00:00:05"),
            toReturn: Date(timeIntervalSince1970: 5)
        )
    }

    func testEpoch() {
        assert(query: Epoch(offset: 30, unit: .second), toReturn: Date(timeIntervalSince1970: 30))
        assert(query: Epoch(offset: 30, unit: .second), toReturn: HighPrecisionTime(secondsSince1970: 30))
        assert(query: Epoch(offset: 30, unit: .millisecond), toReturn: HighPrecisionTime(secondsSince1970: 0, millisecondsOffset: 30))
        assert(query: Epoch(offset: 30, unit: .microsecond), toReturn: HighPrecisionTime(secondsSince1970: 0, microsecondsOffset: 30))
        assert(query: Epoch(offset: 30, unit: .nanosecond), toReturn: HighPrecisionTime(secondsSince1970: 0, nanosecondsOffset: 30))
    }

    func testDate() {
        assert(
            query: DateFn(string: "1970-01-01"),
            toReturn: Date(timeIntervalSince1970: 0)
        )
    }

    func testAuthenticate() {
        let user: RefV! = try! client.query(
            Create(at: Self.randomClass, Obj(
                "credentials" => Obj(
                    "password" => "abcd"
                )
            ))
        ).await().get("ref")

        let auth = try! client.query(
            Login(for: user, Obj(
                "password" => "abcd"
            ))
        ).await()

        let sessionClient = try! client.newSessionClient(secret: auth.get("secret")!)

        XCTAssertTrue(
            try! sessionClient.query(
                Logout(all: true)
            )
            .await()
            .get()!
        )

        XCTAssertFalse(
            try! client.query(
                Identify(
                    ref: user,
                    password: "wrong-password"
                )
            ).await().get()!
        )
    }

    func testNextId() {
        let id: String! = try! client.query(NextId()).await().get()
        XCTAssertNotNil(id)
    }

    func testRefFunctions() {
        assert(
            query: Arr(
                Index("all_spells"),
                Class("spells")
            ),
            toReturn: [Self.allSpells, Self.spells]
        )
    }

    func testEquals() {
        assert(query: Equals("fire", "fire"), toReturn: true)
    }

    func testContains() {
        assert(
            query: Contains(path: "favorites", "foods", in: Obj(
                "favorites" => Obj(
                    "foods" => Arr("crunchings", "munchings")
                )
            )),
            toReturn: true
        )
    }

    func testSelect() {
        assert(
            query: Select(path: "favorites", "foods", 1, from: Obj(
                "favorites" => Obj(
                    "foods" => Arr("crunchings", "munchings")
                )
            )),
            toReturn: "munchings"
        )

        assert(
            query: Select(
                path: "favorites", "foods", 2,
                from: Obj(
                    "favorites" => Obj(
                        "foods" => Arr("crunchings", "munchings")
                    )
                ),
                default: "bananas"
            ),
            toReturn: "bananas"
        )
    }

    func testAdd() {
        assert(query: Add(1, 2), toReturn: 3)
    }

    func testMultiply() {
        assert(query: Multiply(2, 2), toReturn: 4)
    }

    func testSubtract() {
        assert(query: Subtract(5, 3), toReturn: 2)
    }

    func testDivide() {
        assert(query: Divide(10, 5), toReturn: 2)
    }

    func testModulo() {
        assert(query: Modulo(10, 5), toReturn: 0)
    }

    func testLT() {
        assert(query: LT(0, 1), toReturn: true)
    }

    func testLTE() {
        assert(query: LTE(1, 1), toReturn: true)
    }

    func testGT() {
        assert(query: GT(1, 0), toReturn: true)
    }

    func testGTE() {
        assert(query: GTE(0, 0), toReturn: true)
    }

    func testAnd() {
        assert(query: And(true, true), toReturn: true)
    }

    func testOr() {
        assert(query: Or(false, true), toReturn: true)
    }

    func testNot() {
        assert(query: Not(false), toReturn: true)
    }

    func testSetRefV() {
        let match: SetRefV! = try! client.query(
            Match(
                index: Self.spellsByElement,
                terms: "arcane"
            )
        ).await().get()

        XCTAssertEqual(try! match.value["match"]?.get(), Self.spellsByElement)
        XCTAssertEqual(try! match.value["terms"]?.get(), "arcane")
    }

    func testEchoAObjectBack() {
        assert(query: Obj("key" => "value"), toReturn: ["key": "value"])
    }

    private static func queryForRef(_ expr: Expr) -> RefV {
        return try! client.query(expr).await().get("ref")!
    }

    private func assert<T: Equatable>(query expr: Expr, toReturn expected: T, atPath: Segment...) {
        XCTAssertEqual(try! client.query(expr).await().get(path: atPath), expected)
    }

    private func assert<T: Equatable>(query expr: Expr, toReturn expected: [T], atPath: Segment...) {
        XCTAssertEqual(try! client.query(expr).await().get(path: atPath), expected)
    }

    private func assert<T: Equatable>(query expr: Expr, toReturn expected: [String: T], atPath: Segment...) {
        XCTAssertEqual(try! client.query(expr).await().get(path: atPath), expected)
    }

}