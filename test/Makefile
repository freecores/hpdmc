SOURCES_DDRIO=tb_ddrio.v ../rtl/hpdmc_ddrio.v
SOURCES_MODEL=tb_model.v ddr.v
SOURCES_HPDMC=tb_hpdmc.v ddr.v ../rtl/hpdmc_conf.v ../rtl/hpdmc_ddrio.v ../rtl/hpdmc_scheduler.v ../rtl/hpdmc.v

all: hpdmc

ddrio: $(SOURCES_MODEL)
	cver $(SOURCES_DDRIO)

model: $(SOURCES_MODEL)
	cver $(SOURCES_MODEL)

hpdmc: $(SOURCES)
	cver $(SOURCES_HPDMC)

clean:
	rm -f verilog.log ddrio.vcd hpdmc.vcd

.PHONY: clean 
