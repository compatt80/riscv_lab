#include "../include/common.h"

extern "C" void npc_itrace(int pc, int next_pc, int inst) {
#ifdef CONFIG_ITRACE
    // 将指令写入环形缓冲区 (用于出错后的回溯)
    iringbuf_write(pc, inst);
    
    #ifdef CONFIG_ITRACE_REALTIME
        char buf[128];
        //调用反汇编库(llvm/capstone)，将二进制inst转为汇编字符串
        disassemble(buf, sizeof(buf), pc, (uint8_t *)&inst, 4);
        //打印格式：PC地址:机器码汇编指令
        printf("ITRACE: 0x%08x: %08x %s\n", pc, inst, buf);
    #endif
#endif
}