//3 June
module PS_top (clk,clk_fetch,clk_dcd,clk_exe,clk_rf,rst,interrupt,stallb,shf_ps_sz,shf_ps_sv,mul_ps_mv,mul_ps_mn,alu_ps_ac,alu_ps_an,alu_ps_av,alu_ps_az,alu_ps_compd,pm_ps_op,bc_dt,ps_dmiaddinst,ps_pm_cslt,ps_pm_wrb,ps_pm_add,ps_cu_float,ps_cu_trunc,ps_alu_en,ps_mul_en,ps_shf_en,ps_mul_otreg,mul_ps_mu,mul_ps_mi,ps_alu_ci,alu_ps_au,alu_ps_as,alu_ps_ai,ps_alu_sat,ps_alu_hc,ps_mul_cls,ps_mul_sc,ps_shf_cls,ps_alu_sc1,ps_alu_sc2,ps_mul_dtsts,ps_xb_raddy,ps_xb_w_cuEn,ps_xb_wadd,ps_xb_raddx,ps_xb_w_bcEn,ps_dg_wrt_en,ps_dg_rd_add,ps_dg_wrt_add,ps_bc_immdt,ps_dm_cslt,ps_dm_wrb,ps_dg_en,ps_dg_dgsclt,ps_dg_mdfy,ps_dg_iadd,ps_dg_madd,ps_bc_drr_slct,ps_bc_di_slct,ps_bc_dt,dg_ps_add,ps_dg_immdt,ps_clk_stall);


input clk,clk_fetch,clk_dcd,clk_exe,clk_rf,rst,interrupt,stallb;
input shf_ps_sz,shf_ps_sv,mul_ps_mv,mul_ps_mn,alu_ps_ac,alu_ps_an,alu_ps_av,alu_ps_az,alu_ps_compd; 
input[31:0] pm_ps_op;
input[15:0] bc_dt;
input[15:0] dg_ps_add;
input alu_ps_au,alu_ps_as,alu_ps_ai;
output ps_dmiaddinst;
output ps_pm_cslt,ps_pm_wrb;
output [15:0] ps_pm_add;
output ps_cu_float,ps_cu_trunc, ps_alu_en, ps_mul_en, ps_shf_en, ps_mul_otreg,mul_ps_mu,mul_ps_mi;
output ps_alu_ci,ps_alu_sat;
output[1:0] ps_alu_hc, ps_mul_cls, ps_mul_sc, ps_shf_cls,ps_alu_sc2;
output[2:0] ps_alu_sc1;
output[3:0] ps_mul_dtsts, ps_xb_raddy;                       
output[2:0] ps_xb_w_cuEn;
output[3:0] ps_xb_wadd;
output[3:0] ps_xb_raddx;
output ps_xb_w_bcEn,ps_dg_wrt_en;
output[4:0] ps_dg_rd_add,ps_dg_wrt_add;
output[15:0] ps_bc_immdt;
output ps_dm_cslt,ps_dm_wrb;
output ps_dg_en,ps_dg_dgsclt,ps_dg_mdfy;
output[2:0] ps_dg_iadd,ps_dg_madd;
output[1:0] ps_bc_drr_slct,ps_bc_di_slct;
output[15:0] ps_bc_dt,ps_dg_immdt;
output ps_clk_stall;


//Internal Sginals
reg cnd_tru, ps_idle,ps_pcstck_pntr;
reg[6:0] ps_mode1;
reg[15:0] ps_faddr,ps_daddr,ps_pc;
reg[15:0] dg_ps_add_dly;
reg[15:0] ps_astat;						//ASTAT work left -> compare
reg[15:0] ps_lcntr,ps_curlcntr,ps_laddr;
reg[15:0] ps_pcstck;
reg[2:0] ps_stcky;
reg ps_pshstck_dly,ps_popstck_dly;
reg[15:0] ps_rd_dt;
reg ps_cmpt_dly;
reg ps_jmp,ps_jmp_dly;
reg ps_loop_dly;
reg ps_call,ps_rtrn,ps_rtrn_dly;

//Used for compute decoding
reg cpt_en;
reg ps_alu_ci,ps_alu_sat,ps_cu_trunc;

wire ps_alu_en, ps_mul_en, ps_shf_en, ps_cu_float, ps_mul_otreg;
wire[1:0] ps_alu_hc, ps_mul_cls, ps_mul_sc, ps_shf_cls;
wire[2:0] ps_alu_sc1;
wire[1:0] ps_alu_sc2;
wire[3:0] ps_mul_dtsts, ps_xb_rd_a0, ps_xb_raddy;
wire[2:0] ps_xb_w_cuEn;
wire[3:0] ps_xb_wrt_a;

