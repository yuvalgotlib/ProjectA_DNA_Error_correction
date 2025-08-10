`timescale 1ns / 1ps
module kmer_gen (
        input logic clk,
        input logic reset,                // Asynchronous reset signal
        input logic [511:0] read,          // 512-bit original read input
        input logic EN_RG1,                 // Enable signal for rgd1
        input logic EN_SHIFT,             // Enable signal for counter and shifting
        input logic EN_RG2,                 // Enable signal for rg2
        input logic EN_OUT,               // Enable signal to propagate register
        output logic [97:0] rg_out        // Output k-mer with position (2 registers of 49 bits each)
);

        // Internal Signals
        logic [7:0] init_arr;
        logic [7:0] counter;                 // Counter value (8 bits)
        logic [511:0] rgd1_reg;              // Group of registers for rgd1 (8 registers of 64 bits)
        logic [511:0] rg2_reg;                // Register for top 90 bits after shift
        logic [97:0] rg_out_reg;             // Register for final output

        // Asynchronous Reset Logic
        always_ff @(negedge reset or posedge clk) begin
                if (!reset) begin
                        counter <= 8'b0;           // Reset counter to 0 on reset
                                init_arr <= 8'b0;
                end else if (EN_SHIFT) begin
                        counter <= counter + 8'd1; // Increment counter by 2 after each shift
                end

        // read Logic (Data Propagation to rgd1)
                if (EN_RG1) begin
                        rgd1_reg <= {read[503:0], init_arr};          // Propagate input data to rgd1 group of registers
                end

        // rg2 Logic (Data Propagation)
                if (EN_RG2) begin
                        rg2_reg <= rgd1_reg << (2 * counter); // insert rg2 the shiftet by counter value
                end

        // rg_out Logic (Concatenate and Write)
                if (EN_OUT) begin
                        rg_out_reg <= {counter - 2'b01 , rg2_reg[511:422]}; // Concatenate rg2_out (k-mer) with counter (position)
                end
        end
        // Output Assignment
        assign rg_out = rg_out_reg;           // Assign final register to output
        
endmodule
