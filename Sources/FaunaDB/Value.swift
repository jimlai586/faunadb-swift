import Foundation

/**
    Represents a timestamp returned by the server.

    [Reference](https://fauna.com/documentation/queries#values-special_types)

    - Note: You can convert a timestamp to two different types:

        - `HighPrecisionTime`: A timestamp with nanoseconds precision.
        - `Date`: A timestamp with seconds precision only.
*/
// swiftlint:disable:next cyclomatic_complexity
public func faunaDecode(_ v: Any) -> Any {
    switch v {
    case is String:
        return v
    case is Int:
        return v
    case is Bool:
        return v
    case is Double:
        return v
    case let u as [Any]:
        return u.map(faunaDecode)
    case let u as [String: Any]:
        guard u.keys.count == 1, let k = u.keys.first, let t = Tags(rawValue: k.replacingOccurrences(of: "@", with: "")), let value = u[k] else {
            return u.mapValues(faunaDecode)
        }
        let mj = MJ(faunaDecode(value))
        switch t {
        case .ref:
            return RefV.decode(mj: mj)
        case .date:
            return DateV.decode(mj: mj)
        case .bytes:
            return BytesV.decode(mj: mj)
        case .ts:
            return TimeV.decode(mj: mj)
        case .set:
            return SetV.decode(mj: mj)
        case .query:
            return QueryV.decode(mj: mj)
        case .obj:
            return ObjV.decode(mj: mj)
        }
    default:
        return v
    }
}

public func faunaEncode(_ v: Any) -> Any {
    dp(v)
    switch v {
    case is String:
        return v
    case is Int:
        return v
    case is Bool:
        return v
    case is Double:
        return v
    case let u as Value:
        return u.encode()
    case let u as [Any]:
        return u.map(faunaEncode)
    case let u as [String: Any]:
        return u.mapValues(faunaEncode)
    default:
        return v
    }
}
public enum Tags: String {
    case ref, date, bytes, query, set, obj, ts
    static var object = "object"
    static var null = "null"
    var tag: String {
        return "@\(rawValue)"
    }
}

public protocol FaunaCodable {
    static func decode(mj: MJ) -> Any
    func encode() -> Any
}

extension MagicJSON: ExpressibleByDictionaryLiteral {
    public typealias Key = JSONKey
    public typealias Value = Any?
    public init(dictionaryLiteral elements: (Key, Value)...) {
        var d = [String: Any?]()
        elements.forEach { (k, v) in
            d[k.jkey] = v
        }
        self.init(d.toStringKey())
    }
}

public typealias Value = FaunaCodable & CustomStringConvertible

public struct TimeV: Value {
    public static func decode(mj: MJ) -> Any {
        guard let tv = TimeV(from: mj.stringValue) else {
            return MJ.nullString
        }
        return tv
    }

    public func encode() -> Any {
        return [Tags.ts.tag: ts.description]
    }
    public var ts: HighPrecisionTime

    public init(_ hpt: HighPrecisionTime) {
        self.ts = hpt
    }

    /// Creates a new TimeV instance considering the `Date` provided.
    /// - Note: The timestamp created will only have seconds precision.
    /// If you need more granularity, consider using a `HighPrecisionTime` instance.
    public init(date: Date) {
        self.ts = HighPrecisionTime(date: date)
    }

    init?(from string: String) {
        guard let time = HighPrecisionTime(parse: string) else { return nil}
        self.ts = time
    }
    public var description: String {
        return ts.description
    }

}

/// Represents a date returned by the server.
/// [Reference](https://fauna.com/documentation/queries#values-special_types).
public struct DateV: Value {
    public static func decode(mj: MJ) -> Any {
        guard let dv = DateV(from: mj.stringValue) else {
            return MJ.nullString
        }
        return dv
    }
    public func encode() -> Any {
        return [Tags.date.tag: DateV.formatter.string(for: date)]
    }
    private static let formatter = ISO8601Formatter(with: "yyyy-MM-dd")

    public var date: Date
    public var description: String {
        return date.description
    }

