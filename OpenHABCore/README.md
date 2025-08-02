# OpenHABCore

This package contains code shared between the main openHAB app and its extensions.

1. Invoke the (CLI manually)[https://swiftpackageindex.com/apple/swift-openapi-generator/1.10.1/documentation/swift-openapi-generator/manually-invoking-the-generator-cli]
This is a work around to use openAPI in a package.

1. Clone the generator package locally with git clone https://github.com/apple/swift-openapi-generator

1. Run  ```cd swift-openapi-generator  && swift run swift-openapi-generator generate --config ../Sources/OpenHABCore/openapi/openapi-generator-config.yml --output-directory ../Sources/OpenHABCore/GeneratedSources/openapi ../Sources/OpenHABCore/openapi/openapi.json```

