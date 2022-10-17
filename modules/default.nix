{
  # Add your NixOS modules here
  #
  bttc = import ./bttc;
  unit-status-telegram = import ./unit-status-telegram;
  tat-agent = import ./tat-agent;
  oci-arm-host-capacity = import ./oci-arm-host-capacity;
}