    public init(_ date: Date) {
        self.date = date
    }

    init?(from string: String) {
        guard let time = DateV.formatter.parse(from: string) else { return nil }
        self.date = time
    }
}
/// Represents a Ref returned by the server.
/// [Reference](https://fauna.com/documentation/queries#values-special_types).
public final class RefV: Value {
    public static func decode(mj: MJ) -> Any {
        return RefV(mj[F.id].stringValue, clazz: mj[F.class].optional(), database: mj[F.database].optional())
    }
    public func encode() -> Any {
        guard let nc = Native(rawValue: id) else {
            var d = [F.id: id as Any]
            d[F.class] = clazz?.encode()
            d[F.database] = database?.encode()
            let mj = [Tags.ref.tag: d] as MJ
            dp(mj)
            return mj.jsonObject
        }
        return nc.ref().encode()
    }
    public let id: String
    public let clazz: RefV?
    public let database: RefV?
    public init(_ id: String, clazz: RefV? = nil, database: RefV? = nil) {
        self.id = id
        self.clazz = clazz
        self.database = database
    }

    public var description: String {
        let cls = clazz.map { ", class=\($0)" } ?? ""
        let db = database.map { ", database=\($0)" } ?? ""
        return "RefV(id=\(id)\(cls)\(db))"
    }
}

extension RefV: Equatable {
    public static func == (left: RefV, right: RefV) -> Bool {
        return left.id == right.id &&
            left.clazz == right.clazz &&
            left.database == right.database
    }
}

public enum Native: String {
    case classes, indexes, databases, keys, functions, tokens, credentials
    func ref() -> RefV {
        switch self {
        case .classes:
            return RefV("classes")
        case .indexes:
            return RefV("indexes")
        case .databases:
            return RefV("databases")
        case .keys:
            return RefV("keys")
        case .functions:
            return RefV("functions")
        case .tokens:
            return RefV("tokens")
        case .credentials:
            return RefV("credentials")
        }
    }
}

/// Represents a binary blob returned by the server.
/// [Reference](https://fauna.com/documentation/queries#values-special_types).
public struct BytesV: Value {
    public static func decode(mj: MJ) -> Any {
        let base64 = mj.stringValue
        guard let data = Data(base64Encoded: base64) else {
            return MJ.nullString
        }
        return BytesV(data)
    }
    public func encode() -> Any {
        return [Tags.bytes.tag: bytes.base64EncodedString()]
    }
    public let bytes: Data
    public var description: String {
        return "\"\(bytes.base64EncodedString())\""
    }
    public init(_ bytes: Data) {
        self.bytes = bytes
    }
    public init(fromArray bytes: [UInt8]) {
        self.bytes = Data(bytes)
    }
}

/// Represents a SetRef returned by the server.
/// [Reference](https://fauna.com/documentation/queries#values-special_types).

public protocol ComplexValue: Value, MJConvertible {
    var seTag: String {get}
    var mj: MJ {get set}
    init(mj: MJ)
}

extension ComplexValue {
    public static func decode(mj: MJ) -> Any {
        return Self.init(mj: mj)
    }
    public func encode() -> Any {
        return [seTag: faunaEncode(mj.jsonObject)]
    }
    public var description: String {
        return "\(type(of: self))(\(mj))"
    }
}

public struct SetV: ComplexValue {
    public var seTag: String {
        return Tags.set.tag
    }
    public var mj: MJ
    public init(mj: MJ) {
        self.mj = mj
    }
}

/// Represents an object returned by the server.
/// [Reference](https://fauna.com/documentation/queries#values).
public struct ObjV: ComplexValue {
    public var seTag: String {
        return Tags.object
    }
    public var mj: MJ
    public init(mj: MJ) {
        self.mj = mj
    }
}

/// Represents a query value in the FaunaDB query language.
/// [Reference](https://fauna.com/documentation/queries#values-special_types).
public struct QueryV: ComplexValue {
    public var seTag: String {
        return Tags.query.tag
    }
    public var mj: MJ
    public init(mj: MJ) {
        self.mj = mj
    }
}
