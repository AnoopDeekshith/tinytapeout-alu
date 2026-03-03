/*
 * Copyright (c) 2024 Anoop Deekshith R
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_example (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

    wire [3:0] A      = ui_in[3:0];
    wire [3:0] B      = ui_in[7:4];
    wire [2:0] opcode = uio_in[2:0];

    reg [3:0] result;
    reg       carry;

    always @(*) begin
        carry = 1'b0;
        case (opcode)
            3'b000: {carry, result} = A + B;
            3'b001: {carry, result} = A - B;
            3'b010: result = A & B;
            3'b011: result = A | B;
            3'b100: result = A ^ B;
            3'b101: result = ~A;
            3'b110: result = A << 1;
            3'b111: result = A >> 1;
            default: result = 4'b0;
        endcase
    end

    wire zero_flag     = (result == 4'b0);
    wire negative_flag = result[3];

    assign uo_out[3:0] = result;
    assign uo_out[4]   = zero_flag;
    assign uo_out[5]   = carry;
    assign uo_out[6]   = negative_flag;
    assign uo_out[7]   = 1'b0;

    wire _unused = &{ena, clk, rst_n, uio_in[7:3]};

endmodule
