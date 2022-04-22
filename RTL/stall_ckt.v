module stalling_design(clk,stall,pm_add,dm_add,rwb,fetch_clk,decode_clk,execute_clk,execute1_clk);
input clk,stall,rwb;
input[15:0]dm_add,pm_add;
reg fetch_en=0,decode_en=0,execute_en=0,execute1_en=0;
output wire fetch_clk,decode_clk,execute_clk,execute1_clk;
wire [2:0]A;
assign fetch_clk=fetch_en & clk;
assign decode_clk=decode_en& clk;
assign execute_clk=execute_en & clk;
assign execute1_clk=execute1_en & clk;
assign A[0]= (dm_add[15]|dm_add[14]|dm_add[13]|dm_add[12])&(~rwb);
assign A[1]= (dm_add[15]|dm_add[14]|dm_add[13]|dm_add[12])&(rwb);
assign A[2]= (pm_add[15]|pm_add[14]|pm_add[13]|pm_add[12]);
always @(negedge clk)begin
    fetch_en<=stall&~A[2];
    decode_en<=(fetch_en&~(A[1]|A[0]))|(stall&(A[1]&A[0]));
    execute_en<=(decode_en&!A[0])|(stall&A[0]);
    execute1_en<=(execute_en&!A[0])|(stall&A[0]);
end
endmodule
/*
module t_stalling_design();
reg clk,stall,rwb;
reg[15:0] dm_add,pm_add ;
wire  fetch_clk,decode_clk,execute_clk,execute1_clk;
stalling_design inst(clk,stall,pm_add,dm_add,rwb,fetch_clk,decode_clk,execute_clk,execute1_clk);
initial begin 
    clk=1;
    forever #5 clk=~clk;
end
/*initial begin
    stall=1;
    #20 stall=0;
    #20 stall=1;
    #20 stall=0;
end
initial begin
    rwb<=0;
    #60 rwb<=1;

end
initial begin
      	pm_add=16'h01FF;
	#20 pm_add=16'h1FFF;
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
    #10 dm_add=16'h0FFF;
      #20 dm_add=16'h1A1B;
     #30 dm_add=16'h2FFF;
      #30 dm_add=16'h0FAC;
end
endmodule//

initial begin
	rwb=0;
end

initial begin
	stall=1;
	#20 stall=0;
	#20 stall=1;
end


initial begin
	pm_add=16'h0FFF;
	#20 pm_add=16'h1FFF;
	#20 pm_add=16'h0123;
end


initial begin
	dm_add=16'h0FFF;
        #20 dm_add=16'h1AFF;
        #20 dm_add=16'h0ABC;
end	
endmodule
*/