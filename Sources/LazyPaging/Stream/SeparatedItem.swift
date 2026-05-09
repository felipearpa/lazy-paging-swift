import Foundation

/// The output type of ``PagingData/insertSeparators(_:)`` — each row is
/// either a loaded item or a separator injected between items. Requires
/// both sides to share the same `ID` type so the value can be
/// `Identifiable` for `ForEach` diffing.
public enum SeparatedItem<Item: Sendable, Separator: Sendable>: Sendable {
    case item(Item)
    case separator(Separator)
}

extension SeparatedItem: Equatable where Item: Equatable, Separator: Equatable {}
extension SeparatedItem: Hashable where Item: Hashable, Separator: Hashable {}

extension SeparatedItem: Identifiable where
    Item: Identifiable,
    Separator: Identifiable,
    Item.ID == Separator.ID
{
    public var id: Item.ID {
        switch self {
        case .item(let item): return item.id
        case .separator(let separator): return separator.id
        }
    }
}
