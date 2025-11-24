# Smart wrapper for falcon-sensor that tries multiple approaches
{ callPackage
, lib
, stdenv
, builtins
, ...
}@args:

let
  # Check environment variables
  userProvidedUrl = builtins.getEnv "FALCON_SENSOR_URL";
  useStub = builtins.getEnv "FALCON_SENSOR_STUB" == "1";
  tryDownload = builtins.getEnv "FALCON_SENSOR_DOWNLOAD" == "1";

in
if useStub then
  # Explicitly requested stub for testing
  callPackage ./package-stub.nix { }
else if userProvidedUrl != "" || tryDownload then
  # User provided a URL or wants to try downloading
  callPackage ./package-with-url.nix args
else
  # Default: try the manual approach (requireFile)
  # This will fail with instructions if .deb not in store
  callPackage ./package.nix args