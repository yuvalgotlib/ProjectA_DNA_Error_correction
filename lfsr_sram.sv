`timescale 1ns / 1ps
module lfsr_sram (
        input logic clk,
        input logic reset,
        input logic [97:0] rg_out,        // 98-bit input from gen_kmers module
        input logic EN_LFSR,              // Enable signal for LFSR calculation
        input logic set_row, get_row, read_add,         // Enable signal for LOAD
        input logic [63:0] dataout1, dataout2, dataout3, dataout4, dataout_ba, // Data output for each SRAM

        // Separate control signals for dual ports
        input logic OEB1, CSB1, WEB1,
        input logic OEB2, CSB2, WEB2,

        output logic [63:0] datain1, datain2, datain3, datain4, datain_ba, // Data input for each SRAM
        output logic [6:0] address, address_ba // Shared address for all SRAMs
);

        // Internal LFSR registers
        logic [6:0] LFSR0_data; // Functions as the address
        logic [4:0] LFSR1_data;
        logic [4:0] LFSR2_data;
        logic [4:0] LFSR3_data;
        logic [4:0] LFSR4_data;

        // Temporary storage for row data
        logic [63:0] modified_data1, modified_data2, modified_data3, modified_data4, modified_data_ba;
        logic [5:0] bit_offset1, bit_offset2, bit_offset3, bit_offset4;

        logic [31:0] current_data;
        logic [7:0] position;
        assign position = rg_out[97:90];
        //assign address_ba = rg_out[97:90];
        
        // Global signal for cnt
        logic [2:0] global_cnt;
        logic [63:0] global_mask;
        logic [63:0] global_chain;
        
        logic [79:0] taps;
        logic [79:0] taps_internal;
        assign taps_internal = rg_out[79:0];  // Only first 90 bits
        assign taps = taps_internal ^ {taps_internal[78:0], 1'b0};

        localparam integer prev_data = 4; // Need to remember data from 3 cycles ago to write in parallel

        function [63:0] update_counter(input logic [63:0] orig, input logic [5:0] offset);
                logic [1:0] cnt;
                logic [63:0] mask;
                logic [63:0] chain;
                cnt = orig[offset +: 2];
                cnt = (cnt < 2'b11) ? cnt + 1 : 2'b11;
                
                mask = ~(64'b11 << offset);
                chain = {62'b0, cnt};
                                
                // Assign the cnt value to the global signal
                global_cnt = cnt;  // Store cnt globally
                global_mask = mask;
                global_chain = chain;
                
                
                
                return (orig & mask) | (chain << offset);
        endfunction

        always_ff @(posedge clk or negedge reset) begin
                if (!reset) begin
                        // Reset all LFSRs to random values
                        LFSR0_data <= 7'b0101101;
                        LFSR1_data <= 5'b00101;
                        LFSR2_data <= 5'b11001;
                        LFSR3_data <= 5'b01101;
                        LFSR4_data <= 5'b01011;
                        modified_data_ba <= 64'b0;
                        modified_data1 <= 64'b0;
                        modified_data2 <= 64'b0;
                        modified_data3 <= 64'b0;
                        modified_data4 <= 64'b0;
                end else begin
                        if (EN_LFSR) begin // SRAM hash write shift + SRAM_HASH_WRITE_SHIFT_PIPE
                               address <= LFSR0_data[6:0];
                               // Update LFSR values
                                LFSR0_data <= {taps[5], taps[20], taps[45], taps[67], taps[17], taps[72], taps[36]};
                                LFSR1_data <= {taps[15], taps[51], taps[25], taps[50], taps[31]};
                                LFSR2_data <= {taps[9], taps[44], taps[58], taps[13], taps[66]};
                                LFSR3_data <= {taps[40], taps[24], taps[55], taps[20], taps[60]};
                                LFSR4_data <= {taps[15], taps[30], taps[5], taps[61], taps[45]};   
                        end

                                                if (read_add) begin // SRAM hash write shift + SRAM_HASH_WRITE_SHIFT_PIPE
                                                        address <= LFSR0_data[6:0];
                                                        address_ba <= (rg_out[97:90] >>1);
                                                        current_data <= {5'b0, LFSR0_data, LFSR1_data, LFSR2_data, LFSR3_data, LFSR4_data}; // LFSR data concatenation
                                                end 
                                                
                        if (get_row) begin // Pre-load state
                                
                                // Address calculations
                                
                                modified_data1 <= (dataout1 === 64'bx) ? 64'b0 : dataout1;
                                modified_data2 <= (dataout2 === 64'bx) ? 64'b0 : dataout2;
                                modified_data3 <= (dataout3 === 64'bx) ? 64'b0 : dataout3;
                                modified_data4 <= (dataout4 === 64'bx) ? 64'b0 : dataout4;

                                if (!position[0]) begin // Even
                                        if ((dataout_ba[31:0] === 32'bx) || (dataout_ba[31:0] === 32'bz)) begin
                                                modified_data_ba <= {current_data, 32'b0};
                                        end else begin
                                                modified_data_ba <= {current_data, dataout_ba[31:0]};
                                        end
                                end else begin // Odd
                                        if (dataout_ba[63:32] === 32'bx) begin
                                                modified_data_ba <= {32'b0, current_data};
                                        end else begin
                                                modified_data_ba <= {dataout_ba[63:32], current_data};
                                        end
                                end

                                // Bit offset calculations
                                bit_offset1 <= LFSR1_data[4:0] << 1; // Multiply by 2
                                bit_offset2 <= LFSR2_data[4:0] << 1;
                                bit_offset3 <= LFSR3_data[4:0] << 1;
                                bit_offset4 <= LFSR4_data[4:0] << 1;
                        end

                                                if (position < 208 + prev_data) begin
                                                        if (set_row) begin // Write to SRAM updated data
                                                                
                                                                if (bit_offset1 < 63 && bit_offset1 != 0) begin
                                                                        datain1 <= update_counter(modified_data1, bit_offset1);
                                                                end else if (modified_data1[bit_offset1 +: 2] < 2'b11) begin
                                                                        if (bit_offset1 == 63) begin
                                                                                datain1 <= {modified_data1[63:62] + 1, modified_data1[61:0]};
                                                                        end else begin
                                                                                datain1 <= {modified_data1[63:2], modified_data1[1:0] + 1};
                                                                        end
                                                                end else begin
                                                                        datain1 <= modified_data1;
                                                                end

                                                                if (bit_offset2 < 63 && bit_offset2 != 0) begin
                                                                        datain2 <= update_counter(modified_data2, bit_offset2);
                                                                end else if (modified_data2[bit_offset2 +: 2] < 2'b11) begin
                                                                        if (bit_offset2 == 63) begin
                                                                                datain2 <= {modified_data2[63:62] + 1, modified_data2[61:0]};
                                                                        end else begin
                                                                                datain2 <= {modified_data2[63:2], modified_data2[1:0] + 1};
                                                                        end
                                                                end else begin
                                                                        datain2 <= modified_data2;
                                                                end

                                                                if (bit_offset3 < 63 && bit_offset3 != 0) begin
                                                                        datain3 <= update_counter(modified_data3, bit_offset3);
                                                                end else if (modified_data3[bit_offset3 +: 2] < 2'b11) begin
                                                                        if (bit_offset3 == 63) begin
                                                                                datain3 <= {modified_data3[63:62] + 1, modified_data3[61:0]};
                                                                        end else begin
                                                                                datain3 <= {modified_data3[63:2], modified_data3[1:0] + 1};
                                                                        end
                                                                end else begin
                                                                        datain3 <= modified_data3;
                                                                end

                                                                if (bit_offset4 < 63 && bit_offset4 != 0) begin
                                                                        datain4 <= update_counter(modified_data4, bit_offset4);
                                                                end else if (modified_data4[bit_offset4 +: 2] < 2'b11) begin
                                                                        if (bit_offset4 == 63) begin
                                                                                datain4 <= {modified_data4[63:62] + 1, modified_data4[61:0]};
                                                                        end else begin
                                                                                datain4 <= {modified_data4[63:2], modified_data4[1:0] + 1};
                                                                        end
                                                                end else begin
                                                                        datain4 <= modified_data4;
                                                                end

                                                                datain_ba <= modified_data_ba; // Assign modified_data_ba directly
                                                        end
                                                end

                end
        end
endmodule
