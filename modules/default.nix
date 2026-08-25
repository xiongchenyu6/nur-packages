{
  falcon-sensor = import ./falcon-sensor;
  hashtopolis-server = import ./hashtopolis-server;
  hashtopolis-agent = import ./hashtopolis-agent;
  casdoor = import ./casdoor;
  fleet = import ./fleet.nix;
  gotrue-supabase = import ./gotrue-supabase;
  cc-switch = import ./cc-switch;
  codexpro = import ./codexpro;
  sub2api = import ./sub2api;
  dify = import ./dify;
  supabase-realtime = import ./supabase-realtime;
  dnf-server = import ./dnf-server;
  freqtrade-ohlc-sync = import ./freqtrade-ohlc-sync;
  nautilus-accumulator = import ./nautilus-accumulator;
  nautilus-trend = import ./nautilus-trend;
  nautilus-signal = import ./nautilus-signal;
  nautilus-equity-trend = import ./nautilus-equity-trend;
  quant-collectors = import ./quant-collectors;
}
