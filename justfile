semver:="2.1"
release_spec:
    -mkdir {{justfile_dir()}}/releases
    typst compile specification/specification.typ {{justfile_dir()}}/releases/specification_{{semver}}.pdf --input semver={{semver}}

# target linux: linux_amd64
# target mac: darwin_arm64

compile_emulator target:
    -mkdir {{justfile_dir()}}/releases
    odin build emulator -o:aggressive -target:{{target}} --out:releases/svc16_{{semver}}_{{target}}

