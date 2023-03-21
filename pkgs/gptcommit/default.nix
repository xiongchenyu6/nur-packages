{ stdenv, lib, rustPlatform, pkg-config, nix-update-script, openssl, source }:

rustPlatform.buildRustPackage (source.gptcommit // {
  cargoSha256 = "sha256-kgcrJQYnwK34aROUkchAnITS305QgpttJ2giKrE5S0Y=";

  nativeBuildInputs = [ pkg-config ];

  buildInputs = lib.optionals stdenv.isLinux [ openssl ];

  passthru = { updateScript = nix-update-script { }; };

  doCheck = false;

  meta = with lib; {
    description =
      "A git prepare-commit-msg hook for authoring commit messages with GPT-3. ";
    homepage = "https://github.com/zurawiki/gptcommit";
    license = with licenses; [ asl20 ];
    maintainers = with maintainers; [ happysalada ];
    platforms = with platforms; all;
  };
})
