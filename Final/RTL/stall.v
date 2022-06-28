module stalling_design(clk,rst,stall,ps_clk_stall,pm_add,dm_add,wrb,fetch_clk,decode_clk,execute_clk,execute1_clk);
input clk,rst,stall,wrb,ps_clk_stall;
input[15:0]dm_add,pm_add;
reg fetch_en=0,decode_en=0,execute_en=0,execute1_en=0;
output wire fetch_clk,decode_clk,execute_clk,execute1_clk;
wire [2:0]A;
reg[2:0] A_p;
assign fetch_clk=fetch_en & clk;
assign decode_clk=decode_en& clk;
assign execute_clk=execute_en & clk;
assign execute1_clk=execute1_en & clk;
assign A[0]= (dm_add[15]|dm_add[14]|dm_add[13]|dm_add[12])&(wrb);
assign A[1]= (dm_add[15]|dm_add[14]|dm_add[13]|dm_add[12])&(~wrb);
assign A[2]= (pm_add[15]|pm_add[14]|pm_add[13]|pm_add[12]);
always @(negedge clk or negedge rst) begin
    A_p[1:0]<=A[1:0];
    A_p[2]<=A[2]|(~ps_clk_stall);
    if(!rst) begin
        fetch_en<=1;
        decode_en<=1;
        execute_en<=1;
        execute1_en<=1;
    end
    else begin
        fetch_en<=stall&ps_clk_stall;
        if(A[2]|A[1]|A[0]) begin
            decode_en<=stall;
        end else if(~ps_clk_stall) begin
            decode_en<=ps_clk_stall;
        end else if(A_p[2]|A_p[1]|A_p[0]) begin
            decode_en<=1'b1;
        end else begin
            decode_en<=fetch_en;
        end
        if(A[1]|A[0]) begin
            execute_en<=stall;
        end else if(A_p[1]|A_p[0]) begin 
            execute_en<=1'b1;
        end else begin
            execute_en<=decode_en;
        end
        if(A[0]) begin
            execute1_en<=stall;
        end else if(A_p[0]) begin
            execute1_en<=1'b1;
        end else begin
            execute1_en<=execute_en;
        end

    end
end
endmodule
/*
module t_stalling_design();
reg clk,rst,stall,rwb;
reg[15:0] dm_add,pm_add ;
wire  fetch_clk,decode_clk,execute_clk,execute1_clk;
stalling_design inst(clk,rst,stall,pm_add,dm_add,rwb,fetch_clk,decode_clk,execute_clk,execute1_clk);
initial begin 
    clk=1;
    forever #5 clk=~clk;
end
initial begin
    stall=1;
    #20 stall=0;
    #20 stall=1;
    #20 stall=0;
    #20 stall=1;
    #20 stall=0;
    #20 stall=1;
    #20 stall=0;
    #20 stall=1;
end
initial begin
    rst =1;
    #1 rst=0;
    #2 rst=1;
end
initial begin
    rwb<=1;
    #100 rwb<=0;

end
initial begin
      	pm_add=16'h01FF;
	#20 pm_add=16'h0FFF;
	#20 pm_add=16'h01FF;
	#20 pm_add=16'h0ABC;
	#10 pm_add=16'h0123;

    //#40 pm_add=16'h1FAB;
    //#20 pm_add=16'h0FFF;
    //#10 pm_add=16'h4AFB;
end

initial begin
        dm_add=16'h0FFF;
    #20 dm_add=16'h1FFF;
    #20 dm_add=16'h0FFF;
    #20 dm_add=16'hFA1B;
    #20 dm_add=16'h0FFF;
    #20 dm_add=16'h3FAC;
    #20 dm_add=16'h0001;
    #20 dm_add=16'h3333;
end
endmodule
*/