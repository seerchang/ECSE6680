/*
1: Pipelining Only
2: L=2 Parallel Only
3: L=3 Parallel Only
4: L=3 Parallel and Pipelining
*/

//`define FILTER1
//`define FILTER2
//`define FILTER3
`define FILTER4

// A dummy warpper 
module top(
    input logic clk
);
    parameter NUM_TAPS = 100;

    logic rst;
    logic valid;
    (* DONT_TOUCH = "true" *)logic signed [31:0] x1, x2, x3, y1, y2, y3; 
    (* DONT_TOUCH = "true" *)logic signed [31:0] coeffs [NUM_TAPS-1:0];

    assign valid = 1;
    assign rst = 0;
    
    integer i;
    // assign some arbitrary coeffs 
    always_comb begin
        for (i = 0; i < NUM_TAPS; i = i + 1) begin
            coeffs[i] = i;
        end
    end

    // assign some arbitrary input 
    always_ff @(posedge clk or posedge rst) begin
        if (rst || x1 == 32'sd10000) begin
            x1 <= 0;  
            x2 <= 0;
            x3 <= 0;
        end else begin
            x1 <= x1 + 1; 
            x2 <= x2 + 1;
            x3 <= x3 + 1;
        end
    end

    // Filter instance
    `ifdef FILTER1
        fir_pipeline #(.N(NUM_TAPS)) fir_dut (
            .clk(clk), .rst(rst), .valid(valid), 
            .coeffs(coeffs),
            .x(x1), .y(y1)
        );
    `elsif FILTER2
        fir_parallel_L2 #(.N(NUM_TAPS)) fir_dut (
            .clk(clk), .rst(rst), .valid(valid), 
            .coeffs(coeffs),
            .x1(x1), .y1(y1),
            .x2(x2), .y2(y2)
        );
    `elsif FILTER3
        fir_parallel_L3 #(.N(NUM_TAPS)) fir_dut (
            .clk(clk), .rst(rst), .valid(valid),
            .coeffs(coeffs),
            .x1(x1), .y1(y1), 
            .x2(x2), .y2(y2),
            .x3(x3), .y3(y3)
        );
    `elsif FILTER4
        fir_parallel_L3_pipeline #(.N(NUM_TAPS)) fir_dut (
            .clk(clk), .rst(rst), .valid(valid),
            .coeffs(coeffs),
            .x1(x1), .y1(y1), 
            .x2(x2), .y2(y2),
            .x3(x3), .y3(y3)
        );
    `endif




endmodule
