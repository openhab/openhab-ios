# OpenHABCore

This package contains code shared between the main openHAB app and its extensions.

1. If you replace `Sources/OpenHABCore/openapi/openapi.json` with a newer spec from openHAB, re-apply the patch at the repository root afterwards: `git apply openapi-source.patch` (run from the repository root).
The patch adds the `X-OpenHAB-Source` header and the `source` query parameter to the item command endpoints, which the published spec does not describe yet. Delete `openapi-source.patch` and this step once the upstream spec includes them.

1. Invoke the (CLI manually)[https://swiftpackageindex.com/apple/swift-openapi-generator/1.12.2/documentation/swift-openapi-generator/manually-invoking-the-generator-cli]
This is a work around to use openAPI in a package.

1. Clone the generator package locally with git clone https://github.com/apple/swift-openapi-generator

1. Run  ```cd swift-openapi-generator  && swift run swift-openapi-generator generate --config ../Sources/OpenHABCore/openapi/openapi-generator-config.yml --output-directory ../Sources/OpenHABCore/GeneratedSources/openapi ../Sources/OpenHABCore/openapi/openapi.json```

