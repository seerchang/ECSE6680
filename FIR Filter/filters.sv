
module fir_pipeline #(
    parameter N = 100
)(
    input logic clk, rst, valid,
    input logic signed [31:0] x,
    input logic signed [31:0] coeffs [N-1:0],
    output logic signed [31:0] y
);

    integer i;

    // Pipeline array to hold partial sums
    logic signed [2*31:0] sum_pipeline [N-1:0];
    logic signed [2*31:0] sum_final;
    logic signed [31:0] x_in;

    always_comb begin
        if (valid)
            x_in = x;
        else
            x_in = 0;     
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            // Clear everything on reset
            for (i = 0; i < N; i++) begin
                sum_pipeline[i] <= '0;
            end
        end
        else begin
            // Stage 0 partial sum: multiply newest sample by coeffs[0]
            sum_pipeline[0] <= (x_in * coeffs[N-1]) >>> 31;
            // For i>0: sum_pipeline[i] = sum_pipeline[i-1] + (x * coeffs[i])
            for (i = 1; i < N; i++) begin
                sum_pipeline[i] <= sum_pipeline[i-1] + ((x_in * coeffs[N-1-i]) >>> 31);
            end
        end
    end

    assign sum_final = sum_pipeline[N-1];

    always_comb begin
        if (sum_final > 64'sd2147483647) // 2^32 - 1
            y = 32'sd2147483647;
        else if (sum_final < -64'sd2147483648)  // -2^31
            y = -32'sd2147483648;
        else
            y = sum_final[31:0];  // Truncate to 32-bit (Q31)
    end

endmodule


module fir_parallel_L2 #(
    parameter N = 100
)(
    input  logic clk,
    input  logic rst,
    input  logic valid,
    // Two adjacent input samples
    input  logic signed [31:0] x1,  // x[2k]
    input  logic signed [31:0] x2,  // x[2k+1]
    // FIR coefficients
    input  logic signed [31:0] coeffs [N-1:0],
    // Two adjacent outputs
    output logic signed [31:0] y1,  // y[2k]
    output logic signed [31:0] y2   // y[2k+1]
);

    logic signed [31:0] sr [0:N];

    integer i;

    logic signed [63:0] acc1, acc2;
    logic signed [31:0] x1_in, x2_in;

    always_comb begin
        if (valid) begin
            x1_in = x1;
            x2_in = x2;
        end else begin
            x1_in = 0;
            x2_in = 0;
        end     
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i <= N; i++) begin
                sr[i] <= '0;
            end
            y1 <= '0;
            y2 <= '0;
        end
        else begin
            // Shift old samples up by 2
            for (i = N; i >= 2; i--) begin
                sr[i] <= sr[i-2];
            end

            // Insert the newest samples at the bottom
            sr[0] <= x2_in;
            sr[1] <= x1_in;

            // Compute y1 and y2 (no pipelining — a single cycle sum)
            acc1 = 0;
            acc2 = 0;
            for (i = 0; i < N; i++) begin
                acc1 += (sr[i]   * coeffs[i]) >>> 31;
                acc2 += (sr[i+1] * coeffs[i]) >>> 31;
            end

            // Truncate
            y1 <= acc2[31:0];
            y2 <= acc1[31:0];
        end
    end
endmodule


