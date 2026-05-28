// 让 Verilog 访问 C++ 里模拟的内存。
module MemDPIC(
    input wire clk,
    input wire en, //存储器使能
    input wire [31:0] addr, //访问地址 
    input wire [7:0] wmask, //写掩码
    input wire [31:0] wdata, //写数据
    output reg [31:0] rdata //读数据
);
    import "DPI-C" function int pmem_read(input int raddr);
    import "DPI-C" function void pmem_write(input int waddr, input int wdata, input byte wmask);

    always @(*) begin
        if (en) begin
            rdata = pmem_read(addr);
        end else begin
            rdata = 0;
        end
    end

    always @(posedge clk) begin
        if (en && wmask != 0) begin
            pmem_write(addr, wdata, wmask);
        end
    end

endmodule

// 把 Verilog 寄存器堆的写回同步到 C++ 的 cpu_gpr[32]。
module RegfileDPIC (
    input clk,
    input wen, //写使能
    input [4:0] waddr, //写地址
    input [31:0] wdata //写数据
);
    import "DPI-C" function void set_gpr_value(input int idx,input int value);

    always@(posedge clk)begin
        if(wen && waddr!=0)begin
            set_gpr_value({27'b0, waddr}, wdata);
        end
    end
    
endmodule

// 检测到 RISC-V 的 ebreak 指令时，通知 C++ 仿真结束。正常/异常
module EbreakDPIC (
    input wire clk,
    input wire ebreak_en, //当前指令是否是ebreak
    input [31:0] a0_val //约定：a0=0表示正常退出，非0表示错误
);
    import "DPI-C" function void npc_ebreak(input int code);
    
    always @(posedge clk) begin
        if(ebreak_en)begin
            npc_ebreak(a0_val);
        end
    end
endmodule

// 每执行一条指令，把 pc / next_pc / inst 传给 C++ 的 itrace 逻辑 
// 记录每条执行过的指令
module ITraceDPIC (
    input clk,
    input [31:0] pc, 
    input [31:0] inst,
    input [31:0] next_pc
);
    import "DPI-C" function void npc_itrace(input int pc, input int next_pc,input int inst);

    always @(posedge clk) begin
        if (pc != 0) begin
            npc_itrace(pc, next_pc, inst);
        end
    end
    
endmodule
