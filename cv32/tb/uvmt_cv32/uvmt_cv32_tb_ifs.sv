//
// Copyright 2020 OpenHW Group
// Copyright 2020 Datum Technologies
// 
// Licensed under the Solderpad Hardware Licence, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     https://solderpad.org/licenses/
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// 



// This file specifies all interfaces used by the CV32 test bench (uvmt_cv32_tb).
// Most interfaces support tasks to allow control by the ENV or test cases.

`ifndef __UVMT_CV32_TB_IFS_SV__
`define __UVMT_CV32_TB_IFS_SV__


/**
 * clocks and reset
 */
interface uvmt_cv32_clk_gen_if (output logic core_clock, output logic core_reset_n);

   import uvm_pkg::*;
   
   bit       start_clk               = 0;
   // TODO: get the uvme_cv32_* values from random ENV CFG members.
   realtime  core_clock_period       = 1500ps; // uvme_cv32_clk_period * 1ps;
   realtime  reset_deassert_duration = 7400ps; // uvme_cv32_reset_deassert_duarion * 1ps;
   realtime  reset_assert_duration   = 7400ps; // uvme_cv32_reset_assert_duarion * 1ps;
   
   
   /**
    * Generates clock and reset signals.
    * If reset_n comes up de-asserted (1'b1), wait a bit, then assert, then de-assert
    * Otherwise, leave reset asserted, wait a bit, then de-assert.
    */
   initial begin
      core_clock   = 0; // uvme_cv32_clk_initial_value;
      core_reset_n = 0; // uvme_cv32_reset_initial_value;
      wait (start_clk);
      fork
         forever begin
            #(core_clock_period/2) core_clock = ~core_clock;
         end
         begin
           if (core_reset_n == 1'b1) #(reset_deassert_duration);
           core_reset_n = 1'b0;
           #(reset_assert_duration);
           core_reset_n = 1'b1;
         end
      join_none
   end
   
   /**
    * Sets clock period in ps.
    */
   function void set_clk_period ( real clk_period );
      core_clock_period = clk_period * 1ps;
   endfunction : set_clk_period
   
   /** Triggers the generation of clk. */
   function void start();
      start_clk = 1;
      `uvm_info("CLK_GEN_IF", "uvmt_cv32_clk_gen_if.start() called", UVM_NONE)
   endfunction : start
   
endinterface : uvmt_cv32_clk_gen_if

/**
 * Status information generated by the Virtual Peripherals in the DUT WRAPPER memory.
 */
interface uvmt_cv32_vp_status_if (
                                  inout wire        tests_passed,
                                  inout wire        tests_failed,
                                  inout wire        exit_valid,
                                  inout wire [31:0] exit_value
                                 );

  import uvm_pkg::*;

  // TODO: X/Z checks
  initial begin
  end

endinterface : uvmt_cv32_vp_status_if


/**
 * Quasi-static core control signals.
 */
interface uvmt_cv32_core_cntrl_if (
                                    output logic        fetch_en,
                                    output logic        fregfile_disable,
                                    output logic        ext_perf_counters,
                                    // quasi static values
                                    output logic        clock_en,
                                    output logic        test_en,
                                    output logic [31:0] boot_addr,
                                    output logic [ 3:0] core_id,
                                    output logic [ 5:0] cluster_id,
                                    // To be driven by future debug module (DM)
                                    output logic        debug_req,
                                    // Testcase asserts this to load memory (not really a core control signal)
                                    output logic        load_instr_mem
                                  );

  import uvm_pkg::*;

  initial begin: static_controls
    fetch_en          = 1'b0; // Enabled by go_fetch(), below
    fregfile_disable  = 1'b0;
    ext_perf_counters = 1'b0; // TODO: set proper width (currently 0 in the RTL)
  end

  // TODO: randomize core_id and cluster_id (should have no affect?).
  //       randomize boot_addr (need to sync with the start address of the test program.
  //       figure out what to do with test_en.
  initial begin: quasi_static_controls
    clock_en   = 1'b1;
    test_en    = 1'b0;
    boot_addr  = 32'h80;
    core_id    = 4'h0;
    cluster_id = 6'b00_0000;
  end

  // TODO: waiting for the User Manual to provide some guidance here...
  initial begin: debug_control
    debug_req  = 1'b0;
  end

  /** Sets fetch_en to the core. */
  function void go_fetch();
    fetch_en = 1'b1;
    `uvm_info("CORE_CNTRL_IF", "uvmt_cv32_core_cntrl_if.go_fetch() called", UVM_DEBUG)
  endfunction : go_fetch

endinterface : uvmt_cv32_core_cntrl_if


/**
 * Core interrupts
 */
interface uvmt_cv32_core_interrupts_if
 #(
   parameter NUM_FAST_INTR   = 15, //TODO: pass these in from the TB/DUT_WRAP
             NUM_XFASTX_INTR = 32  // _XFASTX_ deliberately choosen to make it visually distinct from _FAST_
  )
  (
   input  logic                       irq_ack,        // dut output
   input  logic                       irq_id,         // dut output
   output logic                       irq_sec,        // dut input
   output logic                       irq_software,   // dut input
   output logic                       irq_timer,      // dut input
   output logic                       irq_external,   // dut input
   output logic [NUM_FAST_INTR-1:0]   irq_fast,       // dut input
   output logic                       irq_nmi,        // dut input
   output logic [NUM_XFASTX_INTR-1:0] irq_fastx       // dut input
  );

  import uvm_pkg::*;

  initial begin
    irq_sec      = 1'b0;
    irq_software = 1'b0;
    irq_timer    = 1'b0;
    irq_external = 1'b0;
    irq_fast     = {NUM_FAST_INTR{1'b0}};
    irq_nmi      = 1'b0;
    irq_fastx    = {NUM_XFASTX_INTR{1'b0}};
    `uvm_info("CORE_INTERRUPT_IF", "Interrupt inputs to CORE all tied low (for now).", UVM_NONE)
  end

endinterface : uvmt_cv32_core_interrupts_if

/**
 * Core status signals.
 */
interface uvmt_cv32_core_status_if (
                                    input  logic       core_busy,
                                    input  logic       sec_lvl
                                   );

  import uvm_pkg::*;

endinterface : uvmt_cv32_core_status_if

/**
 * Step and compare interface
 * Necessary because Xcelium does not support event in the module port list
 */
interface uvmt_cv32_step_compare_if;

   event        ovp_cpu_retire; // Was ovp.cpu.Retire
   event        riscv_retire;   // Was riscv_core.riscv_tracer_i.retire
   bit   [31:0] ovp_cpu_PCr;    // Was iss_wrap.cpu.PCr
   logic [31:0] insn_pc;
   bit         ovp_b1_Step;    // Was ovp.b1.Step = 0;
   bit         ovp_b1_Stepping; // Was ovp.b1.Stepping = 1;
   event       ovp_cpu_busWait;  // Was call to ovp.cpu.busWait();

endinterface // uvmt_cv32_step_compare_if


`endif // __UVMT_CV32_TB_IFS_SV__
