Pod::Spec.new do |s|
  s.name = "ShopGun-Future"
  s.module_name = "Future"
  s.version = "0.3.0"
  s.summary = "🕰 A simple Swift Future type"

  s.description = <<-DESC
  Future is a lightweight type that expresses the idea of 'work'. 
  
  It is easily chainable, allowing you to build up complex Futures from smaller units of work.

  None of the work expressed in a Future is performed until the you explicitly run it.

  This library includes a number of extra wrappers around common operations, allowing them to easily chained with other futures.
  DESC

  s.homepage = "https://github.com/shopgun/swift-future"

  s.license = "MIT"

  s.authors = {
    "Laurie Hufford" => "lh@shopgun.com"
  }
  s.social_media_url = "https://twitter.com/shopgun"

  s.source = {
    :git => "https://github.com/shopgun/swift-future.git",
    :tag => s.version
  }

  s.swift_version = "5.0"

  s.ios.deployment_target = "8.0"
  s.osx.deployment_target = "10.10"
  s.tvos.deployment_target = "9.0"
  s.watchos.deployment_target = "2.0"

  s.source_files = "Sources", "Sources/**/*.swift"
end
