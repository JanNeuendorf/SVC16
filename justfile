release_spec semver:
    -mkdir {{justfile_dir()}}/releases
    typst compile specification/specification.typ {{justfile_dir()}}/releases/specification_{{semver}}.pdf --input semver={{semver}}


