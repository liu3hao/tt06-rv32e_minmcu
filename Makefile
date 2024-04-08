create-user-config:
	python tt/tt_tool.py --create-user-config

flow:
	python tt/tt_tool.py --create-user-config
	docker run --rm -v $(OPENLANE_ROOT):/openlane -v $(OPENLANE_PDK_ROOT):$(OPENLANE_PDK_ROOT) -v ${CURDIR}:/work -e PDK=sky130A -e PDK_ROOT=$(OPENLANE_PDK_ROOT) efabless/openlane:2023.11.23 /bin/bash -c "./flow.tcl -design /work/src -run_path /work/runs -overwrite -tag wokwi"
	python tt/tt_tool.py --print-cell-category > cell_usage.md
	python tt/tt_tool.py --print-cell-summary > cell_summary.md

synth:
	rm -rf runs/wokwi_syn
	docker run --rm -v $(OPENLANE_ROOT):/openlane -v $(OPENLANE_PDK_ROOT):$(OPENLANE_PDK_ROOT) -v ${CURDIR}:/work -e PDK=sky130A -e PDK_ROOT=$(OPENLANE_PDK_ROOT) efabless/openlane:2023.11.23 /bin/bash -c "./flow2.tcl -design /work/src -run_path /work/runs -overwrite -tag wokwi_syn"
	@sleep 1
	sed -n '/71. Printing statistics./,/Chip area for module/p' runs/wokwi_syn/logs/synthesis/1-synthesis.log
	sed -n '/71. Printing statistics./,/Number of cells:/p' runs/wokwi_syn/logs/synthesis/1-synthesis.log

# interactive:
# 	docker run --rm -it -v $(OPENLANE_ROOT):/openlane -v $(OPENLANE_PDK_ROOT):$(OPENLANE_PDK_ROOT) -v ${CURDIR}:/work -e PDK=sky130A -e PDK_ROOT=$(OPENLANE_PDK_ROOT) efabless/openlane:2023.11.23 /bin/bash -c "./flow.tcl -interactive"

yosys_dump:
	yosys -p "read_verilog -sv src/$(file)" \
		  -p "opt" \
		  -p "proc" \
		  -p "opt" \
		  -p "techmap" \
		  -p "opt" \
		  -p "show -prefix src/$(file) -format dot -colors 2 -signed -width" \
		  -p "tee -o src/$(file).log stat -width"
	dot -Ksfdp -o$(file).svg -Tsvg src/$(file).dot

cpu_imm:
	xdot $(PWD)/runs/wokwi_syn/results/synthesis/tt_um_rv32e_cpu.imm.v.dot

hierarchy:
	xdot $(PWD)/runs/wokwi_syn/tmp/synthesis/hierarchy.dot