//Used for condition decoding
reg cnd_en,cnt_en;
reg[4:0] opc_cnd;
reg[7:0] astat_bts;

wire cnd_stat;

//Used for Ureg address decoding
reg ps_pshstck,ps_popstck,ps_imminst,ps_dminst,ps_loop,ps_urgtrnsinst,ps_dmimminst,ps_dmiaddinst;
reg[7:0] ps_ureg1_add,ps_ureg2_add;

wire ps_xb_w_bcEn,ps_dg_wrt_en,ps_wrt_en;
wire[3:0] ps_xb_dm_rd_add, ps_xb_dm_wrt_add;
wire[4:0] ps_dg_rd_add,ps_rd_add,ps_dg_wrt_add,ps_wrt_add;

//Used for memory
reg ps_pm_cslt,ps_pm_wrb;
reg ps_dm_cslt,ps_dm_wrb;
reg [15:0] ps_pm_add;

//Used for RF specifically
reg[3:0] ps_xb_raddx;
reg[3:0] ps_xb_wadd;

//Used for bus connect
reg[15:0] ps_bc_immdt,ps_bc_dt;

wire[1:0] ps_bc_drr_slct,ps_bc_di_slct;

//Used for DAG
reg ps_dg_en,ps_dg_dgsclt,ps_dg_mdfy;
reg[2:0] ps_dg_iadd,ps_dg_madd;
reg[15:0] ps_dg_immdt;

//Used for jump, call etc.
reg[15:0] dg_ps_add_p,ps_daddr_p;
reg stallb_p,stallb_p_f,stallb_p_dcd,stallb_p_exe,stallb_p_rf;

//Used for loop
wire ps_clk_stall;



//Compute Decoing hardware
cmpt_inst_dcdr cpt(clk_exe,rst,cpt_en,pm_ps_op[26],pm_ps_op[25:5], ps_alu_en,ps_mul_en, ps_shf_en, ps_cu_float, ps_alu_sc1,ps_alu_sc2, ps_mul_otreg, ps_alu_hc, ps_mul_cls, ps_mul_sc, ps_shf_cls, ps_xb_w_cuEn,ps_mul_dtsts, ps_xb_rd_a0, ps_xb_raddy, ps_xb_wrt_a);

//Condition decoding hardware
cnd_dcdr cnd(cnd_en,opc_cnd,cnd_stat,astat_bts);

//Ureg related decoding hardware
ureg_add_dcdr urdcd(clk_dcd,ps_pshstck,ps_popstck,ps_imminst,ps_dminst,ps_dmiaddinst,ps_urgtrnsinst,ps_loop,ps_dm_wrb,ps_ureg1_add,ps_ureg2_add,ps_xb_w_bcEn,ps_dg_wrt_en,ps_wrt_en,ps_xb_dm_rd_add,ps_xb_dm_wrt_add,ps_dg_rd_add,ps_rd_add,ps_dg_wrt_add,ps_wrt_add);

//Bus connect selection logic
bc_slct_cntrl bsc(clk_dcd,ps_pshstck,ps_popstck,ps_imminst,ps_dmimminst,ps_dmiaddinst,ps_dminst,ps_urgtrnsinst,ps_loop,ps_dm_wrb,ps_ureg1_add[7:4],ps_ureg2_add[7:4],ps_bc_drr_slct,ps_bc_di_slct);

always @(negedge clk_fetch or negedge rst) begin
	if(!rst) begin
		stallb_p_f<=1'b1;
	end
	else begin
		stallb_p_f<=stallb;
	end
end

always @(negedge clk_dcd or negedge rst) begin
	if(!rst) begin
		stallb_p_dcd<=1'b1;
	end
	else begin
		stallb_p_dcd<=stallb;
	end
end

always @(negedge clk_exe or negedge rst) begin
	if(!rst) begin
		stallb_p_exe<=1'b1;
	end
	else begin
		stallb_p_exe<=stallb;
	end
end

always @(negedge clk_rf or negedge rst) begin
	if(!rst) begin
		stallb_p_rf<=1'b1;
	end
	else begin
		stallb_p_rf<=stallb;
	end
end

