#!/bin/bash
expname="exp1"
../../NetLogo\ 6.1.1/netlogo-headless.sh --model PIE.nlogo --experiment $expname --table table-output.csv --spreadsheet spreadsheet-output.csv > $expname.log & 
#expname="exp2"
#../../NetLogo\ 6.1.1/netlogo-headless.sh --model CAN.nlogo --experiment $expname --spreadsheet $expname.csv > $expname.log &