module fir_parallel_L3 #(
    parameter N = 100
)(
    input  logic clk,
    input  logic rst,
    input  logic valid,
    // 2 adjacent input samples
    input  logic signed [31:0] x1,  // x[3k]
    input  logic signed [31:0] x2,  // x[3k+1]
    input  logic signed [31:0] x3,  // x[3k+2]
    // FIR coefficients
    input  logic signed [31:0] coeffs [N-1:0],
    // 2 adjacent outputs
    output logic signed [31:0] y1,  // y[3k]
    output logic signed [31:0] y2,  // y[3k+1]
    output logic signed [31:0] y3   // y[3k+2]
);

    logic signed [31:0] sr [0:N+1];

    integer i;

    logic signed [63:0] acc1, acc2;
    logic signed [63:0] acc3;
    logic signed [31:0] x1_in, x2_in, x3_in;

    always_comb begin
        if (valid) begin
            x1_in = x1;
            x2_in = x2;
            x3_in = x3;
        end else begin
            x1_in = 0;
            x2_in = 0;
            x3_in = 0;
        end     
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i <= N+1; i++) begin
                sr[i] <= '0;
            end
            y1 <= '0;
            y2 <= '0;
            y3 <= '0;
        end
        else begin
            // Shift old samples up by 3
            for (i = N; i >= 3; i--) begin
                sr[i] <= sr[i-3];
            end

            // Insert the newest samples at the bottom
            sr[0] <= x3_in;
            sr[1] <= x2_in;
            sr[2] <= x1_in;

            // Compute y1 and y2 (no pipelining — a single cycle sum)
            acc1 = '0;
            acc2 = '0;
            acc3 = '0;

            for (i = 0; i < N; i++) begin
                acc1 += (sr[i]   * coeffs[i]) >>> 31;
                acc2 += (sr[i+1] * coeffs[i]) >>> 31;
                acc3 += (sr[i+2] * coeffs[i]) >>> 31;
            end

            // Truncate
            y1 <= acc3[31:0];
            y2 <= acc2[31:0];
            y3 <= acc1[31:0];
        end
    end
endmodule



module fir_parallel_L3_pipeline #(
    parameter N = 100
)(
    input  logic clk,
    input  logic rst,
    input  logic valid,

    // Three input samples (adjacent in time): x[3k], x[3k+1], x[3k+2]
    input  logic signed [31:0]  x1,
    input  logic signed [31:0]  x2,
    input  logic signed [31:0]  x3,

    // FIR coefficients
    input  logic signed [31:0] coeffs [N-1:0],

    // Three outputs (adjacent in time): y[3k], y[3k+1], y[3k+2]
    output logic signed [31:0] y1,
    output logic signed [31:0] y2,
    output logic signed [31:0] y3
);

    integer i;
    logic signed [31:0] x1_in, x2_in, x3_in;
    
    // Pipeline array to hold partial sums
    logic signed [63:0] sum_pipeline_1 [N-1:0];
    logic signed [63:0] sum_pipeline_2 [N-1:0];
    logic signed [63:0] sum_pipeline_3 [N-1:0];
    logic signed [63:0] sum_pipeline_3_d [N-1:0];

    always_comb begin
        if (valid) begin
            x1_in = x1;
            x2_in = x2;
            x3_in = x3;
        end else begin
            x1_in = 0;
            x2_in = 0;
            x3_in = 0;
        end     
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            // Clear everything on reset
            for (i = 0; i < N; i++) begin
                sum_pipeline_1[i] <= '0;
                sum_pipeline_2[i] <= '0;
                sum_pipeline_3[i] <= '0;
                sum_pipeline_3_d[i] <= '0;
            end
        end
        else begin
            sum_pipeline_1[0] <= (x1_in * coeffs[N-1]) >>> 31;
            sum_pipeline_2[0] <= (x2_in * coeffs[N-1]) >>> 31;
            sum_pipeline_3[0] <= (x3_in * coeffs[N-1]) >>> 31;
            
            for (i = 1; i < N; i++) begin

                sum_pipeline_1[i] <= sum_pipeline_3_d[i-1] + (x1_in * coeffs[N-1-i]) >>> 31;
                sum_pipeline_2[i] <= sum_pipeline_1[i-1] + (x2_in * coeffs[N-1-i]) >>> 31;
                sum_pipeline_3[i] <= sum_pipeline_2[i-1] + (x3_in * coeffs[N-1-i]) >>> 31;
                sum_pipeline_3_d[i] = sum_pipeline_3[i];
            end

        end

    end
    assign y1 = sum_pipeline_1[N-1][31:0];
    assign y2 = sum_pipeline_2[N-1][31:0];
    assign y3 = sum_pipeline_3[N-1][31:0];
endmodule


