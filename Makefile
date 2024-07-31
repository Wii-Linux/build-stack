.PHONY: all download

all: download

download: sd_files/bootmii/armboot.bin sd_files/gumboot/gumboot.elf sd_files/bootmii/gui.elf sd_files/gumboot/LICENSE sd_files/gumboot/README

sd_files/%:
	mkdir -p $(@D)
	wget https://wii-linux.org/archive/gumboot/$(subst sd_files/,,$(subst bootmii/,,$(subst gumboot/,,$@))) -O $@
