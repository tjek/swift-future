# 🕰 Future

![Swift 5](https://github.com/tjek/swift-future/workflows/Swift/badge.svg)
[![Cocoapods](https://img.shields.io/cocoapods/v/Tjek-Future.svg)](http://cocoapods.org/pods/Tjek-Future)
[![License](http://img.shields.io/badge/license-MIT-brightgreen.svg)](LICENSE.md)

A `Future` just represents some 'work', that _may_ take some time (or not).

The power of Futures is that they can be chained togther, producing a single Future object that contains all the work of all the component Futures. 

Furthermore, the work of this Future isnt done until you actually `run` the future.

Here is an example of the kinds of complex logic possible with Futures:

```swift
struct User: Codable {
    var id: String
    var name: String
}

struct Food: Codable {
    var type: String
    var tastiness: Int
}
    
// Make a future that loads a user value from the file "User.json"
let loadFileUser: FutureResult<User> = Bundle.main
    .loadData(forResource: "User.json")
    .flatMapResult(User.decodeJSON(from:))

// Make a future that loads food value from the json string
let loadStringFood: FutureResult<Food> = Future<String>
    .init(value: #"{ "type": "curry", "tastiness": 1000 }"#)
    .map({ $0.data(using: .utf8)! })
    .flatMap(Food.decodeFutureJSON(from:))

// Make a future that loads another user value from a network request
let loadNetworkUser: FutureResult<User> = URLSession.shared
    .dataTaskFutureResult(with: URLRequest(url: URL(string: "https://foo.bar")!))
    .mapResult({ $0.data })
    .flatMapResult(User.decodeFutureJSON(from:))
    
// zip the 3 futures together and, if all successful, convert the response into a string.
let combinedFuture = zipResult3With(
    loadStringFood,
    loadFileUser,
    loadNetworkUser
) { (food: $0, user: $1, networkUser: $2) }
    .mapResult({
        "\($0.user.name) likes \($0.food.type) x\($0.food.tastiness)... networkUser: '\($0.networkUser.name)'"
    })
    
// once it is finally run, print the result
combinedFuture.run { result in
    print(result)
} 
```


Future areas to improve:

- **FutureOptional** - add tests and functionality similar to `Future<Result<_,_>>`
- **Cancellable** - Somehow allow Futures to provide cancellable tokens.
- **More utility extensions** 
	- `UIImageView().setImage(Future<UIImage?>)`
	- `CLGeocoder().geocode(...) -> FutureResult<[CLPlacemark]>`
	- Maybe `CLLocationManager`... how to handle delegates? Future's arent the right thing for streams of events, I think. But sometimes we need 1-hit delegate calls.
