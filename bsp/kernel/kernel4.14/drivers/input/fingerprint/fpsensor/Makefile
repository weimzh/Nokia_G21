# Copyright (C) Microarray
# MicroArray Fprint Driver Code
# MAKEFILE
# Date: 2017-07-21
# Version: for_intel_v4.0.06
# Author: guq
# Contact: guq@chipone.com.cn

ccflags-y += -DDEBUG

obj-m := chipone_fp.o
chipone_fp-objs := fpsensor_spi.o

.PHONY:modules
modules:
	make $(BSP_MAKE_EXTRA_ARGS) ARCH=$(BSP_BOARD_ARCH) CROSS_COMPILE=$(BSP_KERNEL_CROSS_COMPILE) -C $(BSP_KERNEL_PATH) O=$(BSP_KERNEL_OUT) M=`pwd` $@

modules_install:
	make $(BSP_MAKE_EXTRA_ARGS) ARCH=$(BSP_BOARD_ARCH) CROSS_COMPILE=$(BSP_KERNEL_CROSS_COMPILE) -C $(BSP_KERNEL_PATH) O=$(BSP_KERNEL_OUT) M=`pwd` INSTALL_MOD_PATH=$(BSP_MODULES_OUT) $@

clean:
	make -C $(BSP_KERNEL_PATH) O=$(BSP_KERNEL_OUT) M=`pwd` $@
