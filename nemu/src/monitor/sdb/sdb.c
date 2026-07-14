/***************************************************************************************
* Copyright (c) 2014-2024 Zihao Yu, Nanjing University
*
* NEMU is licensed under Mulan PSL v2.
* You can use this software according to the terms and conditions of the Mulan PSL v2.
* You may obtain a copy of Mulan PSL v2 at:
*          http://license.coscl.org.cn/MulanPSL2
*
* THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
* EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
* MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
*
* See the Mulan PSL v2 for more details.
***************************************************************************************/

#include <isa.h>
#include <cpu/cpu.h>
#include <memory/paddr.h>
#include <readline/readline.h>
#include <readline/history.h>
#include "sdb.h"

static int is_batch_mode = false;
static const char *script_text = NULL;
static const char *script_file = NULL;

/* We use the `readline' library to provide more flexibility to read from stdin. */
static char* rl_gets() {
  static char *line_read = NULL;

  if (line_read) {
    free(line_read);
    line_read = NULL;
  }

  line_read = readline("(nemu) ");

  if (line_read && *line_read) {
    add_history(line_read);
  }

  return line_read;
}

static uint64_t parse_count(char *args, uint64_t default_value) {
  if (args == NULL || *args == '\0') return default_value;
  return strtoull(args, NULL, 0);
}

static int cmd_c(char *args) {
  cpu_exec(-1);
  return 0;
}

static int cmd_run(char *args) {
  cpu_exec(parse_count(args, (uint64_t)-1));
  return 0;
}

static int cmd_step(char *args) {
  cpu_exec(parse_count(args, 1));
  return 0;
}

static int cmd_q(char *args) {
  nemu_state.state = NEMU_QUIT;
  return -1;
}

static int cmd_last(char *args) {
  commit_event_dump_last(parse_count(args, 0));
  return 0;
}

static int cmd_print(char *args) {
  if (args == NULL) {
    printf("Usage: print pc|reg [i]|mem <addr> <size>\n");
    return 0;
  }
  char *kind = strtok(args, " ");
  if (kind == NULL) return 0;
  if (strcmp(kind, "pc") == 0) {
    printf("pc = " FMT_WORD "\n", cpu.pc);
  } else if (strcmp(kind, "reg") == 0) {
    char *idx_s = strtok(NULL, " ");
    if (idx_s == NULL) {
      for (int i = 0; i < ARRLEN(cpu.gpr); i ++) {
        printf("x%d = " FMT_WORD "\n", i, cpu.gpr[i]);
      }
    } else {
      int idx = strtol(idx_s, NULL, 0);
      if (idx >= 0 && idx < ARRLEN(cpu.gpr)) printf("x%d = " FMT_WORD "\n", idx, cpu.gpr[idx]);
      else printf("invalid register index %d\n", idx);
    }
  } else if (strcmp(kind, "mem") == 0) {
    char *addr_s = strtok(NULL, " ");
    char *size_s = strtok(NULL, " ");
    if (addr_s == NULL || size_s == NULL) {
      printf("Usage: print mem <addr> <size>\n");
      return 0;
    }
    paddr_t addr = strtoull(addr_s, NULL, 0);
    size_t size = strtoull(size_s, NULL, 0);
    for (size_t off = 0; off < size; off += 4) {
      int len = (size - off >= 4) ? 4 : (int)(size - off);
      paddr_t cur = addr + (paddr_t)off;
      printf("MEM " FMT_PADDR " = " FMT_WORD "\n", cur, paddr_read(cur, len));
    }
  } else {
    printf("Unknown print target '%s'\n", kind);
  }
  return 0;
}

static int cmd_dump(char *args) {
  char *kind = args == NULL ? NULL : strtok(args, " ");
  if (kind == NULL || strcmp(kind, "state") == 0) {
    printf("NEMU_STATE pc=" FMT_WORD " state=%d halt_pc=" FMT_WORD " halt_ret=%u\n",
        cpu.pc, nemu_state.state, nemu_state.halt_pc, nemu_state.halt_ret);
    for (int i = 0; i < ARRLEN(cpu.gpr); i ++) {
      printf("NEMU_REG x%d=" FMT_WORD "\n", i, cpu.gpr[i]);
    }
  } else {
    printf("Usage: dump state\n");
  }
  return 0;
}

