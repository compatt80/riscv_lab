#include"../include/common.h"
#include "VNPC_Top.h"
#include "verilated.h"

extern uint32_t cpu_gpr[];

NPCState npc_state = {.state = NPC_STOP};
uint64_t g_timer = 0;
int res=-1;
static VNPC_Top* dut;


extern "C" void npc_ebreak(int code){
    npc_state.state = NPC_END;
    npc_state.halt_ret = code;
}

static void single_cycle() {
    dut->clock = 0; dut->eval();
    dut->clock = 1; dut->eval();
    g_timer++;
}

static void reset(int n) {
    dut->reset = 1;
    for(int i = 0; i < 32; i++) {
        cpu_gpr[i] = 0;
    }
    while (n-- > 0) single_cycle();
    dut->reset = 0;
}

void cpu_exec(uint64_t n) {
    if (npc_state.state == NPC_END || npc_state.state == NPC_ABORT) {
        printf("Program has ended. Use 'q' to exit.\n");
        res = -1;
    }

    npc_state.state = NPC_RUNNING;

    while (n > 0 && npc_state.state == NPC_RUNNING) {
        #ifdef CONFIG_DIFFTEST
        // 记录执行前的 PC
        uint32_t pc_curr = dut->io_pc; 
        if (dut->io_is_mmio) {
            difftest_skip_ref(); 
        }
        #endif
        single_cycle();
        #ifdef CONFIG_DIFFTEST
        // 对比执行后的状态
        // pc_curr: 当前指令地址, dut->pc: 下一条指令地址
        difftest_step(pc_curr, dut->io_pc);
        #endif
        n--;
    }

    if (npc_state.state == NPC_END) {
        if (npc_state.halt_ret == 0){
            printf(ANSI_FG_GREEN "[NPC] HIT GOOD TRAP" ANSI_NONE "\n");
            res = 0;
        }
        else{
            printf(ANSI_FG_RED "[NPC] HIT BAD TRAP (%d)" ANSI_NONE "\n", npc_state.halt_ret);
            iringbuf_display();
            res = -1;
        }
    } 
    else if (npc_state.state == NPC_ABORT) {
        printf(ANSI_FG_RED "nemu: ABORT" ANSI_NONE "\n");
        iringbuf_display();
        res = -1;
    }
    else if (npc_state.state == NPC_RUNNING) {
        npc_state.state = NPC_STOP;
    }
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    dut = new VNPC_Top;
    long img_size = 0;
    if (argc > 1) {img_size =load_image(argv[1]);}
    else {
        printf("Error: No image provided.\n");
        return 1;
    }

    init_disasm("riscv32");
    #ifdef CONFIG_DIFFTEST
        const char *diff_so_file = "/root/riscvlab/riscv32-nemu-interpreter-so";
        init_difftest(diff_so_file, img_size, 1234);
    #endif
    printf(ANSI_FG_GREEN "--- Simulation Start ---" ANSI_NONE "\n");
    reset(10);


    #ifdef CONFIG_BATCH_MODE
        cpu_exec(-1);
    #else
        sdb_mainloop();
    #endif

    
    delete dut;
    return res;
}