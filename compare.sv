`timescale 1ns/100fs
module compare (
        input logic clk,                  // Clock signal
        input logic reset,                // Reset signal (active low)
        input logic EN_CLASS,             // Enable signal for the classification phase
        input logic EN_POS,               // Enable signal for the position update phase
        input logic EN_EC,                // Enable signal for error correction phase
        input logic [6:0] LFSR0_data,     // Data from LFSR0 (7 bits)
        input logic [4:0] LFSR1_data,     // Data from LFSR1 (5 bits)
        input logic [4:0] LFSR2_data,     // Data from LFSR2 (5 bits)
        input logic [4:0] LFSR3_data,     // Data from LFSR3 (5 bits)
        input logic [4:0] LFSR4_data,     // Data from LFSR4 (5 bits)
        input logic EN_COMPARE,
        input logic [63:0] dataout1, dataout2, dataout3, dataout4, dataout_ba, // Data outputs from SRAMs

        // Read port (Port 2) control signals
        input logic WEB2,                 // Write Enable Bar signal for SRAM
        input logic OEB2,                 // Output Enable Bar signal for SRAM
        input logic CSB2,                 // Chip Select Bar signal for SRAM
        input logic WEB2_ba,              // Write Enable Bar signal for bit array SRAM
        input logic OEB2_ba,              // Output Enable Bar signal for bit array SRAM
        input logic CSB2_ba,              // Chip Select Bar signal for bit array SRAM
                
        input logic Read_sram,              // enables the reading of counters from the srams
        input logic res_to_map,                         //enables writing the 0/1 (weak/solid result) to the map
        input logic local_min,          //enables comparing 2 counter at a time
        input logic calc_absolute, //enables calculation of the absolute minimum of all counter
        input logic get_result,         // enables the evaluation of the absolute mini
                
        output logic [63:0] datain1, datain2, datain3, datain4, datain_ba, // Data outputs from SRAM (unused in compare)
        output logic [6:0] address, address_ba,   // SRAM addresses for normal and bit array SRAM
        output logic map_full,              // Indicates all kmer were classified 0/1
        output logic result,               // Result of the classification
        output logic result_ready,         // Indicates if the result is ready
        output logic calc_done,            // Indicates calculation completion
        output logic dycr_done,            // Indicates decryption completion
        output logic update_map_done,      // Indicates map update completion
        output logic [3:0][207:0] map_mem  // Output the map matrix that will be used in classify
);

        // Internal Signals
        logic [6:0] temp0;                 // Temporary variable for LFSR0 address
        logic [5:0] temp1, temp2, temp3, temp4; // Temporary variables for LFSR1-4 addresses
        logic [1:0] counter1, counter2, counter3, counter4; // 2-bit counters from SRAM
        logic [1:0] min1, min2, absolute_min; // Intermediate minimum values

        // Mapping matrix (4x212), initialized to zero
        //logic [3:0][207:0] map;
        logic [7:0] kmer_num;       // Current k-mer number

        //assign map_mem = map;  //connect this internal matrix to the outside.

        localparam integer map_size = 207;
        localparam integer threshold = 3;

        // Abstraction for SRAM operation validity
        //logic Read_sram_op = (WEB2 && !CSB2 && !OEB2);    // READ operation for LFSR SRAMs
        //logic Read_ba_op = (WEB2_ba && !CSB2_ba && !OEB2_ba); // READ operation for bit array SRAM

        // Synchronous Block: Reset and sequential logic for state management
        always_ff @(posedge clk or negedge reset) begin
                if (!reset) begin
                        map_mem <= '{default: 0}; // Initialize all elements to 0 on
                        kmer_num <= 8'b0;
                        address_ba <= 7'b0;
                        calc_done <= 1'b0;
                        update_map_done <= 1'b0;
                        map_full <= 1'b0;
                        dycr_done <= 1'b0;
                        result <= 1'b0;
                        result_ready <= 1'b0;
                        absolute_min <= 1'b0;
                        min1 <= 2'b0;
                        min2 <= 2'b0;
                        counter1 <= 2'b0;
                        counter2 <= 2'b0;
                        counter3 <= 2'b0;
                        counter4 <= 2'b0;
                        temp0 <= 7'b1;                     
                        temp1 <= 6'b0;
                        temp2 <= 6'b0;
                        temp3 <= 6'b0;
                        temp4 <= 6'b0;
                end else begin
                        // Update kmer_num and address_ba during position update phase
                        if (EN_POS) begin
                                if(kmer_num == map_size)begin
                                        map_full <= 1'b1;
                                end
                                else begin 
                                        kmer_num <= kmer_num + 1;
                                        address_ba <= kmer_num >> 1; // Divide by 2(logical shift right by 1)
                                        //calc_done <= 1'b1;
                                end
                        end

                        // Handle classification phase
                        if (EN_CLASS) begin // enable classification of weak/solid
                              //  if (Read_ba_op) begin
                                        // Extract temporary values from dataout_ba based on k-mer parity
                                        calc_done <= 1'b0;
                                        temp0 <= (kmer_num[0]) ? dataout_ba[58:52] : dataout_ba[26:20];
                                        temp1 <= (kmer_num[0]) ? (dataout_ba[51:47] << 1) : (dataout_ba[19:15] << 1);
                                        temp2 <= (kmer_num[0]) ? (dataout_ba[46:42] << 1) : (dataout_ba[14:10] << 1);
                                        temp3 <= (kmer_num[0]) ? (dataout_ba[41:37] << 1) : (dataout_ba[9:5] << 1);
                                        temp4 <= (kmer_num[0]) ? (dataout_ba[36:32] << 1) : (dataout_ba[4:0] << 1);
                                        address <= temp0; // Update address with temp0
                                        
                                      //  dycr_done <= 1'b1; // Mark decryption as done
                              //  end else begin
                                                                        //==================we
                                     //   dycr_done <= 1'b0; // Reset decryption flag if operation invalid
                              // end
                        end

                        // Handle error correction phase
                        if (EN_EC) begin
                                address <= LFSR0_data; // Use LFSR0 data as address
                                temp1 <= LFSR1_data;
                                temp2 <= LFSR2_data;
                                temp3 <= LFSR3_data;
                                temp4 <= LFSR4_data;
                        end
                        
                        // Update Mapping Matrix: Store result in the map matrix when ready
                        if (res_to_map) begin
                                map_mem[0][kmer_num] <= result; // Update the map with the result
                                update_map_done <= 1'b1;    // Indicate map update completion
                                result_ready <= 1'b0;           
                        end else begin
                                update_map_done <= 1'b0;    // Reset flag if result not ready
                        end
                        
                        // Counter Updates: Read 2-bit counters from SRAMs during valid operations
                        if (Read_sram) begin
                                counter1 <= dataout1[temp1 +: 2];
                                counter2 <= dataout2[temp2 +: 2];
                                counter3 <= dataout3[temp3 +: 2];
                                counter4 <= dataout4[temp4 +: 2];
                        end         
                        if(EN_COMPARE) begin
                            if(local_min) begin
                                min1 <= (counter1 < counter2) ? counter1 : counter2;
                                min2 <= (counter3 < counter4) ? counter3 : counter4;
                            end else if(calc_absolute) begin
                                absolute_min <= (min1 < min2) ? min1 : min2;
                            end else if(get_result) begin
                                result <= (absolute_min >= threshold);
                                                                result_ready <= 1'b1; // Result readiness flag
                            end
                        end
                                       
                       /*
        // Combinational Logic for Result Calculation
        always_comb begin
                if(EN_COMPARE) begin
                        // Determine the minimum of counters from SRAMs
                        min1 = (counter1 < counter2) ? counter1 : counter2;
                        min2 = (counter3 < counter4) ? counter3 : counter4;
                        // Find the absolute minimum value
                        absolute_min = (min1 < min2) ? min1 : min2;
                        // Result is '1' if absolute_min >= 3, otherwise '0'
                        result = (absolute_min >= threshold);
                        result_ready = 1'b1; // Result readiness flag
                end
                else result_ready = 1'b0;*/
                        end
        end
endmodule
