// -----------------------------------------------------------------------------
// 4-input priority logic with four selectable priority orders
// -----------------------------------------------------------------------------
module fsa_priority_logic4 (
    input  logic [3:0] req,      // active-high requests from local ports
    input  logic [1:0] state,    // selects one of the four priority orders
    output logic [3:0] grant     // one-hot grant
);
    // helper: function returns the grant vector for a given permutation
    function automatic logic [3:0] do_encode (
        input logic [3:0] r,
        input int         a, b, c, d      // priority indices (highest→lowest)
    );
        logic [3:0] g;
        g = 4'b0000;
        if (r[a])       g[a] = 1'b1;
        else if (r[b])  g[b] = 1'b1;
        else if (r[c])  g[c] = 1'b1;
        else if (r[d])  g[d] = 1'b1;
        return g;
    endfunction

    // multiplex the four hard-wired permutations
    always_comb begin
        unique case (state)
            2'b00 : grant = do_encode(req, 3, 2, 1, 0);  // 3-2-1-0
            2'b01 : grant = do_encode(req, 0, 3, 2, 1);  // 0-3-2-1
            2'b10 : grant = do_encode(req, 1, 0, 3, 2);  // 1-0-3-2
            2'b11 : grant = do_encode(req, 2, 1, 0, 3);  // 2-1-0-3
            default: grant = 4'b0000;
        endcase
    end
endmodule


//==============================================================================
//  Fair-Switch-Arbiter (FSA) – 4-port Leaf Node
//==============================================================================
module fsa_leaf_node #(
    parameter INIT_PTR = 4'b0001          // first priority = 3>2>1>0
)(
    input  logic        clk,
    input  logic        rst,

    // local side --------------------------------------------------------------
    input  logic [3:0]  req,              // active-high requests
    output logic [3:0]  grant,            // one-hot grant (masked by ack)

    // tree interface ----------------------------------------------------------
    output logic        up_req,           // request to parent
    input  logic        ack,              // parent ack (1-cycle pulse)
    input  logic        update            // global pulse from root node
);

    //----------------------------------------------------------------------
    // 1. Rotating-priority pointer (4-bit one-hot)
    //----------------------------------------------------------------------
    logic [3:0] ptr;                      // ‘priority’ in the paper
    logic [3:0] grant_int;               // internal (before ack mask)

    always_ff @(posedge clk) begin
        if (rst)  
            ptr <= INIT_PTR;
        else if (ack)         
            ptr <= grant_int;      // rotate when request accepted
        // else hold
    end

    // convert one-hot pointer to the 2-bit “state” used by the priority logic
    logic [1:0] state;
    always_comb begin
        unique case (ptr)
            4'b0001: state = 2'b00;      // 3210   (Table-1)
            4'b0010: state = 2'b01;      // 0321
            4'b0100: state = 2'b10;      // 1032
            4'b1000: state = 2'b11;      // 2103
            default: state = 2'b00;      // should never happen
        endcase
    end

    //----------------------------------------------------------------------
    // 2. Priority logic (purely combinational)
    //----------------------------------------------------------------------

    fsa_priority_logic4 u_prio (
        .req   (req),
        .state (state),
        .grant (grant_int)
    );

    // only advertise the grant when parent accepted this leaf
    assign grant = ack ? grant_int : 4'b0000;

    //----------------------------------------------------------------------
    // 3. Lock flag  – have we served every local requester?
    //----------------------------------------------------------------------
    logic lock_set, lock;

    assign lock_set =  ack & ( grant[0] |
                              (grant[1] &  ~req[0]) |
                              (grant[2] &  ~req[1] &  ~req[0]) |
                              (grant[3] &  ~req[2] &  ~req[1] & ~req[0]));

    always_ff @(posedge clk) begin
        if (rst)        
            lock <= 1'b0;
        else if (update)   
            lock <= 1'b0;  
        else if (lock_set) 
            lock <= 1'b1; 
    end

    //----------------------------------------------------------------------
    // 4. Upward request 
    //----------------------------------------------------------------------
    assign up_req = ~lock & |req;

endmodule
