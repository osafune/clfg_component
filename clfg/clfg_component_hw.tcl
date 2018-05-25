# ===================================================================
# TITLE : CameraLink BASE Configuration Frame-grabber
#
#   DEGISN : S.OSAFUNE (J-7SYSTEM WORKS LIMITED)
#   DATE   : 2018/05/17 -> 2018/05/25
#   MODIFY : 2018/05/25 17.1 beta
#
# ===================================================================
# *******************************************************************************
# The MIT License (MIT)
# Copyright (c) 2018 J-7SYSTEM WORKS LIMITED.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
# of the Software, and to permit persons to whom the Software is furnished to do
# so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# *******************************************************************************

# 
# request TCL package from ACDS 16.1
# 
package require -exact qsys 16.1


# 
# module clfg_component
# 
set_module_property NAME clfg_component
set_module_property DISPLAY_NAME "CameraLink Frame-grabber"
set_module_property DESCRIPTION "CameraLink BASE Configuration Simple Frame-grabber"
set_module_property AUTHOR "S.OSAFUNE / J-7SYSTEM WORKS LIMITED"
set_module_property VERSION 17.1
set_module_property INTERNAL false
set_module_property OPAQUE_ADDRESS_MAP true
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE false
set_module_property HIDE_FROM_SOPC true
set_module_property HIDE_FROM_QUARTUS true
set_module_property REPORT_TO_TALKBACK false
set_module_property ALLOW_GREYBOX_GENERATION false
set_module_property REPORT_HIERARCHY false


# 
# file sets
# 
add_fileset QUARTUS_SYNTH QUARTUS_SYNTH "" ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL clr_fg_component
set_fileset_property QUARTUS_SYNTH ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property QUARTUS_SYNTH ENABLE_FILE_OVERWRITE_MODE false

set hdlpath "./hdl"
add_fileset_file clr_fg_avm.v VERILOG PATH "${hdlpath}/clr_fg_avm.v"
add_fileset_file clr_fg_avs.v VERILOG PATH "${hdlpath}/clr_fg_avs.v"
add_fileset_file clr_fg_clinput.v VERILOG PATH "${hdlpath}/clr_fg_clinput.v"
add_fileset_file clr_fg_tap.v VERILOG PATH "${hdlpath}/clr_fg_tap.v"
add_fileset_file clr_fg_component.v VERILOG PATH "${hdlpath}/clr_fg_component.v" TOP_LEVEL_FILE


# 
# parameters
# 
add_parameter DEVICE_FAMILY string
set_parameter_property DEVICE_FAMILY SYSTEM_INFO {DEVICE_FAMILY}
set_parameter_property DEVICE_FAMILY HDL_PARAMETER true
set_parameter_property DEVICE_FAMILY ENABLED false
#set_parameter_property DEVICE_FAMILY VISIBLE false


# 
# display items
# 


#-----------------------------------
# Avalon-MM Slave interface
#-----------------------------------
# 
# connection point clock_s1
# 
add_interface clock_s1 clock end
set_interface_property clock_s1 clockRate 0

add_interface_port clock_s1 csi_s1_clk clk Input 1

# 
# connection point reset_s1
# 
add_interface reset_s1 reset end
set_interface_property reset_s1 associatedClock clock_s1
set_interface_property reset_s1 synchronousEdges DEASSERT

add_interface_port reset_s1 rsi_s1_reset reset Input 1

# 
# connection point s1
# 
add_interface s1 avalon end
set_interface_property s1 addressUnits WORDS
set_interface_property s1 associatedClock clock_s1
set_interface_property s1 associatedReset reset_s1
set_interface_property s1 bitsPerSymbol 8
set_interface_property s1 burstOnBurstBoundariesOnly false
set_interface_property s1 burstcountUnits WORDS
set_interface_property s1 explicitAddressSpan 0
set_interface_property s1 holdTime 0
set_interface_property s1 linewrapBursts false
set_interface_property s1 maximumPendingReadTransactions 0
set_interface_property s1 maximumPendingWriteTransactions 0
set_interface_property s1 readLatency 0
set_interface_property s1 readWaitTime 1
set_interface_property s1 setupTime 0
set_interface_property s1 timingUnits Cycles
set_interface_property s1 writeWaitTime 0

