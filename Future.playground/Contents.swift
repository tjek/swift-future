import PlaygroundSupport
import Foundation
import Future

struct User: Codable {
    var id: String
    var name: String
}
struct Food: Codable {
    var type: String
    var tastiness: Int
}

let loadFileUser: FutureResult<User> = Future
    .init(work: {
        .success(User(id: "foo", name: "bar"))
    })
//    // imagine it's a big file, so load & decode on a global queue.
//    .async(
//        Bundle.main.loadData(forResource: "User.json")
//            .flatMapResult(User.decodeJSON(from:)),
//
//        on: .global(),
//        completesOn: .global()
//    )


let loadStringFood: FutureResult<Food> = Future<String>
    .init(value: #"{ "type": "curry", "tastiness": 1000 }"#)
    .map({ $0.data(using: .utf8)! })
    .flatMap(Food.decodeJSON(from:))

let loadNetworkUser: FutureResult<User> = URLSession.shared
    .dataTaskResult(with: URLRequest(url: URL(string: "https://foo.bar")!))
    .mapResult({ $0.data })
    .flatMapResult(User.decodeJSON(from:))

let combinedFuture = zipResult3With(
    loadStringFood,
    loadFileUser,
    loadNetworkUser
) { (food: $0, user: $1, networkUser: $2) }
    .mapResult({
        "\($0.user.name) likes \($0.food.type) x\($0.food.tastiness)... networkUser: '\($0.networkUser.name)'"
    })

//
//combinedFuture.run { result in
//    print(result)
//}
//enum TestError: Error { case foo }
//let f = batchResult([
//    Future<Result<Int, TestError>>(work: { .failure(.foo) }),
//    Future<Result<Int, TestError>>(work: { .success(1) }),
//    Future<Result<Int, TestError>>(work: { .success(5) }),
//    ])
//    .map { try? $0.get() }
//
//f.run {
//    print($0)
//}
//
////    .run { (res: Result<[Int], Error>) in
//////        print(res)
////}

