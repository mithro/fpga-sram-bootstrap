The basic priciple is to store the SRAM contents into the comparatively slow serial flash then copy them at power on into the SRAM before handing over control to the user.

This is specific to the Papilio Plus FPGA board, using a SST25VF040B for FLASH and a IS61WV25616BLL for SRAM but may be adapted to other boards.