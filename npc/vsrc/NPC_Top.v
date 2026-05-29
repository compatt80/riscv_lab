module NPC_Top (
    input               clock,          // 时钟信号
    input               reset,          // 复位信号
    output       [31:0] io_pc,          // 当前正在执行的指令地址（PC）
    output              io_is_mmio      // 当前是否正在访问 MMIO 设备
);

// ------- 取指阶段 ---------
reg  [31:0] pc;
wire [31:0] inst;
wire [31:0] next_pc;

assign io_pc = pc;
// assign io_is_mmio = 1'b0;
assign next_pc = is_jal ? jal_target : is_jalr ? jalr_target : branch_yes ? branch_target : pc + 32'd4;

// pc 寄存器
always @(posedge clock) begin
    if(reset) begin
        pc <= 32'h80000000;
    end
    else begin
        pc <= next_pc;
    end
end

MemDPIC imem(
    .clk(clock),
    .en(1'b1),
    .addr(pc),
    .wmask(8'b0), // 不写内存
    .wdata(32'b0),
    .rdata(inst)
);
ITraceDPIC dpic_itrace(
    .clk(clock),
    .pc(pc),
    .inst(inst),
    .next_pc(next_pc)
);


// ------- 译码阶段 ---------
wire [31:0] rs1_val;
wire [31:0] rs2_val;
wire reg_wen; // 寄存器写使能
wire [31:0] wb_data;
wire [31:0] a0_val;
reg [31:0] src1; // 操作数1
reg [31:0] src2;// 操作数2
// 分段
wire [6:0]  opcode = inst[6:0];
wire [4:0]  rd     = inst[11:7];
wire [2:0]  funct3 = inst[14:12];
wire [4:0]  rs1    = inst[19:15];
wire [4:0]  rs2    = inst[24:20];
wire [6:0] funct7  = inst[31:25];
wire [11:0] funct12 = inst[31:20];
// 立即数扩展
wire [31:0] imm_i = {{20{inst[31]}}, inst[31:20]}; // 符号扩展
wire [31:0] imm_s = {{20{inst[31]}}, inst[31:25], inst[11:7]}; // 符号扩展
wire [31:0] imm_b = {{19{inst[31]}}, inst[31],inst[7],inst[30:25], inst[11:8], 1'b0}; // 符号扩展 末尾+0
wire [31:0] imm_u = {inst[31:12], 12'b0};
wire [31:0] imm_j = {{11{inst[31]}}, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0}; // 符号扩展 末尾+0
// 实例化寄存器堆
RegFile u_regfile (
    .clk(clock),
    .wen(reg_wen),
    .raddr1(rs1),
    .raddr2(rs2),
    .waddr(rd),
    .wdata(wb_data),
    .rdata1(rs1_val),
    .rdata2(rs2_val),
    .a0(a0_val)
);
RegfileDPIC dpic_regfile (
    .clk(clock),
    .wen(reg_wen),
    .waddr(rd),
    .wdata(wb_data)
);
// 生成控制信号
// U-type
wire is_lui   = (opcode == 7'b0110111);
wire is_auipc = (opcode == 7'b0010111);
// J-type
wire is_jal   = (opcode == 7'b1101111);
// I-type 
wire is_jalr  = ((opcode == 7'b1100111) && (funct3 == 3'b000));
wire is_lw    = ((opcode == 7'b0000011) && (funct3 == 3'b010));
wire is_lbu   = ((opcode == 7'b0000011) && (funct3 == 3'b100));
wire is_addi  = ((opcode == 7'b0010011) && (funct3 == 3'b000));
wire is_ori   = ((opcode == 7'b0010011) && (funct3 == 3'b110));
wire is_sltiu = ((opcode == 7'b0010011) && (funct3 == 3'b011));
// S-type
wire is_sw    = ((opcode == 7'b0100011) && (funct3 == 3'b010));
wire is_sb    = ((opcode == 7'b0100011) && (funct3 == 3'b000));
// B-type
wire is_beq   = (opcode == 7'b1100011) && (funct3 == 3'b000);
wire is_bne   = (opcode == 7'b1100011) && (funct3 == 3'b001);
// R-type
wire is_add   = ((opcode == 7'b0110011) && (funct3 == 3'b000) && (funct7 == 7'b0000000));
wire is_sub   = ((opcode == 7'b0110011) && (funct3 == 3'b000) && (funct7 == 7'b0100000));
// system
wire is_ebreak = ((opcode == 7'b1110011)&& (rd == 5'b00000) && (funct3 == 3'b000)&& (rs1 == 5'b00000)&& (funct12 == 12'b000000000001));

wire is_load  = is_lw || is_lbu;
wire is_store = is_sw || is_sb;
wire is_branch = is_beq || is_bne;
wire is_op_imm = is_addi || is_ori || is_sltiu;
wire is_op = is_add || is_sub;

// wire need_rs1 = is_jalr || is_load || is_store || is_branch || is_op_imm || is_op;
// wire need_rs2 = is_store || is_branch || is_op;
// wire need_rd  = is_lui || is_auipc || is_jal || is_jalr || is_load || is_op_imm || is_op;


// 操作数来源 
always @(*) begin
    case (1'b1)
        is_auipc, is_jal: begin
            src1 = pc;
        end
        default: begin
            src1 = rs1_val;
        end
    endcase
end

always @(*) begin
    case (1'b1)
        is_lui, is_auipc: begin
            src2 = imm_u;
        end
        is_jal: begin
            src2 = imm_j;
        end
        is_jalr, is_load, is_op_imm: begin
            src2 = imm_i;
        end
        is_store: begin
            src2 = imm_s;
        end
        is_branch: begin
            src2 = imm_b;
        end
        default: begin
            src2 = rs2_val;
        end
    endcase
end

EbreakDPIC dpic_ebreak (
    .clk       (clock),
    .ebreak_en (is_ebreak),
    .a0_val    (a0_val)
);

// ------- 执行阶段 ---------
localparam ALU_ADD  = 4'd0;
localparam ALU_SUB  = 4'd1;
localparam ALU_OR   = 4'd2;
localparam ALU_SLTU = 4'd3; // 无符号数比较 用于sltiu
localparam ALU_COPY = 4'd4; // 用于 lui
reg [3:0] alu_op; // 操作类型
reg [31:0] alu_result; // 计算结果

// 访存/计算类指令
always @(*) begin
    case(1'b1)
        is_sub: alu_op = ALU_SUB;
        is_ori: alu_op = ALU_OR;
        is_sltiu: alu_op = ALU_SLTU;
        is_lui: alu_op = ALU_COPY;
        default: alu_op = ALU_ADD;
    endcase
end

always @(*) begin
    case(alu_op)
        ALU_ADD: alu_result = src1 + src2;
        ALU_SUB: alu_result = src1 - src2;
        ALU_OR: alu_result = src1 | src2;
        ALU_COPY: alu_result = src2;
        ALU_SLTU: alu_result = ({1'b0, src1} < {1'b0, src2}) ? 32'd1 : 32'd0;
        default: alu_result = 32'b0;
    endcase
end

// 跳转类指令 修改PC
wire branch_yes =  (is_beq && (rs1_val == rs2_val)) || (is_bne && (rs1_val != rs2_val));
wire [31:0] branch_target = pc + imm_b;

wire [31:0] jal_target = pc + imm_j;
wire [31:0] jalr_target = (rs1_val + imm_i)  & 32'hfffffffe; // 最后的 & ~1


// ------- 访存阶段 ---------
wire [31:0] dmem_addr = alu_result; // 写地址
reg [7:0] dmem_wmask; // 写掩码
reg [31:0] dmem_wdata; // 写数据
wire [31:0] dmem_rdata; // 读数据
reg [31:0] mem_result; // 根据lw lbu来决定最终的读数据结果


// sw sb写哪个字节
always @(*) begin
    case(1'b1)
        is_sw:begin
            dmem_wmask = 8'b00001111;
        end
        is_sb:begin
            dmem_wmask = 8'b00000001 << dmem_addr[1:0];
        end
        default: dmem_wmask = 8'b00000000;
    endcase
end
// sw sb 的写数据
always @(*) begin
    case (1'b1)
        is_sw:begin
            dmem_wdata = rs2_val;
        end 
        is_sb:begin
            if(dmem_addr[1:0] == 2'd0) dmem_wdata = {24'b0, rs2_val[7:0]};
            else if(dmem_addr[1:0] == 2'd1) dmem_wdata = {16'b0, rs2_val[7:0], 8'b0};
            else if(dmem_addr[1:0] == 2'd2) dmem_wdata = {8'b0, rs2_val[7:0], 16'b0};
            else dmem_wdata = {rs2_val[7:0], 24'b0};
        end 
        default: dmem_wdata = 32'b0;
    endcase
end
// lw lbu的读结果
always @(*) begin
    case(1'b1)
        is_lw:begin
            mem_result = dmem_rdata;
        end
        is_lbu:begin
            if(dmem_addr[1:0] == 2'd0) mem_result = {24'b0,dmem_rdata[7:0]};
            else if(dmem_addr[1:0] == 2'd1) mem_result = {24'b0,dmem_rdata[15:8]};
            else if(dmem_addr[1:0] == 2'd2) mem_result = {24'b0,dmem_rdata[23:16]};
            else mem_result = {24'b0,dmem_rdata[31:24]};
        end
        default:mem_result = 32'b0;
    endcase
end
// io_is_mmio判断
assign io_is_mmio = is_store && ((dmem_addr < 32'h80000000) || (dmem_addr >= 32'h88000000));
// 实例化dmem
MemDPIC dmem(
    .clk(clock),
    .en(is_load || is_store),
    .addr(dmem_addr),
    .wmask(dmem_wmask),
    .wdata(dmem_wdata),
    .rdata(dmem_rdata) 
);

// ------- 写回阶段 ---------
assign reg_wen = is_lui || is_auipc || is_jal || is_jalr || is_load || is_op_imm || is_op; // 写回请求
assign wb_data = is_load ? mem_result : (is_jal || is_jalr) ? pc + 32'd4 : alu_result;



endmodule

// 寄存器堆模块
module RegFile (
    input clk,
    input wen, // 写使能
    input wire [4:0] raddr1, // rs1地址
    input wire [4:0] raddr2,// rs2地址
    input wire [4:0]  waddr, // 写地址
    input wire [31:0] wdata, // 写数据
    output wire [31:0] rdata1,// rs1数据
    output wire [31:0] rdata2,// rs2数据
    output wire [31:0] a0 // a0寄存器 
);

    reg [31:0] regs[31:0]; // 定义32个寄存器 每个寄存器数据位 32位
    assign rdata1 = (raddr1 == 5'd0) ? 32'b0 : regs[raddr1]; // x0寄存器数值为0
    assign rdata2 = (raddr2 == 5'd0) ? 32'b0 : regs[raddr2]; // 读操作
    assign a0 = regs[10];

    always @(posedge clk) begin
        if(wen && (waddr != 5'b0)) begin
            regs[waddr] <= wdata;
        end
    end
    
endmodule