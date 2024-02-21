# NixOS RISC-V
An ongoing effort porting NixOS to the RISC-V architecture through cross compilation

## Supported Boards

### VisionFive 2

#### Build
```bash
nix build .#hydraJobs.visionfive2
```

May have to change
```
hardware.deviceTree.name = "starfive/jh7110-starfive-visionfive-2-v1.3b.dtb";
```
as appropriate if your board is v1.2a

#### Info
Prebuilt image is available at https://hydra.nichi.co/job/nixos/riscv/visionfive2/latest

The resulting image includes u-boot, see [VisionFive 2 Single Board Computer Quick Start Guide](https://doc.rvspace.org/VisionFive2/Quick_Start_Guide/VisionFive2_SDK_QSG/boot_mode_settings.html) for instructions on booting from sdcard.

#### Known Issues
Ethernet ports do work to a certain extent, but far from approaching the rated 1Gbps, could be due to misconfigurations in the device tree.

Drivers for PCIe, USB and GPU (and many other peripherals) are not included yet.

### Milk V Duo (original 64M version)

#### Build

```bash
nix build .#hydraJobs.duo
```

#### Info

`XXX TODO`

### Milk V Duo 256M

#### Build
```bash
nix build .#hydraJobs.duo-256
```

#### Info

Native ethernet is untested. GPIO is untested.  RNDIS works.

You will be able to ssh to the Duo 256M after configuring a an Ethernet
connection that uses the RNDIS interface enabled by plugging the Duo in to your
host system.  Unlike the Milk V vendor buildroot image, DHCP is not used by the
NixOS image to manage the addresses of the Duo or the host. Instead, you will
need to configure the host to use a static IP address.

When you plug the Duo in via USB C, an `ifconfig` of the host it's connected
will reveal a new Ethernet interface on your host machine something like
`enp0s20f0u7u2`.  This is the interface that must be configured in order to
connect to the Duo. Under KDE, I used the Network Settings "Connections" pane
to create a new "Wired Ethernet" connection with the following settings:

```
"Wired"
  Restrict to device: enp0s20f0u7u2

IPv4:
  Method: Manual
  Address/Netmask/Gateway: 192.168.58.1/255.255.255.0/0.0.0.0
```

You will likely also need to restrict any existing Ethernet interfaces in
their "Wired" tabs to the real Ethernet interface on your host machine to
prevent the system from trying to use the RNDIS interface to obtain its normal
DHCP settings. For me, I had to add "Restrict to Device: enp1s0" in my primary
wired Ethernet connection settings.

After applying those settings, you should be able to connect to the Duo via
"ssh root@192.168.58.2".  The password is "milkv".

NB: it takes about 30 seconds after the Duo boots for the ssh server to start
after the interface has been recognized by the host, be patient.

You can give the Duo access to the larger internet by setting up
NAT/masquerading on the host.  You can do the following on the host the Duo is
connected to set up NAT.

```bash
echo 1 > /proc/sys/net/ipv4/ip_forward"
```

Or (in NixOS) declaratively:

```nix
   boot.kernel.sysctl = { "net.ipv4.conf.all.forwarding" = true; };
```

Then execute a variant of the following nftables script which enables the host
to route packets on behalf of the Duo via NAT/masquerade to and from the
internet.  Change the interface names as necessary.  Once executed, the Duo
will be able to communicate with the outside world, using the host as a
router.

```
#!/run/current-system/sw/bin/nft -f

# enp1s0 is my ethernet interface, connected to my Internet router.
# enp0s20f0u7u2 is the RNDIS interface created by attaching the Duo to
# the host via USB.

table ip duo_table { chain duo_nat { type nat hook postrouting priority 0;
       policy accept; oifname "enp1s0" masquerade
       }

      chain duo_forward {
               type filter hook forward priority 0; policy accept;
               iifname "enp0s20f0u7u2" oifname "enp1s0" accept
       }
}
```

This can be canonized declaratively in your host's NixOS config via:

```nix
  networking.nftables = {
    enable = true;
    ruleset = ''
      table ip duo_table {
        chain duo_nat {
          type nat hook postrouting priority filter; policy accept;
          oifname "enp1s0" masquerade
        }

        chain duo_forward {
          type filter hook forward priority filter; policy accept;
          iifname "enp0s20f0u7u2" oifname "enp1s0" accept
        }
      }
  '';
  };
```

On a NixOS host machine, you do *not* need "networking.firewall.enable = true;"
for these masquerade and forwarding chains to work but
"networking.nftables.enable = true;" makes the nft command available.

NB: In order for the Duo to connect to the internet, by default, without
changes to this Nix file, the host must be contactable via the IP address
`192.168.58.1` because this Nix file hardcodes that IP address as the Duo's
default gateway.


## Acknowledgement
This work is sponsored by PLCT Lab.
