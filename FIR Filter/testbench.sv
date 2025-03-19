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


module fir_tb;
    parameter NUM_SAMPLES = 90;  // Number of test samples
    parameter CLOCK_PERIOD = 10;
    parameter NUM_TAPS = 100;

    logic clk;
    logic rst;
    logic valid;
    logic signed [31:0] x1, x2, x3, y1, y2, y3; 
    logic signed [31:0] test_x [NUM_SAMPLES-1:0];
    logic signed [31:0] test_y [NUM_SAMPLES-1:0];
    logic signed [31:0] coeffs [NUM_TAPS-1:0];
    logic valid_d1, valid_d2;

    // Clock Generation
    always # (CLOCK_PERIOD / 2) clk = ~clk;

    // Read Coefficients from File
    initial begin
        integer i;
        int file;
        `ifdef FILTER1
            $display("Test unit: Filter 1: Pipelining only");
        `elsif FILTER2
            $display("Test unit: Filter 2: L=2 Parallel only");
        `elsif FILTER3
            $display("Test unit: Filter 3: L=3 Parallel only");
        `elsif FILTER4
            $display("Test unit: Filter 4: L=3 Parallel w. Pipelining");
        `endif

        $display("Loading coefficients from file");
        file = $fopen("coeffs.txt", "r");
        if (file == 0) begin
            $display("Error: Cannot open coeffs.txt");
        end
        
        for (i = 0; i < NUM_TAPS; i = i + 1) begin
            if (!$feof(file))
                $fscanf(file, "%d\n", coeffs[i]); // Read integer coefficient
            else
                coeffs[i] = 0;
        end

        $fclose(file);
        $display("Coefficients loaded successfully.");

        $display("Loading test vectors from file...");
        file = $fopen("testvector.txt", "r");
        if (file == 0) begin
            $display("Error: Cannot open testvector.txt");
        end
        
        for (i = 0; i < NUM_SAMPLES; i = i + 1) begin
            if (!$feof(file))
                $fscanf(file, "%d %d\n", test_x[i], test_y[i]); // Read integer x and expected y
            else begin
                test_x[i] = 0;
                test_y[i] = 0;
            end
        end

        $fclose(file);
        $display("Test Vectors loaded successfully.");
    end

    // DUT Instance (Choose which implementation to test)
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
    `else
        $fatal("No DUT defined!")
    `endif

    integer i;
    // Test Stimulus
    initial begin
        clk = 0;
        rst = 1;
        valid = 0;
        x1 = 0;
        x2 = 0;
        x3 = 0;
        # (2 * CLOCK_PERIOD);
        rst = 0;
       
        @(posedge clk);
        valid = 1;
        // Apply input
        $display("Start Time: %0t", $time);
        `ifdef FILTER1
            for (i = 0; i < NUM_SAMPLES; i++) begin
                x1 = test_x[i];
                # CLOCK_PERIOD;
            end
        `elsif FILTER2
            for (i = 0; i < NUM_SAMPLES / 2; i++) begin
                x1 = test_x[i*2];
                x2 = test_x[i*2 + 1];
                # CLOCK_PERIOD;
            end
        `elsif FILTER3
            for (i = 0; i < NUM_SAMPLES / 3; i++) begin
                x1 = test_x[i*3];
                x2 = test_x[i*3 + 1];
                x3 = test_x[i*3 + 2];
                # CLOCK_PERIOD;
            end
        `elsif FILTER4
            for (i = 0; i < NUM_SAMPLES / 3; i++) begin
                x1 = test_x[i*3];
                x2 = test_x[i*3 + 1];
                x3 = test_x[i*3 + 2];
                # CLOCK_PERIOD;
            end
        `endif

        #(5)
        valid = 0;
    end

    always_ff @(posedge clk) begin
        valid_d1 <= valid;
        valid_d2 <= valid_d1;
    end

    // Monitor output 
    integer cntr = 0, match = 0, mismatch = 0;
    always_ff @(posedge clk) begin
        `ifdef FILTER1
            if (valid_d1 && cntr < NUM_SAMPLES) begin
                if(y1 == test_y[cntr]) match++; else mismatch++;
                cntr++;
                if (cntr == NUM_SAMPLES) begin
                    $display("Finish Time: %0t", $time);
                    $display("Match count: %0d; Mismatch count: %0d", match, mismatch);
                end
            end
        `elsif FILTER2
            if (valid_d2 && cntr < NUM_SAMPLES) begin
                if(y1 == test_y[cntr]) match++; else mismatch++;
                if(y2 == test_y[cntr+1]) match++; else mismatch++;
                cntr += 2;
                if (cntr == NUM_SAMPLES) begin
                    $display("Finish Time: %0t", $time);
                    $display("Match count: %0d; Mismatch count: %0d", match, mismatch);
                end
            end
        `elsif FILTER3
            if (valid_d2 && cntr < NUM_SAMPLES) begin
                if(y1 == test_y[cntr]) match++; else mismatch++;
                if(y2 == test_y[cntr+1]) match++; else mismatch++;
                if(y3 == test_y[cntr+2]) match++; else mismatch++;
                cntr += 3;
                if (cntr == NUM_SAMPLES) begin
                    $display("Finish Time: %0t", $time);
                    $display("Match count: %0d; Mismatch count: %0d", match, mismatch);
                end
            end
        `elsif FILTER4
            if (valid_d2 && cntr < NUM_SAMPLES) begin
                if(y1 == test_y[cntr]) match++; else mismatch++;
                if(y2 == test_y[cntr+1]) match++; else mismatch++;
                if(y3 == test_y[cntr+2]) match++; else mismatch++;
                cntr += 3;
                if (cntr == NUM_SAMPLES) begin
                    $display("Finish Time: %0t", $time);
                    $display("Match count: %0d; Mismatch count: %0d", match, mismatch);
                end
            end
        `endif
    end
endmodule
