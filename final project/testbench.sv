/*
 * Testbench for 32-input arbiter
 */

module arbiter_tb;
    // Inputs
    logic [31:0] req;
    // Outputs
    logic [31:0] grant;

    // Clock and reset
    logic clk;
    logic rst;

    // Instantiate DUT
    fsa_arbiter_32 u_arb (
    .clk(clk), .rst(rst), 
    .req(req), 
    .grant(grant));

    // Parameters
    parameter CYCLES = 10000;

    // Counters for metrics
    integer grant_count [31:0];
    integer cycle_count;

    // Variables for fairness metrics
    real mean;
    real std_dev;
    real jains_index;
    integer i;

    // Clock generation
    always #5 clk = ~clk;

    // Reset
    initial begin
    clk = 0;
    rst = 1;
    #15 rst = 0;
    end

    // Main test
    initial begin
    req = 0;
    cycle_count = 0;
    for (i = 0; i < 32; i++) grant_count[i] = 0;

    // Run uniform requests test
    $display("Starting uniform request test");
    run_test();

    $display("All tests completed");
    //$finish;
    end

    // Task to run a test scenario
    task run_test();
    begin
        cycle_count = 0;
        for (i = 0; i < 32; i++) grant_count[i] = 0;

        while (cycle_count < CYCLES) begin
            @(posedge clk);
            cycle_count++;

            // Generate requests
            req = $urandom_range(0, 2**32-1);
            // req = 32'hFFFFFFFF;

            // Allow grant to propagate
            @(negedge clk);

            // Sample grant
            for (i = 0; i < 32; i++) begin
                if (grant[i]) grant_count[i]++;
            end
        end

        // Compute metrics
        compute_metrics();
    end
    endtask

    // Task to compute and display fairness metrics
    task compute_metrics();
    real sum, sum_sq;
    real denom;
    begin
        // Mean grants per client
        sum = 0;
        for (i = 0; i < 32; i++) sum += grant_count[i];
        mean = sum/32.0;

        // Standard deviation
        sum_sq = 0;
        for (i = 0; i < 32; i++) sum_sq += (grant_count[i] - mean)**2;
        std_dev = $sqrt(sum_sq/32.0);

        // Jain's fairness index: ( (sum)^2 ) / (N * sum_sq_grants)
        denom = 0;
        for (i = 0; i < 32; i++) denom += grant_count[i]**2;
        jains_index = (sum*sum)/(32.0 * denom);

        // Display
        $display(" Jain's index = %0.4f", jains_index);
        $display(" Grant counts: ");
        for (i = 0; i < 32; i++)
        $display("  client %0d: %0d", i, grant_count[i]);
    end
    endtask

endmodule
