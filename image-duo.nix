{ runCommand
, dtc
, ubootTools
, kernel
, writeText
}:

let
  its = writeText "cv180x.its" ''
    /dts-v1/;

    / {
      description = "Various kernels, ramdisks and FDT blobs";
      #address-cells = <2>;

      images {
        kernel-1 {
          description = "cvitek kernel";
          type = "kernel";
          data = /incbin/("${kernel}/Image");
          arch = "riscv";
          os = "linux";
          compression = "none";
          load = <0x00 0x80200000>;
          entry = <0x00 0x80200000>;
          hash-2 {
            algo = "crc32";
          };
        };

        /*
        ramdisk-1 {
          type = "ramdisk";
          data = /incbin/("<FIXME>");
          arch = "riscv";
          os = "linux";
          compression = "gzip";
          load = <00000000>;
          entry = <00000000>;
        };
        */

        fdt-1 {
          description = "cvitek device tree - cv1800b_milkv_duo_sd";
          type = "flat_dt";
          data = /incbin/("${kernel}/dtbs/sophgo/cv1800b-milkv-duo.dtb");
          arch = "riscv";
          compression = "none";
          hash-1 {
            algo = "sha256";
          };
        };
      };

      configurations {
        default = "config-1";

        config-1 {
          description = "boot cvitek system with board cv1800b_milkv_duo_sd";
          kernel = "kernel-1";
          /*
          ramdisk = "ramdisk-1";
          */
          fdt = "fdt-1";
        };
      };
    };
  '';
in
runCommand "boot.sd"
{
  nativeBuildInputs = [ ubootTools dtc ];
} ''
  mkimage -f ${its} "$out" 
''
