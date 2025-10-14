{ lib, rustPlatform, toolchain, partuuid}:

assert lib.assertMsg (builtins.match "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$" partuuid != null) 
  "partuuid must be a valid UUID string, e.g. '123e4567-e89b-12d3-a456-426614174000', got: '${partuuid}'";

rustPlatform.buildRustPackage {
  pname = "winchain";
  version = "0.1.0";

  src = ./.;
  cargoLock.lockFile = ./Cargo.lock;

  cargoBuildOptions = [ "--release" "--target" "x86_64-unknown-uefi" ];
  nativeBuildInputs = [ toolchain ];

  # winchain is guid-pinned at compile time, so always build locally
  allowSubstitutes = false;
  preferLocalBuild = true;
  dontDistribute = true;
  WINCHAIN_PARTUUID = partuuid;

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