add_interface_port s1 avs_s1_address address Input 2
add_interface_port s1 avs_s1_write write Input 1
add_interface_port s1 avs_s1_writedata writedata Input 32
add_interface_port s1 avs_s1_read read Input 1
add_interface_port s1 avs_s1_readdata readdata Output 32
set_interface_assignment s1 embeddedsw.configuration.isFlash 0
set_interface_assignment s1 embeddedsw.configuration.isMemoryDevice 0
set_interface_assignment s1 embeddedsw.configuration.isNonVolatileStorage 0
set_interface_assignment s1 embeddedsw.configuration.isPrintableDevice 0

# 
# connection point irq_s1
# 
add_interface irq_s1 interrupt end
set_interface_property irq_s1 associatedAddressablePoint s1
set_interface_property irq_s1 associatedClock clock_s1
set_interface_property irq_s1 associatedReset reset_s1

add_interface_port irq_s1 avs_s1_irq irq Output 1


#-----------------------------------
# Avalon-MM master interface
#-----------------------------------
# 
# connection point clock_m1
# 
add_interface clock_m1 clock end
set_interface_property clock_m1 clockRate 0

add_interface_port clock_m1 csi_m1_clk clk Input 1

# 
# connection point reset_m1
# 
add_interface reset_m1 reset end
set_interface_property reset_m1 associatedClock clock_s1
set_interface_property reset_m1 synchronousEdges DEASSERT

add_interface_port reset_m1 rsi_m1_reset reset Input 1

# 
# connection point m1
# 
add_interface m1 avalon start
set_interface_property m1 addressUnits SYMBOLS
set_interface_property m1 associatedClock clock_m1
set_interface_property m1 associatedReset reset_s1
set_interface_property m1 bitsPerSymbol 8
set_interface_property m1 burstOnBurstBoundariesOnly false
set_interface_property m1 burstcountUnits WORDS
set_interface_property m1 doStreamReads false
set_interface_property m1 doStreamWrites false
set_interface_property m1 holdTime 0
set_interface_property m1 linewrapBursts false
set_interface_property m1 maximumPendingReadTransactions 0
set_interface_property m1 maximumPendingWriteTransactions 0
set_interface_property m1 readLatency 0
set_interface_property m1 readWaitTime 1
set_interface_property m1 setupTime 0
set_interface_property m1 timingUnits Cycles
set_interface_property m1 writeWaitTime 0

add_interface_port m1 avm_m1_address address Output 32
add_interface_port m1 avm_m1_burstcount burstcount Output 6
add_interface_port m1 avm_m1_write write Output 1
add_interface_port m1 avm_m1_writedata writedata Output 32
add_interface_port m1 avm_m1_byteenable byteenable Output 4
add_interface_port m1 avm_m1_waitrequest waitrequest Input 1


#-----------------------------------
# CameraLink condit interface
#-----------------------------------
# 
# connection point cl_base
# 
add_interface cl_base conduit end
set_interface_property cl_base associatedClock ""
set_interface_property cl_base associatedReset ""

add_interface_port cl_base coe_clr_clk rx_clk Input 1
add_interface_port cl_base coe_clr_fval fval Input 1
add_interface_port cl_base coe_clr_lval lval Input 1
add_interface_port cl_base coe_clr_dval dval Input 1
add_interface_port cl_base coe_clr_port_a port_a Input 8
add_interface_port cl_base coe_clr_port_b port_b Input 8
add_interface_port cl_base coe_clr_port_c port_c Input 8

