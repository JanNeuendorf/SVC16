semver:=`cargo pkgid | cut -d "#" -f2| cut -d@ -f2`
release_spec:
    -mkdir {{justfile_dir()}}/releases
    typst compile specification/specification.typ {{justfile_dir()}}/releases/specification_{{semver}}.pdf --input semver={{semver}}


