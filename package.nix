{ lib, stdenv, toolchain, partuuid}:

assert lib.assertMsg (builtins.match "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$" partuuid != null) 
  "partuuid must be a valid UUID string, e.g. '123e4567-e89b-12d3-a456-426614174000', got: '${partuuid}'";

let
  cargoTarget = "x86_64-unknown-uefi";
  vendor = stdenv.mkDerivation {
    pname = "winchain-cargo-vendor";
    version = "0";
    src = ./.;
    nativeBuildInputs = [ toolchain ];

    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "sha256-iJi6q2smT06R+WN8OjC0ximq9KFpgItcgDhWXhAQTbc=";

    CARGO_HOME = "$TMPDIR/cargo-home";
    HOME = "$TMPDIR/home";
    CARGO_REGISTRIES_CRATES_IO_PROTOCOL = "sparse";

    buildPhase = ''
      mkdir -p "$CARGO_HOME" "$HOME" "$out"
      cargo vendor --versioned-dirs "$out"
    '';
    installPhase = "true";
  };
in 
stdenv.mkDerivation {
  pname = "winchain";
  version = "0.1.0";

  src = ./.;
  nativeBuildInputs = [ toolchain ];

  WINCHAIN_BOOT_PARTITION_GUID = partuuid;

  # winchain is guid-pinned at compile time, so always build locally
  allowSubstitutes = false;
  preferLocalBuild = true;
  dontDistribute = true;

  CARGO_BUILD_TARGET = cargoTarget;
  CARGO_NET_OFFLINE = "true";
  CARGO_HOME = "$TMPDIR/cargo-home";

  buildPhase = ''
    mkdir -p .cargo
    cat > .cargo/config.toml <<'EOF'
    [source.crates-io]
    replace-with = "vendored-sources"

    [source.vendored-sources]
    directory = "vendor"
    EOF

    ln -s ${vendor} vendor

    cargo build --release --frozen --offline --target "$CARGO_BUILD_TARGET"
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp target/x86_64-unknown-uefi/release/winchain.efi $out/bin/winchain.efi
  '';

  meta = {
    description = "UEFI chain-loader for systemd-boot that boots bootmgfw.efi from a specific GPT partition pinned at compile-time";
    license = lib.licenses.mit;
    platform = [ "x86_64-linux" ];
  };
}
