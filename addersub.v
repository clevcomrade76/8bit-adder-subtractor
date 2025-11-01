module full_adder(
    input a,
    input b,
    input cin,
    output sum,
    output cout
);
    assign sum = a ^ b ^ cin;
    assign cout = (a & b) | (b & cin) | (a & cin);
endmodule

module adder_subtractor_8bit(
    input [7:0] a,
    input [7:0] b,
    input mode,
    output [7:0] sum,
    output cout,
    output overflow
);
    wire [7:0] b_xor;
    wire [7:0] carry;
    assign b_xor = b ^ {8{mode}};
    full_adder fa0 (.a(a[0]), .b(b_xor[0]), .cin(mode), .sum(sum[0]), .cout(carry[0]));
    full_adder fa1 (.a(a[1]), .b(b_xor[1]), .cin(carry[0]), .sum(sum[1]), .cout(carry[1]));
    full_adder fa2 (.a(a[2]), .b(b_xor[2]), .cin(carry[1]), .sum(sum[2]), .cout(carry[2]));
    full_adder fa3 (.a(a[3]), .b(b_xor[3]), .cin(carry[2]), .sum(sum[3]), .cout(carry[3]));
    full_adder fa4 (.a(a[4]), .b(b_xor[4]), .cin(carry[3]), .sum(sum[4]), .cout(carry[4]));
    full_adder fa5 (.a(a[5]), .b(b_xor[5]), .cin(carry[4]), .sum(sum[5]), .cout(carry[5]));
    full_adder fa6 (.a(a[6]), .b(b_xor[6]), .cin(carry[5]), .sum(sum[6]), .cout(carry[6]));
    full_adder fa7 (.a(a[7]), .b(b_xor[7]), .cin(carry[6]), .sum(sum[7]), .cout(carry[7]));
    assign cout = carry[7];
    assign overflow = carry[7] ^ carry[6];
endmodule

module binary_to_bcd_14bit(
    input [13:0] binary,  // Up to 9999
    output reg [3:0] thousands,
    output reg [3:0] hundreds,
    output reg [3:0] tens,
    output reg [3:0] ones
);
    integer i;
    always @(*) begin
        thousands = 4'd0;
        hundreds = 4'd0;
        tens = 4'd0;
        ones = 4'd0;
        for (i = 13; i >= 0; i = i - 1) begin
            if (thousands >= 5)
                thousands = thousands + 3;
            if (hundreds >= 5)
                hundreds = hundreds + 3;
            if (tens >= 5)
                tens = tens + 3;
            if (ones >= 5)
                ones = ones + 3;
            thousands = {thousands[2:0], hundreds[3]};
            hundreds = {hundreds[2:0], tens[3]};
            tens = {tens[2:0], ones[3]};
            ones = {ones[2:0], binary[i]};
        end
    end
endmodule

module seven_segment_decoder(
    input [3:0] digit,
    input is_minus,
    output reg [6:0] segments
);
    always @(*) begin
        if (is_minus) begin
            segments = 7'b0111111;  // Display minus sign
        end else begin
            case(digit)
                4'd0: segments = 7'b1000000;
                4'd1: segments = 7'b1111001;
                4'd2: segments = 7'b0100100;
                4'd3: segments = 7'b0110000;
                4'd4: segments = 7'b0011001;
                4'd5: segments = 7'b0010010;
                4'd6: segments = 7'b0000010;
                4'd7: segments = 7'b1111000;
                4'd8: segments = 7'b0000000;
                4'd9: segments = 7'b0010000;
                default: segments = 7'b1111111;
            endcase
        end
    end
endmodule

module display_multiplexer(
    input clk,
    input [3:0] digit0,
    input [3:0] digit1,
    input [3:0] digit2,
    input [3:0] digit3,
    input show_minus,
    output reg [3:0] an,
    output [6:0] seg
);
    reg [1:0] refresh_counter;
    reg [16:0] clock_divider;
    reg [3:0] current_digit;
    reg current_is_minus;
    
    always @(posedge clk) begin
        clock_divider <= clock_divider + 1;
        if (clock_divider == 0) begin
            refresh_counter <= refresh_counter + 1;
        end
    end
    
    always @(*) begin
        case(refresh_counter)
            2'b00: begin
                an = 4'b1110;
                current_digit = digit0;
                current_is_minus = 1'b0;
            end
            2'b01: begin
                an = 4'b1101;
                current_digit = digit1;
                current_is_minus = 1'b0;
            end
            2'b10: begin
                an = 4'b1011;
                current_digit = digit2;
                current_is_minus = 1'b0;
            end
            2'b11: begin
                an = 4'b0111;
                current_digit = digit3;
                current_is_minus = show_minus;
            end
        endcase
    end
    
    seven_segment_decoder decoder(
        .digit(current_digit),
        .is_minus(current_is_minus),
        .segments(seg)
    );
endmodule

module top_basys3(
    input clk,
    input [15:0] sw,
    input btnU,
    output [9:0] led,
    output [6:0] seg,
    output [3:0] an
);
    wire [7:0] a;
    wire [7:0] b;
    wire mode;
    wire [7:0] result;
    wire cout;
    wire overflow;
    wire [8:0] full_result;
    wire [13:0] magnitude;  // Up to 9999
    wire is_negative;
    wire [3:0] thousands;
    wire [3:0] hundreds;
    wire [3:0] tens;
    wire [3:0] ones;
    
    assign a = sw[15:8];
    assign b = sw[7:0];
    assign mode = btnU;
    
    adder_subtractor_8bit adder_sub(
        .a(a),
        .b(b),
        .mode(mode),
        .sum(result),
        .cout(cout),
        .overflow(overflow)
    );
    
    // Handle negative results for subtraction
    assign is_negative = mode & ~cout;
    
    // Calculate the actual 9-bit result
    assign full_result = {cout, result};
    
    // For negative: take 2's complement of 8-bit result
    wire [7:0] negated_result;
    assign negated_result = ~result + 8'd1;
    
    // Select magnitude based on mode and sign
    assign magnitude = is_negative ? {6'd0, negated_result} : {5'd0, full_result};
    
    binary_to_bcd_14bit bcd_converter(
        .binary(magnitude),
        .thousands(thousands),
        .hundreds(hundreds),
        .tens(tens),
        .ones(ones)
    );
    
    display_multiplexer display(
        .clk(clk),
        .digit0(ones),
        .digit1(tens),
        .digit2(hundreds),
        .digit3(thousands),
        .show_minus(is_negative),
        .an(an),
        .seg(seg)
    );
    
    assign led[7:0] = result;
    assign led[8] = cout;
    assign led[9] = overflow;
endmodule