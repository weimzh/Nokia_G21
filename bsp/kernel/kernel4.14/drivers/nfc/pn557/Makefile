#
# Makefile for pn533
#

obj-y     += nfc.o pn8xt.o

ccflags-$(CONFIG_NFC_DEBUG) := -DDEBUG
ccflags-$(CONFIG_NXP_NFC_SN1XX)  := -DNFC_PLATFORM=sn1xx
ccflags-y  := -DNFC_PLATFORM=pn8xt

