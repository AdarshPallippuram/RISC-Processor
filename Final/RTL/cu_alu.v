//---------------------------------------------------------------------------------------------
// ALU Module
//---------------------------------------------------------------------------------------------
module alu   
            #(parameter RF_DATASIZE = 16)  
            (
                // Universal signals
                input wire clk, reset,

                // Data 
                input wire [RF_DATASIZE-1:0] xb_dtx, xb_dty,
                output reg  [RF_DATASIZE-1:0] alu_xb_dt,

                // Control signals
                input wire ps_alu_en, ps_alu_float, ps_alu_sat, ps_alu_ci, ps_alu_trunc,
                input wire [1:0] ps_alu_hc, ps_alu_sc2,
                input wire [2:0] ps_alu_sc1,

                // Flags
                output reg alu_ps_az, alu_ps_an, alu_ps_ac, alu_ps_av, alu_ps_au, alu_ps_as, alu_ps_ai,
                output wire alu_ps_compd
            );

    //---------------------------------------------------------------------------------------
	// Latching Control Signals for execute cycle usage
	//---------------------------------------------------------------------------------------
    reg alu_en, alu_float, alu_sat, alu_trunc;
    reg [1:0]alu_hc, alu_sc2;
    reg [2:0]alu_sc1;
    wire satEn;

    always@(posedge clk or negedge reset)
    begin
        if(~reset)
        begin
                alu_en  <= 1'b0;
                alu_sat <= 1'b0;
        end
        else
        begin
            alu_en  <= ps_alu_en;
            alu_sat <= satEn; 
        end
    end

    assign satEn = alu_en ? ps_alu_sat : alu_sat;

    always@(posedge clk or negedge reset)
    begin
        if(~reset)
        begin
            alu_float <= 1'b0;
            alu_trunc <= 1'b0;
            alu_hc    <= 2'b00;
            alu_sc1   <= 3'b000;
            alu_sc2   <= 2'b00;
        end
        else 
            if(ps_alu_en)
                    begin
                        alu_float <= ps_alu_float;
                        alu_trunc <= ps_alu_trunc;
                        alu_hc    <= ps_alu_hc;
                        alu_sc1   <= ps_alu_sc1;
                        alu_sc2   <= ps_alu_sc2;
                    end 
    end

    //---------------------------------------------------------------------------------------
	// Latching Data for execute cycle usage
	//---------------------------------------------------------------------------------------
    reg [RF_DATASIZE-1:0] x, y;

    always@(posedge clk or negedge reset)
    begin
        if(~reset)
        begin
            x  <= 16'h0001;
            y  <= 16'h0000;
        end
        else
        begin
            x <= ps_alu_en ? xb_dtx : x;
            y <= ps_alu_en ? (~ps_alu_sc2[1] ? xb_dty : 16'h0000) : y; 
        end
    end

    //---------------------------------------------------------------------------------------
    // Invalid condition checking for NAN inputs and checking simultaneous infinities
    //---------------------------------------------------------------------------------------    
    wire invld_x, invld_y;      //For NAN condition checking
    wire infs;                  //For simultaneous infinities

    assign invld_x = (&x[RF_DATASIZE-2:RF_DATASIZE-6]) & (|x[RF_DATASIZE-7:0]) & alu_float;
    assign invld_y = (&y[RF_DATASIZE-2:RF_DATASIZE-6]) & (|y[RF_DATASIZE-7:0]) & alu_float;

    assign infs = (&x[RF_DATASIZE-2:RF_DATASIZE-6]) & ~(|x[RF_DATASIZE-7:0]) & (&y[RF_DATASIZE-2:RF_DATASIZE-6]) & ~(|y[RF_DATASIZE-7:0]) & alu_float;

    //---------------------------------------------------------------------------------------
    // Sign, Exponent, Mantisa and Float to Fixed point regs
    //---------------------------------------------------------------------------------------
    reg sx, sy, s;
    reg [4:0] ex, ey;
    reg [15:0] e;
    reg [10:0] mx, my;
    reg [9:0] m;

    reg [4:0] diff;
    reg [4:0] tru_diff;

    reg [RF_DATASIZE-1:0] Fz;

    //---------------------------------------------------------------------------------------
    // ALU operations (Shadow)
    //---------------------------------------------------------------------------------------
    reg  [RF_DATASIZE-1:0] a, b;
    reg  c;
    wire signed [RF_DATASIZE-1:0] sum, cout;
    reg  [RF_DATASIZE-1:0] norm_ip;
    reg  [RF_DATASIZE-1:0] temp_x, temp_y;
    reg signed [25:0] temp_dt_2, temp_dt_3;
    reg signed [15:0] temp_dt_1, temp_dt; 

    always@(*)
    begin
        if(alu_hc == 2'b00)     //Instructions using adder circuit
        begin
            if(alu_float & ~alu_sc1[0])     //Common floating adder instructions
            begin
                temp_dt = 0;
                //Float to fixed conversion code
                sx = x[RF_DATASIZE-1];
                sy = y[RF_DATASIZE-1];
                ex = x[RF_DATASIZE-2:RF_DATASIZE-6];
                ey = y[RF_DATASIZE-2:RF_DATASIZE-6];

                diff = ex + ~ey + 1;
                tru_diff = (diff^{5{diff[4]}}) + diff[4];
                mx = {1'b1,x[RF_DATASIZE - 7:0]} >> (tru_diff & {5{diff[4]}});
                my = {1'b1,y[RF_DATASIZE - 7:0]} >> (tru_diff & {5{~diff[4]}});

                temp_x = (ex == 5'b0_0000) ? {x[15],15'b000_0000_0000_0000} : (({{5{1'b0}},mx} ^ {16{sx}}) + sx);
                temp_y = (ey == 5'b0_0000) ? {y[15],15'b000_0000_0000_0000} : (({{5{1'b0}},my} ^ {16{sy}}) + sy);
                norm_ip = sum;
            end
            else if(alu_float)
            begin
                ey = 0;
                case(alu_sc1[2:1])
                    2'b00:          //SCALB, LOGB
                    begin
                        sx = 0;
                        diff = 0;
                        norm_ip = 0;
                        tru_diff = 0;
                        temp_dt = 0;
                        ex = x[RF_DATASIZE-2:RF_DATASIZE-6];
                        temp_x = {{11{1'b0}},ex};
                        temp_y = alu_sc2[1] ? 16'b1111_1111_1111_0001 : y;
                    end
                    2'b01:          //TRUNC instructions
                    begin
                        diff = 0;
                        norm_ip = 0;
                        sx = x[RF_DATASIZE-1];
                        ex = x[RF_DATASIZE-2:RF_DATASIZE-6];
                        temp_x = {{11{1'b0}},ex};
                        temp_y = y;
                        temp_dt_3 = {15'b000_0000_0000_0000,((|ex) ? 1'b1 : 1'b0),x[RF_DATASIZE - 7:0]};
                        if(sum < 15)
                        begin
                            temp_dt_2 = temp_dt_3 & 0;
                        end
                        else
                        begin
                            temp_dt_2 = temp_dt_3 << sum;
                        end
                        temp_dt_1 = temp_dt_2[25:10];
                        temp_dt = alu_ps_au ? 16'h0000 : (temp_dt_1 ^ {16{sx}}) + sx;
                    end
                    2'b10:          //FIX instructions
                    begin
                        diff = 0;
                        norm_ip = 0;
                        sx = x[RF_DATASIZE-1];
                        ex = x[RF_DATASIZE-2:RF_DATASIZE-6];
                        temp_x = {{11{1'b0}},ex};
                        temp_y = y;
                        temp_dt_3 = {15'b000_0000_0000_0000,((|ex) ? 1'b1 : 1'b0),x[RF_DATASIZE - 7:0]};
                        if(sum < 15)
                        begin
                            temp_dt_2 = temp_dt_3 & 0;
                        end
                        else
                        begin
                            temp_dt_2 = temp_dt_3 << sum;
                        end
                        if(~alu_trunc)
                        begin
                            if(~temp_dt_2[9] & (~alu_trunc))	
                                //truncate
                                temp_dt_1 = temp_dt_2[25:10];
                            else
                            begin
                                if(temp_dt_2[8:0] == 9'b0_0000_0000)
                                    //rnd to make temp_dt_2[10]=0 and truncate remaining
                                    temp_dt_1 = (temp_dt_2[25:10] + temp_dt_2[10]);
                                else
                                    //add 1 to msb10 and truncate remaining
                                    temp_dt_1 = (temp_dt_2[25:10] + 1);
                            end
                        end
                        else
                            temp_dt_1 = temp_dt_2[25:10];
                        temp_dt = alu_ps_au ? (sx ? (alu_trunc ? 16'hffff : 16'h0000) : 16'h0000) : ((temp_dt_1 ^ {16{sx}}) + sx);

                    end
                    2'b11:          //FLOAT instructions
                    begin
                        sx = 0;
                        ex = 0;
                        diff = 0;
                        temp_x = 1;
                        temp_y = 0;
                        tru_diff = 0;
                        temp_dt = 0;
                        norm_ip = x;
                    end
                    default:
                    begin
                        sx = 0;
                        ex = 0;
                        temp_x = 1;
                        temp_y = 0;
                    end
                endcase
            end
            else            //Fixed point arithmetic instrucions
            begin
                ex = 0;
                ey = 0;
                diff = 0;
                norm_ip = 0;
                tru_diff = 0;
                temp_dt = 0;
                temp_x = x;
                temp_y = y;
            end
            
            c = (~alu_float) & alu_sc1[0] & ps_alu_ci;
            a = (alu_sc2[1] & alu_sc1[1] & ~alu_sc1[0]) ? (~temp_x): temp_x;
            b = alu_sc2[1] ? (((^alu_sc1[2:1]) & (~alu_float)) ? (16'hffff + (ps_alu_ci & alu_sc1[0])) : ((temp_y & {16{alu_sc2[0]}}) + ({15'b000_0000_0000_0000, (~alu_sc1[0])}) + c)) : (alu_sc2[0] ? (~temp_y + 1 - alu_sc1[0] + c) : (temp_y + c));
            
        end
        else
        begin
            ex = 0;
            ey = 0;
            diff = 0;
            norm_ip = 0;
            a = 1;
            b = 0;
            c = 0;
            tru_diff = 0;
            temp_dt = 0;
        end
    end

    reg [RF_DATASIZE-1:0] num_x, num_y;
    reg temp_max;   // temp_max = 1 if y is larger when taking true values
    reg max;        // max = 1 if y is larger
    reg [RF_DATASIZE-1:0] norm_x, norm_y;

    always@(*)
    begin
        if(alu_hc == 2'b10)         //MIN, MAX, CLIP and Comp instructions
        begin
            norm_x = ((x[14:10] == 5'b0_0000) & alu_float) ? {x[15],15'b000_0000_0000_0000} : x;
            norm_y = ((y[14:10] == 5'b0_0000) & alu_float) ? {y[15],15'b000_0000_0000_0000} : y;
            num_x = alu_float ? norm_x[14:0] : ((x ^ {16{x[15]}}) + x[15]);
            num_y = alu_float ? norm_y[14:0] : ((y ^ {16{y[15]}}) + y[15]);

            if(num_x[15] ^ num_y[15])
                temp_max = num_y[15];
            else if(num_x[14] ^ num_y[14])
                temp_max = num_y[14];
            else if(num_x[13] ^ num_y[13])
                temp_max = num_y[13];
            else if(num_x[12] ^ num_y[12])
                temp_max = num_y[12];
            else if(num_x[11] ^ num_y[11])
                temp_max = num_y[11];
            else if(num_x[10] ^ num_y[10])
                temp_max = num_y[10];
            else if(num_x[9] ^ num_y[9])
                temp_max = num_y[9];
            else if(num_x[8] ^ num_y[8])
                temp_max = num_y[8];
            else if(num_x[7] ^ num_y[7])
                temp_max = num_y[7];
            else if(num_x[6] ^ num_y[6])
                temp_max = num_y[6];
            else if(num_x[5] ^ num_y[5])
                temp_max = num_y[5];
            else if(num_x[4] ^ num_y[4])
                temp_max = num_y[4];
            else if(num_x[3] ^ num_y[3])
                temp_max = num_y[3];
            else if(num_x[2] ^ num_y[2])
                temp_max = num_y[2];
            else if(num_x[1] ^ num_y[1])
                temp_max = num_y[1];
            else if(num_x[0] ^ num_y[0])
                temp_max = num_y[0];
            else
                temp_max = 1'b0;

            if(x[15] ^ y[15])
                max = x[15];
            else
                max = temp_max ^ x[15];
        end
        else
        begin
            num_y = 0;
            temp_max = 0;
            max = 0;
        end
    end

    //---------------------------------------------------------------------------------------
    // ALU operations (True)
    //---------------------------------------------------------------------------------------

    always@(*)
    begin
        case(alu_hc)
            2'b00:      //Instructions using adder circuit
            begin
                if(alu_float & ~alu_sc1[0])
                begin
                    if(~alu_sc2[0])         //AI
                        alu_ps_ai = (invld_x | invld_y) | (infs & (x[15] ^ y[15]));
                    else if(alu_sc2[0] & alu_sc1[1])
                        alu_ps_ai = (invld_x | invld_y);
                    else
                        alu_ps_ai = (invld_x | invld_y) | (infs & ~(x[15] ^ y[15]));
                    alu_ps_av = (alu_sc1[1] & alu_sc2[0]) ? 1'b0 : (e[5] ^ (&e[4:0])) & (~alu_ps_ai);      //AV
                    alu_ps_au = (alu_sc1[1] & alu_sc2[0]) ? 1'b0 : e[15] | ~(|e[14:0]) & (~alu_ps_ai);     //AU

                    alu_xb_dt = (invld_x | invld_y) ? 16'hffff : ((~alu_sc2[1] & alu_sc1[2]) ? {1'b0,Fz[14:0]} : Fz);
                end
                else if(alu_float)
                begin
                    case(alu_sc1[2:1])
                        2'b00:      //SCALB, LOGB
                        begin
                            alu_ps_av = (alu_sc2[1] ? ((&ex | ~(|ex)) & ~invld_x) : (~y[15] & ((|sum[15:5]) | (&sum[4:0])))) & (~alu_ps_ai);      //AV
                            alu_ps_au = (sum[15] | ~(|sum[14:0])) & ~(alu_sc2[1]) & (~alu_ps_ai);             //AU
                            alu_ps_ai = invld_x;
                            if(alu_sc2[1])
                            begin
                                if(invld_x)
                                    alu_xb_dt = 16'hffff;
                                else if(alu_ps_av)
                                    alu_xb_dt = satEn ? ({16{&ex}} & 16'h7fff | {16{~(|ex)}} & 16'h8000) : ({16{&ex}} & 16'h7c00 | {16{~(|ex)}} & 16'hfc00);
                                else
                                    alu_xb_dt = sum;
                            end
                            else
                            begin
                                alu_xb_dt = alu_ps_av ? (alu_trunc ? {x[15],15'b11110_11_1111_1111} : {x[15],15'b11111_00_0000_0000}) : (alu_ps_au ? {x[15],15'b000_0000_0000_0000} : {x[RF_DATASIZE-1], sum[4:0],x[9:0]});
                            end
                        end
                        2'b01:      //TRUNC instructions
                        begin
                            alu_ps_av = (((sum > 29) | &ex) ? 1'b1 : 1'b0) & (~alu_ps_ai);
                            alu_ps_au = (|temp_dt_3[10:0]) & (sum < 15) & (~alu_ps_ai);
                            alu_ps_ai = invld_x | (~satEn & alu_ps_av);
                            if(invld_x)
                                alu_xb_dt = 16'hffff;
                            else if(satEn)
                                alu_xb_dt = alu_ps_av ? (sx ? 16'h8000 : 16'h7fff) : temp_dt;
                            else
                                alu_xb_dt = alu_ps_av ? 16'hffff : temp_dt;
                        end
                        2'b10:      //FIX instructions
                        begin
                            alu_ps_av = (((sum > 29) | &ex) ? 1'b1 : 1'b0) & (~alu_ps_ai);
                            alu_ps_au = (|temp_dt_3[10:0]) & (sum < 15) & (~alu_ps_ai);
                            alu_ps_ai = invld_x | (~satEn & alu_ps_av);
                            if(invld_x)
                                alu_xb_dt = 16'hffff;
                            else if(satEn)
                                alu_xb_dt = alu_ps_av ? (sx ? 16'h8000 : 16'h7fff) : temp_dt;
                            else
                                alu_xb_dt = alu_ps_av ? 16'hffff : temp_dt;
                        end
                        2'b11:      //FLOAT instructions
                        begin
                            alu_ps_ai = 1'b0;       //AI
                            alu_ps_av = (~y[15] & ((|e[15:5]) | (&e[4:0]))) & (~alu_ps_ai);      //AV
                            alu_ps_au = (e[15] | ~(|e[14:0])) & (~alu_ps_ai);                    //AU
                            alu_xb_dt = ~(|x) ? 16'h0000 : Fz;
                        end  
                    endcase
                end
                else
                begin
                    alu_ps_au = 1'b0;       //AU
                    alu_ps_av = ((alu_sc1 == 3'b010) ? 1'b0 : (cout[RF_DATASIZE-1] ^ cout[RF_DATASIZE-2]));       //AV
                    alu_ps_ai = 1'b0;       //AI
                    alu_xb_dt = (satEn & alu_ps_av) ? (sum[15] ? 16'h7fff : 16'h8000) : ((~alu_sc2[1] & alu_sc1[1] & ~alu_sc2[0]) ? (sum >>> 1) : sum);
                end
            end       

            2'b10:      //Min, Max, CLIP and Comp Instructions
            begin
                alu_ps_av = 1'b0;       //AV (reset for MIN, MAX, CLIP instructions)
                alu_ps_au = 1'b0;       //AU
                alu_ps_ai = invld_x | invld_y;    //Checking for NAN input
                case(alu_sc1[1:0])
                    2'b00:      // Rn = MIN(Rx,Ry), Fn = MIN(Fx,Fy)
                        alu_xb_dt = alu_ps_ai ? 16'b1111_1111_1111_1111 : (max ? norm_x : norm_y);
                    2'b10:      // Rn = MAX(Rx,Ry), Fn = MAX(Fx,Fy)
                        alu_xb_dt = alu_ps_ai ? 16'b1111_1111_1111_1111 : (max ? norm_y : norm_x);
                    2'b01:      // Rn = CLIP Rx by Ry, Fn = CLIP Fx by Fy
                        alu_xb_dt = alu_ps_ai ? 16'b1111_1111_1111_1111 : (temp_max ? x : (alu_float ? ((x[15]) ? {1'b1,num_y} : {1'b0,num_y}) : ((x[15]) ? ({1'b0,num_y} ^ {16{1'b1}} + 1'b1): {1'b0,num_y})));
                    2'b11:      // COMP(Rx,Ry), COMP(Fx,Fy)
                        alu_xb_dt = alu_ps_ai ? 16'b1111_1111_1111_1111 : ((x == y) ? 0 : (max ? 16'hffff : 16'h0001));
                    default:
                        alu_xb_dt = 16'h1;
                endcase
            end

            2'b01:      //Logical Instructions
            begin
                alu_ps_av = 1'b0;       //AV (reset for logical instructions)
                alu_ps_au = 1'b0;       //AU
                alu_ps_ai = 1'b0;       //AI
                case(alu_sc1)
                    3'b000:     //Rx AND Ry
                        alu_xb_dt = x & y;
                    3'b001:     //Rx OR Ry
                        alu_xb_dt = x | y;
                    3'b010:     //Rx XOR Ry
                        alu_xb_dt = x ^ y;
                    3'b100:     //REG_AND
                        alu_xb_dt = &x;
                    3'b101:     //REG_OR
                        alu_xb_dt = |x;
                    3'b111:     //NOT RX
                        alu_xb_dt = ~x;
                    default: 
                        alu_xb_dt = 16'h1;
                endcase
            end
                        
            2'b11:      //Remaining Instructions
            begin
                case(alu_sc1)
                    3'b000:     //Fn = -Fx
                    begin
                        alu_ps_av = 1'b0;       //AV (reset for Floating point Negate)
                        alu_ps_au = 1'b0;       //AU
                        if((x[RF_DATASIZE-2:RF_DATASIZE-6] == 5'b0_0000))
                        begin
                            alu_xb_dt = {~x[RF_DATASIZE-1],15'b000_0000_0000_0000};
                            alu_ps_ai = 1'b0;       //AI = 0
                        end
                        else if(invld_x)
                        begin
                            alu_xb_dt = 16'b1111_1111_1111_1111;
                            alu_ps_ai = 1'b1;       //AI = 1
                        end
                        else
                        begin
                            alu_xb_dt = {~x[RF_DATASIZE-1], x[RF_DATASIZE-2:0]};
                            alu_ps_ai = 1'b0;       //AI = 0
                        end
                    end
                    3'b001:     //Fn = PASS Fx, Rn = PASS Rx
                    begin
                        alu_ps_av = 1'b0;       //AV
                        alu_ps_au = 1'b0;       //AU
                        if((x[RF_DATASIZE-2:RF_DATASIZE-6] == 5'b0_0000) & alu_float)
                        begin
                            alu_xb_dt = {x[RF_DATASIZE-1],15'b000_0000_0000_0000};
                            alu_ps_ai = 1'b0;       //AI = 0
                        end
                        else if(invld_x)
                        begin
                            alu_xb_dt = 16'b1111_1111_1111_1111;
                            alu_ps_ai = 1'b1;       //AI = 1
                        end
                        else
                        begin
                            alu_xb_dt = x;
                            alu_ps_ai = 1'b0;       //AI = 0
                        end
                    end
                    3'b010:     //Rn = MANT Fx
                    begin
                        alu_ps_av = 1'b0;       //AV (reset for MANT)
                        alu_ps_au = 1'b0;       //AU
                        if(x[RF_DATASIZE-2:RF_DATASIZE-6] == 5'b00000)
                        begin
                            alu_xb_dt = {x[RF_DATASIZE-1],15'b000_0000_0000_0000};
                            alu_ps_ai = 1'b0;       //AI = 0
                        end
                        else
                            if(x[RF_DATASIZE-2:RF_DATASIZE-6] == 5'b11111)
                            begin
                                alu_xb_dt = 16'b1111_1111_1111_1111;
                                alu_ps_ai = 1'b1;       //AI = 1
                            end
                            else
                            begin
                                alu_xb_dt = {1'b1, x[RF_DATASIZE-7:0], 5'b0_0000};
                                alu_ps_ai = 1'b1;       //AI = 1
                            end
                    end
                    3'b011:     //Rn = ABS Rx, Fn = ABS Fx
                    begin
                        alu_ps_au = 1'b0;       //AU
                        alu_ps_ai = invld_x;    //Checking for NAN input
                        alu_ps_av = (alu_float ? 1'b0 : ((x == 16'b1000_0000_0000_0000) ? 1'b1 : 1'b0)) & (~alu_ps_ai);       //AV high only if x is highest negative fixed integer
                        alu_xb_dt = alu_float ? {1'b0, x[RF_DATASIZE-2:0]} : ((satEn & alu_ps_av) ? 16'h7fff : (({16{x[RF_DATASIZE-1]}} ^ x) + x[RF_DATASIZE-1]));
                    end
                    3'b100:     //Fn = Fx COPYSIGN Fy
                    begin
                        alu_ps_av = 1'b0;       //AV (reset for COPYSIGN)
                        alu_ps_au = 1'b0;       //AU
                        alu_ps_ai = invld_x | invld_y;
                        if(x[RF_DATASIZE-2:RF_DATASIZE-6] == 5'b0_0000)
                            alu_xb_dt = {y[RF_DATASIZE-1],15'b000_0000_0000_0000};
                        else
                            if(invld_x | invld_y)
                                alu_xb_dt = 16'b1111_1111_1111_1111;
                            else
                                alu_xb_dt = {y[RF_DATASIZE-1], x[RF_DATASIZE-2:0]};
                    end
                    default:
                    begin
                        alu_ps_av = 0;
                        alu_ps_au = 0;
                        alu_ps_ai = 0;
                        alu_xb_dt = 16'h1;
                    end
                endcase
            end
            default:
            begin
                alu_xb_dt = 16'h1;
            end
        endcase
    end

    //---------------------------------------------------------------------------------------
    // Normalising circuit
    //---------------------------------------------------------------------------------------
    reg [RF_DATASIZE-1:0] tru_norm_ip;
    reg [4:0] zeroes;
    reg [7:0] zval8;
    reg [3:0] zval4;

    reg signed [4:0] shft_amnt;
    reg signed [15:0] exp_diff;
    reg [15:0] norm_out;

    always@(*)
    begin
        tru_norm_ip = (norm_ip ^ {16{norm_ip[RF_DATASIZE-1]}}) + norm_ip[RF_DATASIZE-1];
        
        if(tru_norm_ip == 16'h0000) 	
            zeroes = 5'b10000;		//for all-zero value
        else
        begin
            zeroes[4] = 1'b0;
            zeroes[3] = (tru_norm_ip[15:8] == 8'h00);	
            zval8     = (zeroes[3] ? tru_norm_ip[7:0] : tru_norm_ip[15:8]);
            zeroes[2] = (zval8[7:4] == 4'h0);
            zval4     = (zeroes[2] ? zval8[3:0] : zval8[7:4]);
            zeroes[1] = (zval4[3:2] == 2'b00);
            zeroes[0] = zeroes[1] ? ~zval4[1] : ~zval4[3];
        end
        
        shft_amnt = 5'b0_0101 - zeroes;     //subtracting from 5 since we want to shift to LSB 11 bits
        exp_diff  = shft_amnt - {16{({alu_en,alu_float,alu_hc,alu_sc2,alu_sc1[1:0]} == 8'b11_00_00_10)}};     //checking for by 2 instructions
        norm_out = tru_norm_ip << zeroes;
    end

    //---------------------------------------------------------------------------------------
    // Rounding
    //---------------------------------------------------------------------------------------
    reg [9:0] rnd_out;

    always@(*)
    begin
		if(~alu_trunc)
		begin
			if(~norm_out[4])	
				//truncate
				rnd_out = norm_out[14:5];
			else
			begin
				if(norm_out[3:0] == 4'b0000)
					//rnd to make norm_out[5]=0 and truncate remaining
					rnd_out = (norm_out[14:5] + norm_out[5]);
				else
					//add 1 to msb10 and truncate remaining
					rnd_out = (norm_out[14:5] + 1);
			end
		end
		else
			rnd_out = norm_out[14:5];
	end

    //---------------------------------------------------------------------------------------
    // Fixed to Floating point
    //---------------------------------------------------------------------------------------
    always@(*)
    begin
        s = norm_ip[RF_DATASIZE-1];
        e = alu_sc1[0] ? (30 - zeroes + ({16{alu_sc2[1]}} & y)) : (((ex & {5{~diff[4]}}) | (ey & {5{diff[4]}})) + exp_diff);
        m = rnd_out;

        Fz = alu_ps_av ? (alu_trunc ? {s,15'b11110_11_1111_1111} : {s,15'b11111_00_0000_0000}) : (alu_ps_au ? {s,15'b000_0000_0000_0000} : {s, e[4:0], m});
    end

    //---------------------------------------------------------------------------------------
    // Flags
    //---------------------------------------------------------------------------------------
    always@(*)
    begin 
        //AZ
        alu_ps_az = ((alu_float & ~(alu_sc1[0] & ~alu_sc2[0] & (^alu_sc1[2:1]))) ? (alu_xb_dt[14:0] == 15'h0): (alu_xb_dt == 16'h0000)) & (~alu_ps_ai);         //1st condition checks for float instr other than FIX, TRUNC, ABS Fx
        
        //AN (reset for MANT instrucion)
        alu_ps_an = (({alu_hc,alu_sc1} == 5'b11_010) ? 1'b0 : alu_xb_dt[RF_DATASIZE-1]) & (~alu_ps_ai);

        //AC (reset for logical, COMP, MIN, MAX, PASS, ABS, CLIP and floating instructions)
        alu_ps_ac = (cout[RF_DATASIZE-1] & ~(|alu_hc) & (~alu_float) & ~({alu_hc,alu_sc2,alu_sc1} == 7'b00_01_011)) & (~alu_ps_ai);

        //AS (reset for all instr other than ABS Fx, ABS Rx, MANT)
        alu_ps_as = (({alu_hc,alu_sc1[1]} == 3'b11_1) ? x[15] : 1'b0) & (~alu_ps_ai);
    end

        //COMPR
        assign alu_ps_compd = alu_en & ({alu_hc,alu_sc1,alu_sc2} == 7'b10_011_01);

    //---------------------------------------------------------------------------------------
    // Adder
    //---------------------------------------------------------------------------------------
    genvar i;
    generate
        full_adder f (a[0], b[0], 1'b0, sum[0], cout[0]);
        for(i=1; i<RF_DATASIZE; i=i+1)
        begin
            full_adder f (a[i], b[i], cout[i-1], sum[i], cout[i]);
        end
    endgenerate

endmodule

//-------------------------------------------------------------------------------------------
// ADDER MODULE
//-------------------------------------------------------------------------------------------
module full_adder
    (
        input wire a,b,c,
        output wire sum,cout
    );
    assign sum  = a^b^c;
    assign cout = (a&b) | (b&c) | (a&c);
endmodule

//--------------------------------------------------------------
// TEST BENCH MODULE
//--------------------------------------------------------------
// module test_ALU_final 
//             #(parameter RF_DATASIZE = 16) 
//             ();

//     reg clk, reset;
//     reg [RF_DATASIZE-1:0] xb_dtx, xb_dty;
//     wire [RF_DATASIZE-1:0] alu_xb_dt;
//     reg ps_alu_en, ps_alu_float, ps_alu_sat, ps_alu_ci, ps_alu_trunc;
//     reg [1:0] ps_alu_hc, ps_alu_sc2;
//     reg [2:0] ps_alu_sc1;
//     wire alu_ps_az, alu_ps_an, alu_ps_ac, alu_ps_av, alu_ps_au, alu_ps_as, alu_ps_ai, alu_ps_compd;

//     ALU inst1 
//             (
//                 // Universal signals
//                 clk, reset,

//                 // Data 
//                 xb_dtx, xb_dty,
//                 alu_xb_dt,

//                 // Control signals
//                 ps_alu_en, ps_alu_float, ps_alu_sat, ps_alu_ci, ps_alu_trunc,
//                 ps_alu_hc, ps_alu_sc2,
//                 ps_alu_sc1,

//                 // Flags
//                 alu_ps_az, alu_ps_an, alu_ps_ac, alu_ps_av, alu_ps_au, alu_ps_as, alu_ps_ai,
//                 alu_ps_compd
//             );

//     initial begin
//         clk = 0;
//         forever #5 clk = ~clk;
//     end

//     initial begin
//         reset = 1;
//         #2 reset = 0;
//         #2 reset = 1;
//     end

//     initial begin
//         ps_alu_en = 0;
//         #8 ps_alu_en = 1;    
//     end

//     initial begin
//         ps_alu_sat = 0;
//         ps_alu_ci = 0;
//     end

//     initial begin
//         ps_alu_trunc = 0;
//     end

//     initial begin
//         {ps_alu_float, ps_alu_hc, ps_alu_sc2[1],ps_alu_sc1,ps_alu_sc2[0]} = 8'b0_01_1_100_0;
//     end

//     initial begin
//         xb_dtx = 16'hffff;
//     end

//     initial begin
//         xb_dty = 16'h7808;
//     end

// endmodule