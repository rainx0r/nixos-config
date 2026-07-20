{
  lib,
  fetchFromGitHub,
  openssl,
  pkg-config,
  rustPlatform,
  versionCheckHook,
}:

rustPlatform.buildRustPackage rec {
  pname = "clifton";
  version = "0.3.0";

  src = fetchFromGitHub {
    owner = "isambard-sc";
    repo = "clifton";
    rev = version;
    hash = "sha256-wNRcDjHUswpZ2FHkivkjn44TXon10eSlkCuVXrXcaCU=";
  };

  cargoHash = "sha256-p2Xtotlv+eckZiKloltpG5p6QyIKo6IGbMNrTxXcg8o=";

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ openssl ];

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  meta = {
    description = "SSH connection manager for Isambard";
    homepage = "https://github.com/isambard-sc/clifton";
    changelog = "https://github.com/isambard-sc/clifton/blob/${version}/CHANGELOG.md";
    license = lib.licenses.mit;
    mainProgram = "clifton";
    platforms = lib.platforms.unix;
  };
}
