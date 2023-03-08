{ python3, source, makeWrapper, epc, readline, ... }:
let
  inherit (python3.pkgs) buildPythonPackage;
  inherit (python3.pkgs)
    flask prompt-toolkit playwright sqlalchemy rich names openai tiktoken;
in buildPythonPackage (source.chatgpt-wrapper // {
  buildInputs = [ makeWrapper ];
  propagatedNativeBuildInputs = [ readline ];
  postInstall = ''
    wrapProgram $out/bin/chatgpt --set PLAYWRIGHT_BROWSERS_PATH ${playwright.browsers}
  '';
  propagatedBuildInputs = [
    flask
    sqlalchemy
    prompt-toolkit
    playwright
    rich
    epc
    names
    openai
    tiktoken
  ];
  doCheck = false;
})
