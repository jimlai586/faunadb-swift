import Foundation

// MARK: Values

/// Ref creates a new RefV value with the ID provided.
///
/// [Reference](https://fauna.com/documentation/queries#values-special_types).
public func ref(cls: RefV, id: String) -> MJ {
    return [F.ref: cls, F.id: id]
}

public func ref(id: String) -> MJ {
    return [Tags.ref.tag: id]
}

public func createClass(_ name: String) -> MJ {
    return [F.create_class: ObjV(mj: [F.name: name])]
}

public func create(_ classRef: MJ, _ obj: ObjV) -> MJ {
    return [F.create: classRef, F.params: obj]
}

public func dataObj(_ data: MJ) -> ObjV {
    return ObjV(mj: [F.data: ObjV(mj: data)])
}

public func clazz(_ name: String) -> MJ {
    return [F.class: name]
}
