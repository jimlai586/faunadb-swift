import Foundation

public protocol JSONKey {
    var jkey: String {get}
}

public protocol MJConvertible {
    var mj: MagicJSON {get}
}

extension String: JSONKey {
    public var jkey: String {
        return self
    }
}

public protocol Initable {
    init()
}

extension Dictionary: MJConvertible where Key: JSONKey {
    public var mj: MagicJSON {
        return .dict(self.toStringKey())
    }
}

public protocol HashableJSONKey {
    func toStringKey() -> [String: Any]
}

extension Dictionary: HashableJSONKey where Key: JSONKey {
    public func toStringKey() -> [String: Any] {
        var d = [String: Any]()
        var nd: [Key: Any?] = self
        nd = nd.mapValues { v in
            guard let v = v else {
                return MJ.nullString
            }
            return v
        }
        for k in nd.keys {
            let v = nd[k]!
            let s = k.jkey
            switch v {
            case let u as [Key: Any?]:
                d[s] = u.toStringKey()
            default:
                d[s] = v
            }
        }
        return d
    }
}

public typealias MJ = MagicJSON
public enum MagicJSON {
    public static var nullString = "null"
    case arr([Any]), dict([String: Any]), empty, null, raw(Any)
}

extension MagicJSON: ExpressibleByArrayLiteral {
    public typealias ArrayLiteralElement = Any
    public init(arrayLiteral elements: ArrayLiteralElement...) {
        self.init(elements)
    }
}

extension MagicJSON: ExpressibleByStringLiteral {
    public typealias StringLiteralType = String
    public init(stringLiteral value: StringLiteralType) {
        self.init(value)
    }
}

extension MagicJSON: ExpressibleByIntegerLiteral {
    public typealias IntegerLiteralType = Int
    public init(integerLiteral value: IntegerLiteralType) {
        self.init(value)
    }
}

extension MagicJSON: ExpressibleByFloatLiteral {
    public typealias FloatLiteralType = Double
    public init(floatLiteral value: FloatLiteralType) {
        self.init(value)
    }
}

extension MagicJSON: ExpressibleByBooleanLiteral {
    public typealias BooleanLiteralType = Bool
    public init(booleanLiteral value: BooleanLiteralType) {
        self.init(value)
    }
}

public extension MagicJSON {
    init(_ jd: Any?) {
        guard let jd = jd else {
            self = .null
            return
        }
        switch jd {
        case let u as [Any]:
            self = .arr(u)
        case let u as [String: Any]:
            self = .dict(u.toStringKey())
        case let u as HashableJSONKey:
            self = .dict(u.toStringKey())
        case let u as MJ:
            self = u
        default:
            self = .raw(jd)
        }
    }
    init() {
        self = .empty
    }
    init(data: Data) {
        let json = try? JSONSerialization.jsonObject(with: data, options: [])
        self.init(json)
    }
    subscript<T>(_ k: T) -> MagicJSON where T: JSONKey {
        get {
            switch self {
            case .dict(let d):
                return MagicJSON(d[k.jkey])
            default:
                return MagicJSON.null
            }
        }
        set {
            switch self {
            case .dict(var d):
                if case .null = newValue {
                    d[k.jkey] = nil
                } else {
                    d[k.jkey] = newValue
                }
                self = .dict(d)
            default:
                break
            }
        }
    }
    subscript(_ idx: Int) -> MagicJSON {
        get {
            switch self {
            case .arr(let arr):
                guard 0 ..< arr.count ~= idx else {
                    return MagicJSON.null
                }
                return MagicJSON(arr[idx])
            default:
                return MagicJSON.null
            }
        }
        set {
            switch self {
            case .arr(var arr):
                guard 0 ..< arr.count ~= idx else {
                    return
                }
                arr[idx] = newValue
                self = .arr(arr)
            default:
                break
            }
        }
    }

    var stringValue: String {
        switch self {
        case .raw(let u):
            return u as? String ?? String(describing: u)
        default:
            return ""
        }
    }
    var intValue: Int {
        switch self {
        case .raw(let u):
            return u as? Int ?? 0
        default:
            return 0
        }
    }
    var floatValue: Float {
        switch self {
        case .raw(let u):
            return u as? Float ?? 0
        default:
            return 0
        }
    }
    var doubleValue: Double {
        switch self {
        case .raw(let u):
            return u as? Double ?? 0
        default:
            return 0
        }
    }
    var string: String? {
        switch self {
        case .raw(let u):
            return String(describing: u)
        default:
            return nil
        }
    }
    var int: Int? {
        switch self {
        case .raw(let u):
            return u as? Int
        default:
            return nil
        }
    }
    var float: Float? {
        switch self {
        case .raw(let u):
            return u as? Float
        default:
            return nil
        }
    }
    var double: Double? {
        switch self {
        case .raw(let u):
            return u as? Double
        default:
            return nil
        }
    }
    var arrayValue: [MagicJSON] {
        switch self {
        case .arr(let u):
            return u.map {MagicJSON($0)}
        default:
            return []
        }
    }
    var dictValue: [String: MagicJSON] {
        switch self {
        case .dict(let u):
            return u.mapValues {MagicJSON($0)}
        default:
            return [:]
        }
    }
    var data: Data? {
        return try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted])
    }
    var jsonObject: Any {
        switch self {
        case .arr(let a):
            return a.map { MJ($0).jsonObject}
        case .dict(let d):
            return d.mapValues {MJ($0).jsonObject}
        case .raw(let r):
            return r
        case .null:
            return MJ.nullString
        default:
            return [String: String]()
        }
    }
    func val<T>() -> T where T: Initable {
        switch self {
        case .raw(let v):
            return v as? T ?? T()
        default:
            return T()
        }
    }
    func optional<T>() -> T? {
        switch self {
        case .raw(let v):
            return v as? T
        default:
            return nil
        }
    }
}

extension MagicJSON: CustomStringConvertible {
    public var description: String {
        switch self {
        case .arr(let a):
            return String(describing: a)
        case .dict(let d):
            return String(describing: d)
        case .empty:
            return "empty"
        case .null:
            return MJ.nullString
        case .raw(let u):
            return String(describing: u)
        }
    }
}
