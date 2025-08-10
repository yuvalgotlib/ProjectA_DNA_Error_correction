`timescale 1ns/100fs
module gen_hash_controller (
        input  logic clk,
        input  logic reset,              // Active low reset signal
        input  logic start_gen,          // Start signal for FSM

        output logic EN_RG1,             // Enable signal for rg1
        output logic EN_RG2,             // Enable signal for rg2
        output logic EN_LFSR,            // Enable signal for LFSRs

        output logic EN_SHIFT,           // Enable signal for shifting
        output logic EN_OUT,             // Enable signal for output
        output logic set_row, get_row, read_add,       // Enable signal for LOAD

        output logic WEB1,
        output logic WEB2,
        output logic CSB1,
        output logic CSB2,
        output logic OEB1,
        output logic OEB2,

        output logic generation_done     // Signal that generation phase is complete
);

        // FSM states
        typedef enum logic [3:0] {
                IDLE,                             // Wait for start_gen signal
                LOAD_RG1,                         // Load data into RG1
                SHIFT_BY_COUNTER,                // Write shifted data by counter to RG2
                OPEN_RG_OUT,          			// Write k-mer data to RG_OUT and shift
				NOP,							//keep the first rg-out unchanged for the lfsr
				OPEN_LFSR,                   		// Write hash data with LFSRs and shift
				SET_ADDR,						// Prep control signals for reading from the sram
                GET_ROW,                        // Read data from SRAM using hashed addresses
				SET_ROW,						// Stop and wait for SRAM preparation
                SRAM_WRITE              		// Write hash data to SRAM
                                            
        } state_t;

        state_t current_state, next_state;
        logic [7:0] kmer_gen_done; // Internal counter register
		logic counter;

        // State register
        always_ff @(posedge clk or negedge reset) begin
                if (!reset) begin
                        current_state <= IDLE;
                        kmer_gen_done <= 0;
                end else begin
                        current_state <= next_state;
                        if (current_state == SHIFT_BY_COUNTER ||
                                current_state == OPEN_RG_OUT ||
                                current_state == EN_LFSR ||
                                current_state == SRAM_WRITE)
                                kmer_gen_done <= kmer_gen_done + 1;
                end
        end

        // FSM next-state logic
        always_comb begin
                // Default values
                next_state = current_state;

                case (current_state)
                        IDLE: begin  
                                EN_RG1 = 0;
                                EN_RG2 = 0;
                                EN_LFSR = 0;
                                EN_OUT = 0;
                                EN_SHIFT = 0;
                                generation_done = 0;
								counter = 0;
								read_add = 0;
								get_row = 0;
								set_row = 0;

                                WEB1 = 0;
                                WEB2 = 1;
                                CSB1 = 0;
                                CSB2 = 0;
                                OEB1 = 1;
                                OEB2 = 1;

                                if (start_gen)
                                        next_state = LOAD_RG1;
                        end

                        LOAD_RG1: begin
                                EN_RG1 = 1;
                                next_state = SHIFT_BY_COUNTER;
                        end

						SHIFT_BY_COUNTER: begin
                                EN_RG1 = 0;
                                EN_RG2 = 1;
                                EN_SHIFT = 1;
                                next_state = OPEN_RG_OUT;
                        end

						OPEN_RG_OUT: begin
                                EN_OUT = 1;
                                next_state = NOP;
                        end
						
						NOP: begin
							EN_RG2 = 0;
							EN_SHIFT = 0;
							EN_OUT = 0;
							next_state = OPEN_LFSR;
						end
						
						OPEN_LFSR: begin
								EN_LFSR = 1;
								next_state = SET_ADDR;
						end
						SET_ADDR: begin
							read_add = 1;
							EN_RG2 = 0;
							EN_SHIFT = 0;
							EN_OUT = 0;
							EN_LFSR = 0;							
							WEB1 = 1;
							OEB2=0;
							next_state = GET_ROW;
						end
						
						GET_ROW: begin
							get_row = 1;
							read_add = 0;
                            next_state = SET_ROW;
                        end

						SET_ROW: begin
							set_row = 1;
							get_row = 0;
							read_add = 0;
							WEB1=0;
							OEB2=1;
                            next_state = SRAM_WRITE;
                        end

						SRAM_WRITE: begin
							EN_RG2 = 1;
							EN_SHIFT = 1;
							EN_OUT = 1;
							EN_LFSR = 1;	
	                        if (kmer_gen_done == 8'd212) begin
	                        	generation_done = 1;
	                            next_state = IDLE;
	                            end else begin
									next_state = SET_ADDR;
							end
                        end

                        default: next_state = IDLE;
                endcase
        end

endmodule
