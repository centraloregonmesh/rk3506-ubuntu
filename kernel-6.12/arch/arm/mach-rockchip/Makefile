# SPDX-License-Identifier: GPL-2.0-only
CFLAGS_platsmp.o := -march=armv7-a

obj-$(CONFIG_ARCH_ROCKCHIP) += rockchip.o

ifdef CONFIG_PM_SLEEP
obj-$(CONFIG_CPU_RK3288) += pm.o sleep.o
endif

obj-$(CONFIG_SMP) += headsmp.o platsmp.o
