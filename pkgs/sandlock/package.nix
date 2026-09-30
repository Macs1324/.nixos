{
  lib,
  rustPlatform,
  pkg-config,
  linux-pam,
  wayland,
  libxkbcommon,
  vulkan-loader,
  libGL,
}:
rustPlatform.buildRustPackage {
  pname = "sandlock";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [./Cargo.toml ./Cargo.lock ./build.rs ./src];
  };
  cargoLock.lockFile = ./Cargo.lock;

  nativeBuildInputs = [pkg-config];
  buildInputs = [linux-pam wayland libxkbcommon];

  # Loaded with dlopen at runtime: the Vulkan loader (wgpu) and
  # libwayland-client (wayland-sys).
  postFixup = ''
    patchelf --add-rpath ${lib.makeLibraryPath [vulkan-loader libGL wayland]} $out/bin/sandlock
  '';

  meta = {
    description = "Wayland screen locker: the desktop dissolves into a storm of its own pixels";
    mainProgram = "sandlock";
    platforms = lib.platforms.linux;
  };
}
