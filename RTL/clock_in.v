module stall_clk(
    input clk_in, stallb_en, rst,
    output wire clk_f, clk_dcd, clk_exe, clk_rf);
reg en_ff_1,en_ff_2,en_ff_3,en_ff_4;
assign clk_f=en_ff_1&clk_in;
assign clk_dcd=en_ff_2&clk_in;
assign clk_exe=en_ff_3&clk_in;
assign clk_rf=en_ff_4&clk_in;
always @(negedge clk_in or negedge rst) begin
    if(!rst) begin
        en_ff_1<=0;
        en_ff_2<=0;
        en_ff_3<=0;
        en_ff_4<=0;
    end
    else begin
        en_ff_1<=stallb_en;
        en_ff_2<=en_ff_1;
        en_ff_3<=en_ff_2;
        en_ff_4<=en_ff_3;
    end
end
endmodule
/*
module T_stall_clk();
reg clk_in, stallb_en,rst;
wire clk_f, clk_dcd, clk_exe;
stall_clk inst_1(clk_in, stallb_en,rst,clk_f, clk_dcd, clk_exe);
initial begin
    clk_in=0;
    forever #5 clk_in=~clk_in;
end
initial begin
    stallb_en=1;
    forever begin
        #100 stallb_en=0;
        #30 stallb_en=1;
    end
end
initial begin
    rst=1;
    #1 rst=0;
    #1 rst=1;
end
endmodule //clock_in
*/