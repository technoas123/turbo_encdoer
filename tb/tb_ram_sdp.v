`timescale 1ns / 1ps

module tb_ram_sdp;

    localparam DATA_WIDTH = 2;
    localparam ADDR_WIDTH = 12;

    reg                   clk;
    reg                   we;
    reg  [ADDR_WIDTH-1:0] waddr;
    reg  [DATA_WIDTH-1:0] din;
    reg  [ADDR_WIDTH-1:0] raddr;
    wire [DATA_WIDTH-1:0] dout;

    integer errors;

    ram_sdp #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .clk   (clk),
        .we    (we),
        .waddr (waddr),
        .din   (din),
        .raddr (raddr),
        .dout  (dout)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task write_word;
        input [ADDR_WIDTH-1:0] address;
        input [DATA_WIDTH-1:0] value;
        begin
            @(negedge clk);
            we    = 1'b1;
            waddr = address;
            din   = value;

            @(posedge clk);
            #1;
        end
    endtask

    task check_read;
        input [ADDR_WIDTH-1:0] address;
        input [DATA_WIDTH-1:0] expected;
        reg [DATA_WIDTH-1:0] previous_dout;
        begin
            @(negedge clk);
            previous_dout = dout;
            raddr = address;

            // A synchronous-read RAM should not change dout immediately.
            #1;
            if (dout !== previous_dout) begin
                $display("[ERROR] dout changed before the read clock edge: addr=%0d",
                         address);
                errors = errors + 1;
            end

            @(posedge clk);
            #1;
            if (dout !== expected) begin
                $display("[ERROR] addr=%0d expected=%b got=%b",
                         address, expected, dout);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        errors = 0;
        we     = 1'b0;
        waddr  = {ADDR_WIDTH{1'b0}};
        din    = {DATA_WIDTH{1'b0}};
        raddr  = {ADDR_WIDTH{1'b0}};

        // Write test values, including high addresses used by the encoder.
        write_word(12'd0,    2'b11);
        write_word(12'd1,    2'b01);
        write_word(12'd2,    2'b10);
        write_word(12'd3,    2'b00);
        write_word(12'd56,   2'b11);
        write_word(12'd2395, 2'b01);
        write_word(12'd4095, 2'b10);

        @(negedge clk);
        we    = 1'b0;
        waddr = 12'd0;
        din   = 2'b00;

        check_read(12'd0,    2'b11);
        check_read(12'd1,    2'b01);
        check_read(12'd2,    2'b10);
        check_read(12'd3,    2'b00);
        check_read(12'd56,   2'b11);
        check_read(12'd2395, 2'b01);
        check_read(12'd4095, 2'b10);

        if (errors == 0)
            $display("[PASS] ram_sdp: all read and latency checks passed.");
        else
            $display("[FAIL] ram_sdp: %0d error(s).", errors);

        $finish;
    end

endmodule