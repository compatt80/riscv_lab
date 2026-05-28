#ifndef __COMMON_H__
#define __COMMON_H__

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <dlfcn.h>


#define MEM_SIZE 0x4000000 
#define MEM_BASE 0x80000000

// 可以在这里或 Makefile 中定义 Trace 开关
//开启指令追踪
#define CONFIG_ITRACE
// 开启实时显示指令
// #define CONFIG_ITRACE_REALTIME
//开启差分测试
 #define CONFIG_DIFFTEST
//开启内存追踪
// #define CONFIG_MTRACE
// #define CONFIG_FTRACE
// #define CONFIG_DTRACE

void init_difftest(const char *ref_so_file, long img_size, int port);
void difftest_step(uint32_t pc, uint32_t npc);
void difftest_skip_ref();
#define DIFFTEST_TO_DUT 0
#define DIFFTEST_TO_REF 1

typedef uint32_t word_t;
typedef uint32_t vaddr_t;
typedef uint32_t paddr_t;

#define FMT_PADDR "0x%08x"
#define FMT_WORD  "0x%08x"

#define ANSI_FG_BLACK   "\33[1;30m"
#define ANSI_FG_RED     "\33[1;31m"
#define ANSI_FG_GREEN   "\33[1;32m"
#define ANSI_FG_YELLOW  "\33[1;33m"
#define ANSI_FG_BLUE    "\33[1;34m"
#define ANSI_FG_MAGENTA "\33[1;35m"
#define ANSI_FG_CYAN    "\33[1;36m"
#define ANSI_FG_WHITE   "\33[1;37m"
#define ANSI_NONE       "\33[0m"

#define ANSI_FMT(str, fmt) fmt str ANSI_NONE

#define Log(format, ...) \
    printf(ANSI_FG_BLUE "[LOG] " ANSI_NONE format "\n", ## __VA_ARGS__)

enum {NPC_RUNNING, NPC_STOP, NPC_END, NPC_ABORT, NPC_QUIT};

typedef struct {
    int state;
    uint32_t halt_pc;
    uint32_t halt_ret;
} NPCState;

extern NPCState npc_state;
extern uint64_t g_timer;

extern "C" {
    // memory.cpp
    int pmem_read(int raddr);
    void pmem_write(int waddr, int wdata, char wmask);
    
    // reg.cpp
    void set_gpr_value(int idx, int data);

    // disasm.cpp 
    void init_disasm(const char *triple);
    void disassemble(char *str, int size, uint64_t pc, uint8_t *code, int nbyte);

    // trace.cpp 
    // ITRACE
    void iringbuf_write(uint32_t pc, uint32_t inst);
    void iringbuf_display();

    // MTRACE
    void pread_display(uint32_t addr, int len);
    void pwrite_display(uint32_t addr, int len);

    // FTRACE
    void init_ftrace(const char *elf_file);
    void ftrace_write(int type, uint32_t pc, uint32_t target);

    // DTRACE
    void dtrace_display(const char *name, int type, uint32_t addr, int len, uint32_t data);
}

long load_image(char const *img_file);
void isa_reg_display();
void sdb_mainloop();
void cpu_exec(uint64_t n);

#endif