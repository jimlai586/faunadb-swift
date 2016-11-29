import Foundation

internal let rootField = Field<Value>()

public struct Field<T> {

    fileprivate let path: Path
    fileprivate let codec: Codec

    public init(_ segments: Segment...) {
        self.init(path: segments)
    }

    public init(path segments: [Segment]) {
        self.init(path: Path(segments))
    }

    fileprivate init(path: Path, codec: Codec = defaultCodec) {
        self.path = path
        self.codec = codec
    }

    internal func get(from value: Value) throws -> T? {
        do {
            return try path.extract(value: value).flatMap(codec.decode)
        } catch let error {
            throw FieldError(path: path, error: error)
        }
    }

}

extension Field {

    public func at(_ segments: Segment...) -> Field {
        return at(path: segments)
    }

    public func at(path segments: [Segment]) -> Field {
        return at(field: Field(path: Path(segments), codec: codec))
    }

    public func at<A>(field: Field<A>) -> Field<A> {
        return Field<A>(path: self.path.subpath(field.path), codec: field.codec)
    }

    public func get<A>(asArrayOf field: Field<A>) -> Field<[A]> {
        return Field<[A]>(path: path, codec: CollectFields<A>(subpath: field.path, codec: field.codec))
    }

    public func get<A>(asDictionaryOf field: Field<A>) -> Field<[String: A]> {
        return Field<[String: A]>(path: path, codec: DictionaryFieds<A>(subpath: field.path, codec: field.codec))
    }

    public func map<A>(_ f: @escaping (T) throws -> A) -> Field<A> {
        return Field<A>(path: path, codec: MapFunction<T, A>(codec: codec, fn: f))
    }

    public func flatMap<A>(_ f: @escaping (T) throws -> A?) -> Field<A> {
        return Field<A>(path: path, codec: FlatMapFunction<T, A>(codec: codec, fn: f))
    }

}

public struct Fields {

    public static func at(_ segments: Segment...) -> Field<Value> {
        return at(path: segments)
    }

    public static func at(path segments: [Segment]) -> Field<Value> {
        return Field(path: segments)
    }

    public static func get<A>(asArrayOf field: Field<A>) -> Field<[A]> {
        return Field(path: Path.root, codec: CollectFields<A>(subpath: field.path, codec: field.codec))
    }

    public static func get<A>(asDictionaryOf field: Field<A>) -> Field<[String: A]> {
        return Field(path: Path.root, codec: DictionaryFieds<A>(subpath: field.path, codec: field.codec))
    }

    public static func map<A>(_ f: @escaping (Value) throws -> A) -> Field<A> {
        return Field(path: Path.root, codec: MapFunction<Value, A>(codec: defaultCodec, fn: f))
    }

    public static func flatMap<A>(_ f: @escaping (Value) throws -> A?) -> Field<A> {
        return Field<A>(path: Path.root, codec: FlatMapFunction<Value, A>(codec: defaultCodec, fn: f))
    }

}

fileprivate protocol Collect: Codec {
    associatedtype SegmentType: Segment
    associatedtype Element
    associatedtype Result

    var subpath: Path { get }
    var codec: Codec { get }

    func decompose(value: Value) throws -> [(SegmentType, Value)]
    func convert(collected: [(SegmentType, Element)]) -> Result
}

extension Collect {
    func decode<T>(value: Value) throws -> T? {
        if value is NullV {
            return try cast(convert(collected: []))
        }

        return try cast(
            convert(collected:
                try decompose(value: value).flatMap {
                    try collectField(segment: $0.0, value: $0.1)
                }
            )
        )
    }

    private func collectField(segment: SegmentType, value: Value) throws -> (SegmentType, Element)? {
        do {
            guard
                let extracted = try subpath.extract(value: value),
                let decoded: Element = try codec.decode(value: extracted)
                else { return nil }

            return (segment, decoded)

        } catch let error {
            let currentPath = Path([segment]).subpath(subpath)
            throw CollectError.failToCollect(currentPath, error)
        }
    }
}

fileprivate struct CollectFields<E>: Collect {
    typealias SegmentType = Int
    typealias Element = E
    typealias Result = [Element]

    let subpath: Path
    let codec: Codec

    func decompose(value: Value) throws -> [(Int, Value)] {
        guard let arr = value as? ArrayV else {
            throw CollectError.notCollectable("array", value)
        }

        return arr.value.enumerated().map { ($0.offset, $0.element) }
    }

    func convert(collected: [(Int, E)]) -> [E] {
        return collected.map { $0.1 }
    }
}

fileprivate struct DictionaryFieds<E>: Collect {
    typealias SegmentType = String
    typealias Element = E
    typealias Result = [String: E]

    let subpath: Path
    let codec: Codec

    func decompose(value: Value) throws -> [(String, Value)] {
        guard let obj = value as? ObjectV else {
            throw CollectError.notCollectable("object", value)
        }

        return obj.value.map { ($0.key, $0.value) }
    }

    func convert(collected: [(String, E)]) -> [String: E] {
        return Dictionary(pairs: collected)
    }
}

fileprivate struct MapFunction<IN, OUT>: Codec {
    let codec: Codec
    let fn: (IN) throws -> OUT

    func decode<T>(value: Value) throws -> T? {
        guard let input: IN = try codec.decode(value: value) else { return nil }
        return try cast(fn(input))
    }
}

fileprivate struct FlatMapFunction<IN, OUT>: Codec {
    let codec: Codec
    let fn: (IN) throws -> OUT?

    func decode<T>(value: Value) throws -> T? {
        guard
            let input: IN = try codec.decode(value: value),
            let output = try fn(input)
            else { return nil }

        return try cast(output)
    }
}

fileprivate struct FieldError: Error {
    let path: Path
    let error: Error
}

extension FieldError: CustomStringConvertible {
    var description: String {
        return "Error while extracting field at \(path): \(error)"
    }
}

fileprivate enum CollectError: Error {
    case notCollectable(String, Value)
    case failToCollect(Path, Error)
}

extension CollectError: CustomStringConvertible {
    var description: String {
        switch self {
        case .notCollectable(let desired, let actual):
            return "Can not collect fields from non \(desired) type \"\(type(of: actual))\""

        case .failToCollect(let subpath, let error):
            return "Error at field \(subpath): \(error)"
        }
    }
}
