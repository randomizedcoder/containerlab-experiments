# constants -> containerlab topology attrset (rendered to arista-mpls.clab.yml).
c:
let
  # cEOS is launched with INTFTYPE=eth / MAPETH0=1, so containerlab must create
  # the data interfaces with kernel names ethN (which cEOS then maps to
  # EthernetN inside EOS, and its if-wait.sh only counts ethN-style names). The
  # device configs in configs.nix use the mapped EthernetN names, so the clab
  # endpoint name is just the config name with Ethernet -> eth.
  clabIf = builtins.replaceStrings [ "Ethernet" ] [ "eth" ];
in
{
  name = c.labName;

  mgmt = {
    network = c.mgmt.network;
    ipv4-subnet = c.mgmt.v4;
    ipv6-subnet = c.mgmt.v6;
  };

  topology = {
    defaults = {
      inherit (c) kind;
    };

    kinds.${c.kind}.image = c.image;

    nodes = {
      ce1.startup-config = "configs/ce1.cfg";
      pe1.startup-config = "configs/pe1.cfg";
      p.startup-config = "configs/p.cfg";
      pe2.startup-config = "configs/pe2.cfg";
      ce2.startup-config = "configs/ce2.cfg";
    };

    # Endpoints use the kernel ethN form (clabIf) of the EthernetN names in
    # configs.nix; cEOS maps ethN -> EthernetN inside EOS.
    links = [
      {
        endpoints = [
          "ce1:${clabIf c.edge.ce1_pe1.ce1If}"
          "pe1:${clabIf c.edge.ce1_pe1.pe1If}"
        ];
      }
      {
        endpoints = [
          "pe1:${clabIf c.core.pe1_p_a.pe1If}"
          "p:${clabIf c.core.pe1_p_a.pIf}"
        ];
      }
      {
        endpoints = [
          "pe1:${clabIf c.core.pe1_p_b.pe1If}"
          "p:${clabIf c.core.pe1_p_b.pIf}"
        ];
      }
      {
        endpoints = [
          "p:${clabIf c.core.p_pe2_a.pIf}"
          "pe2:${clabIf c.core.p_pe2_a.pe2If}"
        ];
      }
      {
        endpoints = [
          "p:${clabIf c.core.p_pe2_b.pIf}"
          "pe2:${clabIf c.core.p_pe2_b.pe2If}"
        ];
      }
      {
        endpoints = [
          "ce2:${clabIf c.edge.ce2_pe2.ce2If}"
          "pe2:${clabIf c.edge.ce2_pe2.pe2If}"
        ];
      }
    ];
  };
}
