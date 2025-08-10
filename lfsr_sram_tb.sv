// Testbench for lfsr_sram module
`timescale 1ns / 100fs

module lfsr_sram_tb;

    // Testbench signals
    logic clk;
    logic reset;
    logic [97:0] rg_out;
    logic EN_LFSR;
    logic EN_LOAD_SRAM;
    logic [63:0] dataout1, dataout2, dataout3, dataout4, dataout_ba;
    logic OEB1, CSB1, WEB1;
    logic OEB2, CSB2, WEB2;
    logic [63:0] datain1, datain2, datain3, datain4, datain_ba;
    logic [6:0] address, address_ba;

    // Instantiate the DUT (Device Under Test)
    lfsr_sram dut (
        .clk(clk),
        .reset(reset),
        .rg_out(rg_out),
        .EN_LFSR(EN_LFSR),
        .EN_LOAD_SRAM(EN_LOAD_SRAM),
        .dataout1(dataout1),
        .dataout2(dataout2),
        .dataout3(dataout3),
        .dataout4(dataout4),
        .dataout_ba(dataout_ba),
        .OEB1(OEB1),
        .CSB1(CSB1),
        .WEB1(WEB1),
        .OEB2(OEB2),
        .CSB2(CSB2),
        .WEB2(WEB2),
        .datain1(datain1),
        .datain2(datain2),
        .datain3(datain3),
        .datain4(datain4),
        .datain_ba(datain_ba),
        .address(address),
        .address_ba(address_ba)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100 MHz clock
    end

    // Testbench logic
    initial begin
        // Initialize signals
        reset = 1;
        rg_out = 98'b0;
        EN_LFSR = 0;
        EN_LOAD_SRAM = 0;
        dataout1 = 64'b0;
        dataout2 = 64'b0;
        dataout3 = 64'b0;
        dataout4 = 64'b0;
        dataout_ba = 64'b0;
        OEB1 = 1;
        CSB1 = 0;
        CSB2 = 0;
        WEB2 = 1;

        WEB1 = 0;
        OEB2 = 1;

        // Apply reset
        #10 reset = 0;
        #10 reset = 1;

        #10 EN_LFSR = 1; // sram_has_write_shift
        //insert data to datain inputs
        rg_out = 98'h0_0002_8002_c000_6c6c_0000_0000;
        #10 EN_LFSR = 0; // preload data
        EN_LOAD_SRAM = 1; 
        WEB1 = 1; 
        OEB2 = 0; 

        #10 EN_LOAD_SRAM = 0; // stop loading SRAM

        #10 EN_LFSR = 1; // preload data
        EN_LOAD_SRAM = 1; 
        WEB1 = 0; 
        OEB2 = 1; 


        // Finish simulation
        #100 $finish;
    end

endmodule