always @ (posedge clk_fetch or negedge rst) begin
	if(!rst) begin
		ps_faddr <=16'b0;
		ps_call <= 1'b0;
		ps_rtrn <= 1'b0;
		ps_rtrn_dly <= 1'b0;
		ps_jmp <= 1'b0;
		ps_jmp_dly <= 1'b0;
		ps_loop_dly<=1'b0;
	end else begin

		ps_call<=pm_ps_op[28] & ~pm_ps_op[27] & pm_ps_op[26] & cnd_tru;
		ps_rtrn<=(pm_ps_op[31:24]==8'b1) & !ps_idle & !ps_stcky[2] & !ps_jmp & !ps_jmp_dly & !ps_rtrn & !ps_rtrn_dly;
		ps_rtrn_dly<= ps_rtrn;
		ps_jmp<=pm_ps_op[28] & ~pm_ps_op[27] & cnd_tru;
		ps_jmp_dly<=ps_jmp;
		ps_loop_dly<=ps_loop;

		if(ps_jmp) begin
			ps_faddr<=dg_ps_add_dly;
		end else if(ps_rtrn|((cnt_en)&(ps_curlcntr!=1'b1)&(ps_faddr==ps_laddr))) begin
			ps_faddr<= ps_pcstck;
		end else if(!ps_idle & !ps_stcky[2]) begin
			ps_faddr <= ps_faddr + 16'b1;
		end
	end
end


always@(posedge clk_dcd or negedge rst) begin

	dg_ps_add_dly<=(dg_ps_add&{16{stallb_p}})|(dg_ps_add_p&{16{~stallb_p}});
	stallb_p<=stallb_p_f & stallb_p_dcd & stallb_p_exe & stallb_p_rf;
	if(!ps_idle & !ps_stcky[2]) begin
		ps_daddr_p<=ps_daddr;
		ps_daddr <= ps_faddr;	
	end

	//RF write address muxing
	if(cpt_en) begin
		ps_xb_wadd<= ps_xb_wrt_a;
	end else begin
		ps_xb_wadd<= ps_xb_dm_wrt_add;
	end

	//Immediate data
	if(ps_imminst | ps_dmimminst | ps_dmiaddinst) begin
		ps_bc_immdt<=pm_ps_op[15:0];
	end

	//LADDR stack writing
	if(!rst) begin
		ps_laddr<=16'b0;
	end else begin
		if(ps_loop)	begin
			ps_laddr<=pm_ps_op[15:0];
		end
	end

end

always @(posedge clk_exe or negedge rst) begin
	dg_ps_add_p<=dg_ps_add;
    if(!ps_idle & !ps_stcky[2]) begin
		ps_pc <= ps_daddr;
	end
end

always @(posedge clk_rf or negedge rst) begin
	if(!rst) begin

		ps_stcky<=3'b001;						//ps_stcky[0] -> empty flag, ps_stcky[1] -> full flag, ps_stcky[2] -> pc sctack overflow
		ps_pcstck_pntr<= 1'b0;
		ps_pshstck_dly<= 1'b0;
		ps_popstck_dly<= 1'b0;
		ps_curlcntr<=16'b0;

	end else begin

		ps_pshstck_dly<= ps_pshstck;
		ps_popstck_dly<= ps_popstck;
		

		if( (ps_popstck_dly | ps_rtrn) & !ps_stcky[0]) begin	
			ps_pcstck_pntr<=ps_pcstck_pntr-1'b1;
		end else if( (ps_pshstck_dly | ps_call) & !ps_stcky[1]) begin
			ps_pcstck_pntr<=ps_pcstck_pntr+1'b1;
		end

		if(ps_loop_dly) begin
			ps_curlcntr<=bc_dt;
		end else if(cnt_en&(ps_faddr==ps_laddr)) begin
			ps_curlcntr<=ps_curlcntr-1'b1;
		end

		ps_stcky[0]<= (ps_stcky[1] & (ps_popstck_dly | ps_rtrn)) | (ps_stcky[0] & !(ps_pshstck_dly | ps_call));
		ps_stcky[1]<= (ps_stcky[0] & (ps_pshstck_dly | ps_call)) | (ps_stcky[1] & !(ps_popstck_dly | ps_rtrn));
		ps_stcky[2]<= (ps_stcky[1] & (ps_pshstck_dly | ps_call)) | ps_stcky[2];

	end

end
reg[1:0] cnt;
always @(posedge clk or negedge rst) begin
	if(!rst)
		cnt<=2'b11;
	else begin
		if(ps_loop)//cnt_en&(ps_faddr==ps_laddr))
			cnt<=2'b00;
		else if(cnt!=2'b11)
			cnt<=cnt+1;
	end
end	
assign ps_clk_stall=cnt[1]&cnt[0];

always @(*) begin

	//Conditional decoding
	opc_cnd= pm_ps_op[4:0];
	cnd_en= pm_ps_op[31]&(~(pm_ps_op[29:26]==4'b1110));
	astat_bts= { shf_ps_sz, shf_ps_sv, mul_ps_mv, mul_ps_mn, alu_ps_ac, alu_ps_an, alu_ps_av, alu_ps_az };   		//ASTAT bits given to condition checking module
	cnd_tru= ( cnd_stat | !cnd_en ) & !ps_idle & !ps_stcky[2] & !ps_jmp & !ps_jmp_dly & !ps_rtrn & !ps_rtrn_dly;
	cnt_en=|ps_curlcntr;

	//Instruction Identification
	if(!pm_ps_op[30] & !ps_idle & !ps_stcky[2] & !ps_jmp & !ps_jmp_dly & !ps_rtrn & !ps_rtrn_dly) begin
		ps_pshstck= (pm_ps_op[29:24]==6'b000010);                       //Push PCstck inst
		ps_popstck= (pm_ps_op[29:24]==6'b000011);			//Pop PCstack inst
		ps_imminst= (pm_ps_op[29:26]==4'b0011);				//Immediate Inst
		ps_dmimminst = (pm_ps_op[29:26]==4'b1010);			//DM immediate instruction
		ps_dmiaddinst = (pm_ps_op[29:26]==4'b1110);			//DM with immediate address
		ps_dminst= (pm_ps_op[29:26]==4'b1001) & cnd_tru;		//DM<->ureg inst
		ps_urgtrnsinst= (pm_ps_op[29:26]==4'b0001) & cnd_tru;		//Between Ureg inst
		ps_loop = (pm_ps_op[29:26]==4'b0010);
	end else begin
		ps_pshstck= 1'b0;
		ps_popstck= 1'b0;
		ps_imminst= 1'b0;
		ps_dminst= 1'b0;
		ps_urgtrnsinst= 1'b0;
		ps_dmimminst = 1'b0;
		ps_dmiaddinst = 1'b0;
		ps_loop = 1'b0;
	end

	//Compute decoding
	cpt_en= pm_ps_op[30] & cnd_tru;
	ps_alu_ci= ps_astat[3];
	ps_alu_sat= ps_mode1[0];
	ps_cu_trunc=ps_mode1[1];


	//PM
	ps_pm_add= ps_faddr;
	ps_pm_cslt= !ps_idle & !ps_stcky[2];
	ps_pm_wrb=1'b0;

	//DAG decoding
	ps_dg_en= pm_ps_op[29] & cnd_tru;
	ps_dg_dgsclt= pm_ps_op[28];
	ps_dg_mdfy= pm_ps_op[28];
	ps_dg_immdt=pm_ps_op[15:0];
	if(ps_dmimminst) begin
		ps_dg_iadd = pm_ps_op[18:16];
		ps_dg_madd = pm_ps_op[21:19];
	end
	else if(ps_dmiaddinst) begin
		ps_dg_iadd = pm_ps_op[26:24];
		ps_dg_madd = 3'b0;
	end
	else begin
		ps_dg_iadd = pm_ps_op[12:10];
		ps_dg_madd = pm_ps_op[9:7];
	end


	//DM
	ps_dm_cslt= ps_dminst | ps_dmimminst | ps_dmiaddinst;
	if(ps_dminst) begin
		ps_dm_wrb = pm_ps_op[6];
	end
	else if(ps_dmiaddinst) begin
		ps_dm_wrb = pm_ps_op[31];
	end
	else begin
		ps_dm_wrb = 1'b1;
	end



	//Ureg Addresses
	ps_ureg1_add= pm_ps_op[23:16];
	ps_ureg2_add= pm_ps_op[15:8];

	//RF read address muxing
	if(cpt_en) begin
		ps_xb_raddx= ps_xb_rd_a0;	
	end else begin
		ps_xb_raddx= ps_xb_dm_rd_add;
	end

	//Read from ps registers to bus connect
	if(ps_rd_add== 5'b00000)
		ps_rd_dt= ps_faddr;
	else if(ps_rd_add== 5'b00001)
		ps_rd_dt= ps_daddr;	
	else if(ps_rd_add== 5'b00011)
		ps_rd_dt= ps_pc;
	else if(ps_rd_add== 5'b00100)					//PCSTCK 
		ps_rd_dt= ps_pcstck;
	else if(ps_rd_add== 5'b00101)
		ps_rd_dt= {15'b0,ps_pcstck_pntr};
	else if(ps_rd_add== 5'b11011)
		ps_rd_dt= {9'b0,ps_mode1};
	else if(ps_rd_add== 5'b11100)
		ps_rd_dt= ps_astat;
	else if(ps_rd_add== 5'b11110)
		ps_rd_dt= {13'b0,ps_stcky};
	else if(ps_rd_add==5'b00111)
		ps_rd_dt= ps_curlcntr;
	else if(ps_rd_add==5'b01000)
		ps_rd_dt= ps_lcntr;
	else if(ps_rd_add==5'b00110)
		ps_rd_dt= ps_laddr;
	else 
		ps_rd_dt= 16'b0;

	//Bypass (Consider if there are changes in pcstkp and stcky bypass after including jump instructions)
	if( (ps_wrt_add==ps_rd_add) & ps_wrt_en ) begin
		if(ps_rd_add== 5'b11011)
			ps_bc_dt= {15'b0,bc_dt[0]};
		else
			ps_bc_dt= bc_dt;
	end else if( (ps_rd_add==5'b00101) & (ps_pshstck_dly | ps_popstck_dly) )
		ps_bc_dt= {15'b0,ps_pshstck_dly};
	else if( (ps_rd_add==5'b11110) & (ps_pshstck_dly | ps_popstck_dly) )
		ps_bc_dt= {13'b0, (ps_stcky[1] & ps_pshstck_dly) ,ps_pshstck_dly, ps_popstck_dly};
	else if( (ps_rd_add== 5'b11100) & (ps_cmpt_dly) ) begin
		if(alu_ps_compd)
			ps_bc_dt= {  !alu_ps_an & !alu_ps_az, ps_astat[15:9] , shf_ps_sz, shf_ps_sv, mul_ps_mv, mul_ps_mn, alu_ps_ac, alu_ps_an, alu_ps_av, alu_ps_az };
		else
			ps_bc_dt= {  ps_astat[15:8] , shf_ps_sz, shf_ps_sv, mul_ps_mv, mul_ps_mn, alu_ps_ac, alu_ps_an, alu_ps_av, alu_ps_az };
	end else
		ps_bc_dt= ps_rd_dt;

end

always@(posedge clk_rf or negedge rst) begin

	if(!rst) begin

		ps_cmpt_dly<=1'b0;
		ps_idle<=1'b0;

	end else begin

		ps_cmpt_dly<=cpt_en;
	
		//Idle
		ps_idle<= ( ( (pm_ps_op[31:23]==9'd1) & !ps_idle ) | ( !interrupt & ps_idle ) ) & !ps_jmp & !ps_jmp_dly & !ps_rtrn & !ps_rtrn_dly & !ps_stcky[2];

	end

end

//Internal Registers - ASTAT, MODE1, PCSTK
always@(posedge clk_rf or negedge rst) begin

	if(!rst) begin

		ps_astat<=16'h0;
		ps_mode1<= 7'b0;
		ps_pcstck<= 16'b0;
		ps_lcntr<=16'b0;
     
	end else begin

		//ASTAT 
		if( (ps_wrt_add==5'b11100) & ps_wrt_en ) begin
	       		ps_astat<= bc_dt;
		end else begin
			if(alu_ps_compd) begin
				ps_astat[15:8]<= { (!alu_ps_an & !alu_ps_az)&(!alu_ps_ai), ps_astat[15:9] };
			end
			ps_astat[7:0]<= { shf_ps_sz, shf_ps_sv, mul_ps_mv, mul_ps_mn, alu_ps_ac, alu_ps_an, alu_ps_av, alu_ps_az };     //Update 6'b0 with compare logic later on	 
		end

	       	//ps_mode1 writing
		if( (ps_wrt_add==5'b11011) & ps_wrt_en ) begin
	       		ps_mode1[6:0]<= bc_dt[6:0];	
		end else begin
			ps_mode1[6:0]<={mul_ps_mu,mul_ps_mi,alu_ps_au,alu_ps_as,alu_ps_ai,ps_mode1[1],ps_mode1[0]};
		end

		//PC stck writing
		if( ( (ps_wrt_add==5'b00100) & ps_wrt_en ) | ps_call | ps_loop) begin
			if(ps_call) begin
				ps_pcstck<= (ps_daddr&{32{stallb_p}})|(ps_daddr_p&{32{~stallb_p}});
			end else if (ps_loop) begin
				ps_pcstck<=ps_faddr;
			end else begin
				ps_pcstck<= bc_dt;
			end
		end
		//LCNTR writing
		if(ps_loop_dly) begin
			ps_lcntr<=bc_dt;
		end
	end
end

endmodule