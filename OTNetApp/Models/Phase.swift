import Foundation

enum Phase<T> {
    case loading
    case loaded(T)
    case empty
    case failed(Error)
}