static int cmd_help(char *args);

static struct {
  const char *name;
  const char *description;
  int (*handler) (char *);
} cmd_table [] = {
  { "help", "Display information about all supported commands", cmd_help },
  { "c", "Continue the execution of the program", cmd_c },
  { "run", "Run [n] retired instructions", cmd_run },
  { "step", "Step [n] retired instructions", cmd_step },
  { "si", "Alias of step [n]", cmd_step },
  { "print", "Print pc, reg, or memory", cmd_print },
  { "dump", "Dump state", cmd_dump },
  { "last", "Print last [n] CommitEvents", cmd_last },
  { "q", "Exit NEMU", cmd_q },
  { "quit", "Exit NEMU", cmd_q },
  { "exit", "Exit NEMU", cmd_q },
};

#define NR_CMD ARRLEN(cmd_table)

static int cmd_help(char *args) {
  char *arg = args == NULL ? NULL : strtok(args, " ");
  int i;

  if (arg == NULL) {
    for (i = 0; i < NR_CMD; i ++) {
      printf("%s - %s\n", cmd_table[i].name, cmd_table[i].description);
    }
  }
  else {
    for (i = 0; i < NR_CMD; i ++) {
      if (strcmp(arg, cmd_table[i].name) == 0) {
        printf("%s - %s\n", cmd_table[i].name, cmd_table[i].description);
        return 0;
      }
    }
    printf("Unknown command '%s'\n", arg);
  }
  return 0;
}

static int sdb_exec_one(char *str) {
  while (*str == ' ' || *str == '\t' || *str == '\n') str ++;
  char *str_end = str + strlen(str);
  while (str_end > str && (str_end[-1] == ' ' || str_end[-1] == '\t' || str_end[-1] == '\n')) {
    *--str_end = '\0';
  }
  if (*str == '\0') return 0;

  char *cmd = strtok(str, " ");
  if (cmd == NULL) { return 0; }
  char *args = cmd + strlen(cmd) + 1;
  if (args >= str_end) args = NULL;

#ifdef CONFIG_DEVICE
  extern void sdl_clear_event_queue();
  sdl_clear_event_queue();
#endif

  for (int i = 0; i < NR_CMD; i ++) {
    if (strcmp(cmd, cmd_table[i].name) == 0) {
      return cmd_table[i].handler(args);
    }
  }

  printf("Unknown command '%s'\n", cmd);
  return 0;
}

static int sdb_exec_script(char *text) {
  char *saveptr = NULL;
  for (char *cmd = strtok_r(text, ";\n", &saveptr); cmd != NULL; cmd = strtok_r(NULL, ";\n", &saveptr)) {
    if (sdb_exec_one(cmd) < 0) return -1;
  }
  return 0;
}

void sdb_set_batch_mode(void) {
  is_batch_mode = true;
}

void sdb_set_script(const char *script) {
  script_text = script;
}

void sdb_set_script_file(const char *path) {
  script_file = path;
}

void sdb_mainloop() {
  if (script_text != NULL) {
    char *copy = strdup(script_text);
    Assert(copy != NULL, "strdup failed");
    sdb_exec_script(copy);
    free(copy);
    return;
  }

  if (script_file != NULL) {
    FILE *fp = fopen(script_file, "r");
    Assert(fp != NULL, "Can not open script file '%s'", script_file);
    fseek(fp, 0, SEEK_END);
    long size = ftell(fp);
    fseek(fp, 0, SEEK_SET);
    char *buf = malloc(size + 1);
    Assert(buf != NULL, "malloc failed");
    size_t nread = fread(buf, 1, size, fp);
    fclose(fp);
    buf[nread] = '\0';
    sdb_exec_script(buf);
    free(buf);
    return;
  }

  if (is_batch_mode) {
    cmd_c(NULL);
    return;
  }

  for (char *str; (str = rl_gets()) != NULL; ) {
    if (sdb_exec_one(str) < 0) return;
  }
}

void init_sdb() {
}
