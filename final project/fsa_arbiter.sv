module fsa_arbiter_32(
    input  logic clk, rst,
    input  logic [31:0] req,
    output logic [31:0] grant
);
    // Signals between leaf and internal nodes
    logic [7:0] up_req_leaf;
    logic [7:0] ack_from_internal;

    // Signals between internal and root nodes
    logic [1:0] up_req_internal;
    logic [1:0] ack_from_root;

    logic update;

    // Leaf nodes (8 of them)
    genvar i;
    generate
        for (i = 0; i < 8; i++) begin : gen_ln
            fsa_leaf_node leaf_inst (
                .clk(clk), .rst(rst), 
                .req(req[4*i +: 4]),
                .grant(grant[4*i +: 4]),
                .ack(ack_from_internal[i]),
                .update(update),
                .up_req(up_req_leaf[i])
            );
        end
    endgenerate

    // Internal nodes (2 of them, each handling 4 leaf nodes)
    fsa_internal_node internal_node0 (
        .up_req_i({up_req_leaf[3], up_req_leaf[2], up_req_leaf[1], up_req_leaf[0]}),
        .ack_o({ack_from_internal[3], ack_from_internal[2], ack_from_internal[1], ack_from_internal[0]}),
        .ack_i(ack_from_root[0]),
        .up_req_o(up_req_internal[0])
    );

    fsa_internal_node internal_node1 (
        .up_req_i({up_req_leaf[7], up_req_leaf[6], up_req_leaf[5], up_req_leaf[4]}),
        .ack_o({ack_from_internal[7], ack_from_internal[6], ack_from_internal[5], ack_from_internal[4]}),
        .ack_i(ack_from_root[1]),
        .up_req_o(up_req_internal[1])
    );

    // 2x2 Root node 
    fsa_root_node2 root_node (
        .req_i({up_req_internal[1], up_req_internal[0]}),
        .ack_o({ack_from_root[1], ack_from_root[0]}),
        .update(update)
    );

endmodule