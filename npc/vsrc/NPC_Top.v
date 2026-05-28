module NPC_Top (
    input               clock,          // 时钟信号
    input               reset,          // 复位信号
    output       [31:0] io_pc,          // 当前正在执行的指令地址（PC）
    output              io_is_mmio      // 当前是否正在访问 MMIO 设备
);

reg  [31:0] pc;
wire [31:0] inst;

assign io_pc = pc;
assign io_is_mmio = 1'b0;

always @(posedge clock) begin
    if(reset) begin
        pc <= 32'h80000000;
    end
    else begin
        pc <= pc + 4;
    end
end

MemDPIC imem(
    .clk(clock),
    .en(1'b1),
    .addr(pc),
    .wmask(8'b0),
    .wdata(32'b0),
    .rdata(inst)
);
wire [6:0]  opcode = inst[6:0];
wire [4:0]  rd     = inst[11:7];
wire [2:0]  funct3 = inst[14:12];
wire [4:0]  rs1    = inst[19:15];
wire [11:0] imm12  = inst[31:20];

wire ebreak_en = (opcode == 7'b1110011)
               && (rd     == 5'b00000)
               && (funct3 == 3'b000)
               && (rs1    == 5'b00000)
               && (imm12  == 12'b000000000001);

wire [31:0] a0_val = 32'b0;

EbreakDPIC dpic_ebreak (
    .clk       (clock),
    .ebreak_en (ebreak_en),
    .a0_val    (a0_val)
);

endmodule