#!/usr/bin/env bash
set -e
# only exit with zero if all commands of the pipeline exit successfully
set -o pipefail

# Make sure to use project tooling
PATH="$(pwd)/tmp/bin:${PATH}"

for i in examples/jsonnet-snippets/*.jsonnet; do
    [ -f "$i" ] || break
    echo "Testing: ${i}"
    echo ""
    fileContent=$(<"$i")
    snippet="local kp = $fileContent;

$(<examples/jsonnet-build-snippet/build-snippet.jsonnet)"
    echo "${snippet}" > "test.jsonnet"
    echo "\`\`\`"
    echo "${snippet}"
    echo "\`\`\`"
    echo ""
    jsonnet -J vendor -m tmp/manifests "test.jsonnet" | xargs -I{} sh -c 'cat {} | gojsontoyaml | kubeval --ignore-missing-schemas; rm -f {}' -- {}
    rm -rf "test.jsonnet"
done

for i in examples/*.jsonnet; do
    [ -f "$i" ] || break
    echo "Testing: ${i}"
    echo ""
    echo "\`\`\`"
    cat "${i}"
    echo "\`\`\`"
    echo ""
    jsonnet -J vendor  -m tmp/manifests "${i}" | xargs -I{} sh -c 'cat {} | gojsontoyaml | kubeval --ignore-missing-schemas; rm -f {}' -- {}
done
