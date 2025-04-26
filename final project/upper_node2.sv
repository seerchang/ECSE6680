// 2×2 prefix fixed-priority arbiter
module prefix_fpa2 (
    input  logic [1:0] req,      // request inputs
    output logic [1:0] grant     // one-hot grant outputs
);
    assign grant[0] = req[0];          
    assign grant[1] = req[1] & ~req[0];   

endmodule

// 4×4 prefix fixed-priority arbiter
module prefix_fpa4 (
    input  logic [3:0] req,      // request inputs
    output logic [3:0] grant     // one-hot grant outputs
);
    logic inv_r [3:0];
    genvar i;
    generate
      for (i = 0; i < 4; i++) begin
        assign inv_r[i] = ~req[i];
      end
    endgenerate

    logic pre [3:0];
    assign pre[0] = 1'b1;                   
    assign pre[1] = inv_r[0];                          
    assign pre[2] = inv_r[0] & inv_r[1];              
    assign pre[3] = inv_r[0] & inv_r[1] & inv_r[2];   
    // eq. (8):
    generate
      for (i = 0; i < 4; i++) begin
        assign grant[i] = req[i] & pre[i];
      end
    endgenerate
endmodule

// internal node: 4 children → 1 parent
module fsa_internal_node (
    input  logic [3:0]  up_req_i,   // requests from 4 lower nodes
    input  logic        ack_i,      // ack from the parent node
    output logic [3:0]  ack_o,      // acks back to the 4 children
    output logic        up_req_o    // aggregated request to parent
);
    logic [3:0] grant;
    // compute one‐hot grant among the 4 up_req_i
    prefix_fpa4 u_fpa4 (
        .req  (up_req_i),
        .grant(grant)
    );

    // only the granted child sees ack_i
    assign ack_o    = grant & {4{ack_i}};

    // forward “any request pending” upstream
    assign up_req_o = |up_req_i;

endmodule


// root node (2×2): 2 children → no parent above
module fsa_root_node2 (
    input  logic [1:0] req_i,      // aggregated requests from 2 internal groups
    output logic [1:0] ack_o,      // acks back to those 2 groups
    output logic       update      // indicates this level’s arbitration happened
);
    // compute one‐hot grant among the 2 req_i
    prefix_fpa2 u_fpa2 (
        .req  (req_i),
        .grant(ack_o)
    );
    
    // update pulses when there is at least one request
    assign update = ~(|req_i);
endmodule
