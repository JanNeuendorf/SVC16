semver:="2.0"
release_spec:
    -mkdir {{justfile_dir()}}/releases
    typst compile specification/specification.typ {{justfile_dir()}}/releases/specification_{{semver}}.pdf --input semver={{semver}}


compile_emulator:
    odin build emulator -o:aggressive -target:linux_amd64 --out:releases/svc16_{{semver}}_linux_amd64

