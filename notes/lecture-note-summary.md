# Lecture Notes Summaries



## 南京大学计算机系统基础课程实验 2025

Document Path: `specs/lecture-notes/01_PA讲义/00_PA_index.md`

Summary: This document is the main index and introductory guide for NJU's 2025 Computer Systems Basics Programming Assignment (PA). It explains the goal of building a simplified but complete computer system through NEMU, covering topics from Turing machines and debuggers to von Neumann systems, batch processing, multitasking, and performance optimization. It also lists the required Linux/GCC/C environment, recommends online and offline reading methods, and emphasizes academic integrity, effective help-seeking, English technical research, official manuals, and GNU/Linux preparation resources.

## PA0 - 世界诞生的前夜: 开发环境配置

Document Path: `specs/lecture-notes/01_PA讲义/01_00_PA0.md`

Summary: This document introduces PA0, the preliminary stage for preparing the development environment before starting the PA computer-system projects. It frames the assignments as a story about a pioneer creating a computer world and explains that even the pioneer must first prepare the necessary tools. The visible instructions emphasize submission requirements and warn students to read them carefully. The estimated average workload for this stage is 10 hours.

## Preparation

Document Path: `specs/lecture-notes/01_PA讲义/01_01_PA0_0.1.md`

Summary: This document introduces PA0 as preparation for the GNU/Linux development environment used in all later PAs and labs. It emphasizes careful independent reading, English technical reading practice, and the expectation that students search for troubleshooting information themselves. The main setup task is to install a 64-bit GUI GNU/Linux system, preferably Ubuntu 22.04 on a physical machine or in a virtual machine, after backing up important data and reserving enough disk space. It then instructs students to find an Ubuntu 22.04 installation tutorial, avoid Ubuntu Software Updater during installation and first login, and choose English as the system language to make command-line work and error searching easier.

## First Exploration with GNU/Linux

Document Path: `specs/lecture-notes/01_PA讲义/01_02_PA0_0.2.md`

Summary: This document introduces students to the GNU/Linux terminal and explains the basic shell prompt, including username, hostname, and current working directory. It encourages using the CLI over relying only on GUI tools, framing terminal usage as essential for the programming environment. It gives initial commands such as `df -h` to check disk usage and `poweroff` to shut down the system. It also explains possible privilege issues with `poweroff`, how to switch to root with `su -`, and warns virtual machine users not to force-close the VM to avoid file corruption.

## Installing Tools

Document Path: `specs/lecture-notes/01_PA讲义/01_03_PA0_0.3.md`

Summary: This document guides students through preparing an Ubuntu environment for the PA assignments by checking network connectivity, configuring APT mirrors, and installing required development tools. It explains how to use `sudo`, add a user to the `sudo` group, update package information, and troubleshoot common mirror resolution issues. It lists essential packages such as build tools, manuals, GCC documentation, GDB, Git, readline, and SDL2 libraries, and ends by instructing students to install a Chinese input method separately.

## Configuring vim

Document Path: `specs/lecture-notes/01_PA讲义/01_04_PA0_0.4.md`

Summary: This document introduces installing, learning, and configuring Vim for use throughout the PA and Lab assignments. It explains how students should practice with `vimtutor` or other tutorials, emphasizes hands-on learning and independent web searching, and demonstrates Vim's power through recording, replaying, and visual block editing examples. The main task is to copy `/etc/vim/vimrc` to `~/.vimrc`, edit it with Vim, enable syntax highlighting, and uncomment or append recommended settings for features such as filetype indentation, search behavior, line numbers, folding, and status display.

## More Exploration

Document Path: `specs/lecture-notes/01_PA讲义/01_05_PA0_0.5.md`

Summary: This document continues PA0 by encouraging students to explore GNU/Linux tools and develop independent problem-solving habits. It covers using manuals and web search effectively, writing and compiling a "Hello World" program with a Makefile, learning basic GDB usage, and installing/configuring tmux for multi-terminal workflows. It also explains why Linux command-line tools and Unix philosophy improve programmer productivity, lists core commands students should practice, and emphasizes asking technical questions clearly with reproducible details and prior troubleshooting attempts.

## Getting Source Code for PAs

Document Path: `specs/lecture-notes/01_PA讲义/01_06_PA0_0.6.md`

Summary: This document guides students through obtaining and initializing the PA source code, configuring Git, setting environment variables, and avoiding root-user development. It explains the required Git branch workflow, basic commits, compiling and running NEMU, debugging with gdb, and checking development tracing logs. It also describes local manual commits, report-writing expectations, and PA0 submission requirements, including placing a PDF report in the project directory. The required report task asks students to write at least 800 Chinese characters reflecting on smart questioning, STFW/RTFM, and independent problem solving.

## PA1 - 开天辟地的篇章: 最简单的计算机

Document Path: `specs/lecture-notes/01_PA讲义/02_00_PA1.md`

Summary: This document introduces PA1, focused on building and understanding the simplest computer model through basic digital circuit concepts and the idea of a Turing machine. It gives required Git branch-management commands to run before starting, including committing, merging `pa0` into `master`, and creating a `pa1` branch. The assignment is estimated to take about 30 hours and is divided into staged tasks: implementing single-step execution, register printing, memory scanning, arithmetic expression evaluation, and finally completing all required work with a full lab report.

## 在开始愉快的PA之旅之前

Document Path: `specs/lecture-notes/01_PA讲义/02_01_PA1_1.1.md`

Summary: This document introduces PA as a new kind of systems-training assignment whose goal is to understand how programs run by building NEMU, a simplified full-system emulator. It explains what emulation means through NES emulator and ATM analogies, compares normal Linux execution with running programs inside simulated hardware, and emphasizes independent debugging, reading manuals, using proper tools, and avoiding procrastination. It also introduces ISA selection among x86, mips32, riscv32, and riscv64, noting that course students must choose riscv32 and that `$ISA` in later notes refers to the chosen architecture. Important tasks include trying FCEUX, checking display/input/audio, cloning and running `am-kernels` input tests, experimenting with parallel `make`, optionally configuring `ccache`, collecting official manuals, and keeping ongoing experiment notes.

## 开天辟地的篇章

Document Path: `specs/lecture-notes/01_PA讲义/02_02_PA1_1.2.md`

Summary: This document introduces the simplest model of a stored-program computer, explaining memory, the CPU, registers, an adder, instructions, and the program counter through a small instruction sequence that computes 1+2+...+100. It frames the computer as a state machine whose execution cycle repeatedly fetches an instruction from the PC, executes it, and updates the PC. It then extends this view to programs themselves, showing that running a program corresponds to deterministic state transitions from an initial machine state. The main task is for students to trace and draw the state-machine execution of the example program, especially through its loop, to build a microscopic understanding of how programs run.

## RTFSC

Document Path: `specs/lecture-notes/01_PA讲义/02_03_PA1_1.3.md`

Summary: This document guides students through reading and understanding the NEMU framework code for the simple TRM model. It introduces the project structure, NEMU's monitor, CPU, memory, device modules, ISA-specific abstraction, kconfig configuration system, Makefile build flow, and how guest programs are loaded and executed. It explains monitor initialization, built-in and image-based guest programs, register and memory setup, the simple debugger loop, `cpu_exec()`, `nemu_trap`, and useful debugging macros. Important tasks include implementing the x86 register structure if using x86, removing the intentional assertion in `welcome()`, running the first guest program, using GDB to understand execution, and fixing the error shown when quitting NEMU directly.

## 基础设施: 简易调试器

Document Path: `specs/lecture-notes/01_PA讲义/02_04_PA1_1.4.md`

Summary: This document introduces infrastructure as a key factor in development efficiency, using NEMU's Simple Debugger (sdb) as the main PA1 example. It explains the required debugger commands, including stepping, register display, memory scanning, expression evaluation, and watchpoints, while noting which commands are already implemented. The lecture gives implementation guidance for command parsing with readline, strtok, sscanf, single-step execution, ISA-specific register display, and a simplified first version of memory scanning. It emphasizes careful testing of each debugger feature because bugs in infrastructure can become much more costly to diagnose later.

## 表达式求值

Document Path: `specs/lecture-notes/01_PA讲义/02_05_PA1_1.5.md`

Summary: This document explains how to add expression evaluation to NEMU's simple debugger, starting with lexical analysis of arithmetic expressions using regular expressions and token storage. It then describes recursive expression evaluation based on BNF grammar, including parenthesis checking, main-operator selection, precedence, associativity, and unsigned 32-bit results. The lecture emphasizes disciplined debugging practices, assertions, GDB, the KISS principle, and connects expression parsing to compiler concepts such as lexical analysis, parsing, and code generation. It also instructs students to implement a random expression generator in `nemu/tools/gen-expr/gen-expr.c` to produce large test suites, handle details such as unsigned arithmetic, spaces, buffer limits, and division by zero, then compare NEMU's `expr()` results against generated expected outputs.

## 监视点

Document Path: `specs/lecture-notes/01_PA讲义/02_06_PA1_1.6.md`

Summary: This document explains how to implement watchpoints in NEMU's simple debugger by extending expression evaluation to support hexadecimal numbers, registers, equality/logical operators, and pointer dereference. It describes managing watchpoint structures with a pool and linked lists, adding commands to create, inspect, and delete watchpoints, and checking them during CPU execution with an optional CONFIG_WATCHPOINT switch. It also teaches debugging principles around faults, errors, failures, segmentation faults, assertions, printf, GDB, and sanitizers, then briefly shows how breakpoints can be simulated with watchpoints and discusses breakpoint efficiency and implementation ideas.

## 如何阅读手册

Document Path: `specs/lecture-notes/01_PA讲义/02_07_PA1_1.7.md`

Summary: This document teaches students how to read technical manuals efficiently during PA work, emphasizing use of the table of contents, targeted searching, and narrowing the scope of relevant information. It explains that looking up documentation is a domain-independent skill and encourages students to practice search, filtering, and keyword refinement instead of reading entire manuals linearly. The required report tasks include drawing a state machine for a summation program, calculating the debugging time saved by the simple debugger, locating ISA manual sections for specific x86/MIPS32/RISC-V questions, counting NEMU source lines with shell commands, and explaining GCC's `-Wall` and `-Werror`. It ends by instructing students to finish the PA1 report, name it as `学号.pdf`, place it in the project directory, and submit with `make submit`.

## PA2 - 简单复杂的机器: 冯诺依曼计算机系统

Document Path: `specs/lecture-notes/01_PA讲义/03_00_PA2.md`

Summary: This document introduces PA2, focused on building toward a von Neumann computer system from simple digital machine components. It frames the assignment as the second chapter of the project story and emphasizes the expanded capabilities that emerge from the basic machine. Before starting, students must organize Git branches with the specified commit, checkout, merge, and branch commands or risk grade impact. The assignment is expected to take about 40 hours and is divided into PA2.1 implementing more instructions and passing most NEMU cpu-tests, PA2.2 implementing klib and infrastructure, and PA2.3 running FCEUX and submitting the full lab report.

## 不停计算的机器

Document Path: `specs/lecture-notes/01_PA讲义/03_01_PA2_2.1.md`

Summary: This document introduces PA2 as the point where students must begin deeply reading and understanding NEMU code rather than only following explicit guideposts. It explains the CPU instruction cycle through instruction fetch, decode, execute, and PC update, emphasizing the stored-program model and how instructions encode opcodes and operands. It then presents YEMU, a tiny C CPU simulator with registers, memory, a PC, and four simple instructions, showing how a program computes `16 + 33`. Important tasks include understanding how YEMU executes instructions, drawing the state machine for the sample addition program, and connecting that state-machine view to the simulator source code.

## RTFM

Document Path: `specs/lecture-notes/01_PA讲义/03_02_PA2_2.2.md`

Summary: This document explains how to study ISA manuals and NEMU source code to understand instruction behavior, opcode encoding, and the full instruction execution cycle. It walks through NEMU's fetch, decode, execute, and PC-update stages, including pattern-based instruction decoding, operand extraction, `snpc` versus `dnpc`, and ISA-specific details such as x86 variable-length instructions and MIPS branch delay slots. It emphasizes structured programming, avoiding copy-paste implementations, and using RTFM/RTFSC plus GDB to understand and debug the system. The main tasks are to clone and use `am-kernels`, implement the missing instructions needed to run the `dummy` C program in NEMU, then add more instructions incrementally to pass additional CPU tests.

## 程序, 运行时环境与AM

Document Path: `specs/lecture-notes/01_PA讲义/03_03_PA2_2.3.md`

Summary: This document explains why programs need a runtime environment beyond instruction support, introducing minimal TRM execution and the role of `halt()`/`nemu_trap` in ending programs on NEMU. It presents Abstract Machine (AM) as a library-based abstraction that decouples programs from architecture-specific details through modules such as TRM, IOE, CTE, VME, and MPE. It walks through the `abstract-machine` and `am-kernels` project structure, key TRM APIs, cross-compilation, linker scripts, startup flow from `start.S` to `_trm_init()` and `main()`, and how AM-built programs run on `$ISA-nemu`. Important tasks include reading AM/NEMU source and Makefiles, understanding AM APIs, and modifying Makefiles so AM can start NEMU in batch mode by default.

## 基础设施(2)

Document Path: `specs/lecture-notes/01_PA讲义/03_04_PA2_2.4.md`

Summary: This document explains PA2.2 infrastructure for debugging, testing, and validating NEMU and AM-based programs. It introduces tracing tools such as itrace, iringbuf, mtrace, and ftrace, including tasks to implement ring-buffer instruction history, memory tracing, ELF-based function tracing, and related analysis exercises. It then describes using AM's native target to isolate and test klib, asks students to build klib-tests for memory/string/formatting functions, and introduces differential testing with REF simulators to compare instruction-level state. The document closes with regression testing for cpu-tests and broader reflections on NEMU as a universal program, plus optional thinking tasks such as detecting infinite loops.

## 输入输出

Document Path: `specs/lecture-notes/01_PA讲义/03_05_PA2_2.5.md`

Summary: This document introduces input/output in computer systems, explaining device registers, port-mapped I/O, memory-mapped I/O, volatile, and how I/O extends the state-machine view of program execution. It then explains how NEMU models device mappings and implements serial, timer, keyboard, VGA, and optional audio devices through AM's IOE abstraction. The main tasks include implementing x86 `in`/`out` if needed, `printf`, timer uptime, keyboard input, VGA screen-size/sync/framebuffer drawing, dtrace, simple `malloc`/`free`, and optional audio support. It also instructs students to validate their work with AM tests, benchmarks, demos, Bad Apple, and FCEUX while emphasizing RTFSC, debugging discipline, and "finish first, optimize later."

## PA3 - 穿越时空的旅程: 批处理系统

Document Path: `specs/lecture-notes/01_PA讲义/04_00_PA3.md`

Summary: This document introduces PA3, focused on building a batch processing system on a von Neumann-style computer model. It gives required Git branch management commands before starting, including committing, switching to master, merging PA2, and creating the PA3 branch. The assignment is estimated to take about 40 hours and is divided into three tasks: implementing the trap operation `yield()`, implementing user program loading and system calls for TRM programs, and running Chinese Paladin to demonstrate the batch system with a complete lab report.

## 批处理系统

Document Path: `specs/lecture-notes/01_PA讲义/04_01_PA3_3.1.md`

Summary: This document introduces PA3 as a step up in system complexity and frames batch processing as an early operating-system role: automatically loading and running the next program after one finishes. It explains why switching execution flow between user programs and the operating system requires controlled entry points rather than ordinary function calls. The lecture then discusses hardware privilege mechanisms across architectures such as x86, MIPS, and RISC-V, showing how illegal privileged operations raise exceptions for OS handling. It notes that PA/NEMU will simplify this by not implementing full protection, while still emphasizing that understanding privilege and exception behavior is central to real computer systems.

## 异常响应机制

Document Path: `specs/lecture-notes/01_PA讲义/04_02_PA3_3.2.md`

Summary: This document explains how exception/trap response mechanisms let user programs transfer control to controlled operating-system entry points, comparing x86 `int`, MIPS32 `syscall`, and RISC-V `ecall`. It describes how hardware saves program state, jumps to exception entry addresses, and later returns via `iret`, `eret`, or `mret`, then reframes the mechanism as a deterministic state-machine extension. It introduces AM's CTE abstraction for context management, including `Event`, architecture-specific `Context`, `cte_init()`, and `yield()`. The main task is to implement trap instructions and `isa_raise_intr()` in NEMU, configure the exception entry path for the selected ISA, run the `yield test`, and add DiffTest-related state initialization where required.

## 用户程序和系统调用

Document Path: `specs/lecture-notes/01_PA讲义/04_03_PA3_3.3.md`

Summary: This document introduces Nanos-lite as a minimal operating system for PA, explaining its startup flow, event handling, and relationship to AM. It walks through loading the first Navy user program from a ramdisk by implementing an ELF loader, checking ELF metadata, and transferring control to the program entry. It then explains the operating system runtime environment and system calls, including how trap instructions pass syscall requests and how to implement SYS_yield, SYS_exit, SYS_write, and SYS_brk. The document also assigns tasks such as enabling CTE event dispatch, building and running dummy/hello programs, adding simple strace support, and answering a required report question tracing how the hello program is compiled, loaded, executed, and prints output.

## 简易文件系统

Document Path: `specs/lecture-notes/01_PA讲义/04_04_PA3_3.4.md`

Summary: This document explains how to implement a Simple File System in Nanos-lite to manage fixed-size files stored in ramdisk and expose file operations through descriptors. It covers implementing open, read, write, lseek, and close, updating the loader to use file names, adding related syscalls, and testing with Navy applications. It then introduces the Unix idea that everything is a file and extends the design into a VFS using function pointers for ordinary files and special device files. Major tasks include supporting serial output, gettimeofday and NDL timers, keyboard events via /dev/events, display info via /proc/dispinfo, and framebuffer drawing via /dev/fb.

## 精彩纷呈的应用程序

Document Path: `specs/lecture-notes/01_PA讲义/04_05_PA3_3.5.md`

Summary: This PA3.5 lecture explains how to enrich Navy's runtime so more complex applications can run, focusing on miniSDL, fixed-point arithmetic, native testing, multimedia libraries, and compatibility layers. It walks through implementing and testing support for applications such as NSlider, MENU, NTerm, Flappy Bird, PAL, AM kernels, FCEUX, oslab0 games, and optional audio-enabled programs. The document also introduces debugging and infrastructure tasks including attach/detach DiffTest mode, NEMU snapshots, and using native layers to isolate bugs. Finally, it instructs students to implement execve-based program launching, improve MENU/NTerm into a simple batch system, answer required system-understanding questions, and submit the PA3 report.

## PA4 - 虚实交错的魔法: 分时多任务

Document Path: `specs/lecture-notes/01_PA讲义/05_00_PA4.md`

Summary: This PA4 overview introduces virtualization concepts needed to support time-sharing multitasking on a computer capable of running an OS and real applications. It instructs students to prepare their Git branches before starting PA4, including committing, merging PA3 into master, and creating a PA4 branch. The work is estimated at 40 hours and is organized into three tasks: implementing a basic multiprogramming system, adding virtual memory management support, and building a preemptive time-sharing multitasking system with a complete lab report.

## 多道程序

Document Path: `specs/lecture-notes/01_PA讲义/05_01_PA4_4.1.md`

Summary: This document introduces multiprogramming in PA4, explaining how an OS can keep multiple processes in memory and switch execution among them when useful, especially during I/O waits. It focuses on context switching via CTE, PCB-managed context pointers and stacks, kernel thread creation with `kcontext()`, scheduling, and the separation of mechanism from policy. It then extends these ideas to RT-Thread and Nanos-lite, with tasks to implement context creation/switching, user process contexts with `ucontext()`, user stacks, argument passing through `argc/argv/envp`, and `execve()`. The later sections cover running Busybox commands under Nanos-lite, supporting `PATH` lookup through `execvp()`, and handling missing executable errors with `errno`.

## Programs and Memory Locations

Document Path: `specs/lecture-notes/01_PA讲义/05_02_PA4_4.2.md`

Summary: This document explains why fixed program load addresses cause memory overlap in a multitasking system when multiple user processes are loaded. It compares absolute code, runtime/load-time relocation, PIC, and PIE as approaches to making programs runnable at different memory locations. It then introduces virtual memory as a hardware-software solution that separates a process's virtual addresses from physical memory using the MMU. The document also briefly describes segmentation as a simple virtual memory mapping method and notes that NEMU does not need to implement i386 segmentation details.

## 超越容量的界限

Document Path: `specs/lecture-notes/01_PA讲义/05_03_PA4_4.3.md`

Summary: This document explains why modern systems use paging rather than segmentation, covering virtual-to-physical page mapping, page tables, i386-style page walks, protection bits, TLB behavior, and ISA differences for x86, RISC-V, and MIPS. It introduces AM's VME abstraction with APIs such as `protect()`, `unprotect()`, `map()`, `vme_init()`, and `ucontext()`, then describes how Nanos-lite should run on top of paging. The main implementation tasks are to add page allocation, implement VME mapping, implement NEMU MMU checking and translation, support user address spaces and user stacks, update context switching to switch address spaces, and implement `mm_brk()` for heap growth. It also discusses optional DiffTest paging support, MIPS software-managed TLB work, kernel mappings, and the challenges of running multiple user processes under virtual memory.

## 分时多任务

Document Path: `specs/lecture-notes/01_PA讲义/05_04_PA4_4.4.md`

Summary: This document explains time-sharing multitasking, contrasting cooperative multitasking based on voluntary `SYS_yield` with preemptive multitasking driven by hardware timer interrupts. It describes how interrupts reach the CPU, how different ISAs represent interrupt-enable state, and what changes are required in NEMU, AM/CTE, and Nanos-lite to implement timer-interrupt-based preemption and time-slice scheduling. The lecture then analyzes how interrupts introduce nondeterminism and concurrency risks, including shared-state bugs and CTE re-entry. It also explains why multiple user processes require kernel/user stack switching, details the circular dependency caused by saving contexts on user stacks, and gives ISA-specific implementation guidance for mips32, riscv32, and x86.

## 编写不朽的传奇

Document Path: `specs/lecture-notes/01_PA讲义/05_05_PA4_4.5.md`

Summary: This final PA document presents optional extensions and wrap-up tasks for showcasing the completed computer system, including switching among multiple foreground programs and porting/running ONScripter on Navy, AM native, and NEMU. It details required library work for miniSDL, SDL_image, SDL_mixer audio mixing, timer/event/file abstractions, audio format conversion, and disk support across AM, Nanos-lite, and NEMU. It then previews operating-system concepts such as virtualization, concurrency bugs, persistence, crash consistency, and window management through NWM. The document ends with required report questions about time-sharing with paging and interrupts, string write protection and segmentation faults in Linux, and final submission instructions.

## PA5 - 天下武功唯快不破: 程序与性能

Document Path: `specs/lecture-notes/01_PA讲义/06_00_PA5.md`

Summary: This document introduces PA5 as an optional programming assignment focused on program performance and making programs run faster. It frames the topic as a continuation of the PA storyline after building a functional modern computer. The only explicit instruction is that PA5 is optional and does not count toward the PA grade.

## 浮点数的支持

Document Path: `specs/lecture-notes/01_PA讲义/06_01_PA5_5.1.md`

Summary: This document explains how to support floating-point-like arithmetic for PAL by using binary scaling instead of implementing x87 floating-point instructions in NEMU. It defines a 32-bit fixed-point `FLOAT` format with 1 sign bit, 15 integer bits, and 16 fractional bits, and describes how real numbers, negative values, arithmetic, comparisons, and conversions work under this representation. Addition, subtraction, and comparisons can use integer operations directly, while multiplication and division require scaling adjustments. The main task is to implement several `FLOAT` conversion and arithmetic functions in `navy-apps/apps/pal/include/FLOAT.h` and `navy-apps/apps/pal/src/FLOAT/FLOAT.c`, enabling battles in PAL to work correctly.

## 通往高速的次元

Document Path: `specs/lecture-notes/01_PA讲义/06_02_PA5_5.2.md`

Summary: This document introduces performance optimization for NEMU after it can run real programs, emphasizing that optimization should target actual hot spots rather than guessed bottlenecks. It explains Amdahl's law and the KISS principle as motivation for avoiding premature or low-impact optimization. The main practical instruction is to use Linux `perf` with `perf record` and `perf report` to collect and inspect profiling data for NEMU. It also notes that profilers can reveal implementation-level performance issues but may not expose deeper design-level bottlenecks in a teaching simulator.

## 天下武功唯快不破

Document Path: `specs/lecture-notes/01_PA讲义/06_03_PA5_5.3.md`

Summary: This document explains why NEMU is slow: as a software interpreter, it must execute many native instructions to simulate each guest instruction. It introduces just-in-time compilation as a way to reduce this overhead by translating guest instructions into reusable native code stored in translation blocks, indexed by the guest PC. The lecture discusses compiling whole basic blocks instead of single instructions, using RTL as an intermediate representation to separate front ends for guest ISAs from back ends for host architectures. It concludes by noting that implementing JIT is difficult and encourages students to study QEMU and experiment with improving NEMU performance.

## 常见问题(FAQ)

Document Path: `specs/lecture-notes/01_PA讲义/99_01_FAQ.md`

Summary: This FAQ explains the purpose, difficulty, expectations, and philosophy of the PA Programming Assignment, emphasizing independent problem solving, system-level understanding, debugging discipline, and academic integrity. It clarifies that PA is not a traditional hardware architecture lab but a C-based simulator and software stack project intended to train students for complex, uncertain engineering tasks. The document warns against copying code, reading public guides, publishing solutions, or expecting reference answers, and instructs students to use STFW/RTFM/RTFSC before asking well-prepared questions. It also discusses time expectations, appropriate goals for students with different programming backgrounds, the relationship between PA and OSlab, and why the course intentionally prioritizes hard training over easier guidance.

## 为什么要学习计算机系统基础

Document Path: `specs/lecture-notes/01_PA讲义/99_02_why.md`

Summary: This document explains why studying computer systems fundamentals is necessary beyond knowing high-level programming syntax. It uses puzzling C program behaviors involving unsigned arithmetic, integer overflow, linking, memory layout, cache locality, calling conventions, and exceptions to show that program results depend on underlying execution mechanisms. It argues that computer science students' core advantage is system-level understanding, including abstraction layers, hardware/software interaction, performance analysis, debugging, portability, and robust design. It also emphasizes hands-on practice as essential for turning superficial knowledge into deep understanding, framed around the question of what really happens when a Hello World program runs.

## Linux入门教程

Document Path: `specs/lecture-notes/01_PA讲义/99_03_linux.md`

Summary: This document is an introductory Linux command-line tutorial for first-time users, encouraging readers to run commands while learning. It covers basic shell commands, man pages, pipes, regular expressions, line counting, disk usage inspection, paging output, compiling and running a C Hello World program, input/output redirection, and Makefile basics. It also includes a larger shell-script example for querying grades, using wget, cookies, sed, awk, cron, and Unix philosophy to show how small text-oriented tools can be combined to solve practical tasks.

## man快速入门

Document Path: `specs/lecture-notes/01_PA讲义/99_04_man.md`

Summary: This document is an introductory tutorial on using the Linux `man` command and learning how to find help independently. It walks beginners through `man man`, navigating the manual viewer with `less`, using help, quitting, scrolling, and searching within manual pages. It explains the structure of manual pages, common sections such as NAME, SYNOPSIS, DESCRIPTION, OPTIONS, EXAMPLES, and SEE ALSO, and how manual categories distinguish commands from library functions. It highlights `man -k` as a way to search for relevant manual pages by keyword and encourages students to read prompts, search effectively, practice commands, and rely on documentation before asking others.

## git快速入门

Document Path: `specs/lecture-notes/01_PA讲义/99_05_git.md`

Summary: This document introduces Git as a version control system for saving and restoring progress during programming work, using a "save/load" analogy. It covers installing and configuring Git, cloning or initializing repositories, checking history and status with `git log` and `git status`, tracking files with `git add`, using `.gitignore`, and committing changes with meaningful messages. It explains how to restore previous versions with `git reset --hard`, warns that this can delete newer history, and presents branches and `git checkout` as safer ways to inspect or preserve alternate versions. It briefly points to additional Git tools such as `git diff`, `git bisect`, `git help`, and `man git` for further learning.

## NEMU ISA API Reference

Document Path: `specs/lecture-notes/01_PA讲义/99_06_nemu-isa-api.md`

Summary: This document defines the ISA-related API surface that NEMU expects each architecture implementation to provide. It covers global word types and formatting, monitor initialization hooks, CPU register state and display/query helpers, instruction decoding and execution, virtual memory checks and address translation, interrupt and exception handling, and DiffTest integration. It specifies required variables, functions, return values, and important semantics such as reset PC setup, `cpu.pc`, MMU result codes, and register comparison behavior.

## 更新日志

Document Path: `specs/lecture-notes/01_PA讲义/99_07_changelog.md`

Summary: This document is a changelog for the ICS PA lecture/project materials across ICS2021 through ICS2024. It records updates to NEMU, Abstract-Machine, am-kernels, Nanos-lite, and Navy-apps, grouping changes into features, fixes, refactors, build changes, performance improvements, and documentation updates. Major topics include ISA/platform support, DiffTest and disassembly changes, build-system fixes, runtime bug fixes, test/application additions, and compatibility updates for Linux, macOS, LLVM, GCC, SDL, and related tools. The entries primarily serve as a reference for tracking project evolution and linked patch commits rather than as step-by-step student instructions.

## x86指令系统简介

Document Path: `specs/lecture-notes/01_PA讲义/99_08_i386-intro.md`

Summary: This document introduces the i386/x86 instruction system as background for implementing x86 instructions in NEMU. It explains the general instruction encoding format, including prefixes, opcodes, ModR/M, SIB, displacement, and immediate fields, and notes which features are simplified away in PA. Using the MOV instruction as a detailed example, it teaches how to read i386 manual opcode tables, distinguish Intel and AT&T operand order, interpret operand-size prefixes, register encodings, moffs operands, embedded register opcodes, and extended opcode fields. It instructs students to consult the corrected i386 manual for exact instruction details and to focus on functional behavior, while generally ignoring timing, segmentation, and exceptions in the PA setting.

## x86的mov指令执行例子剖析

Document Path: `specs/lecture-notes/01_PA讲义/99_09_exec.md`

Summary: This document explains how x86 `mov` instructions are executed in NEMU using two examples: a simple immediate-to-register move and a more complex immediate-to-memory `movw`. It walks through instruction fetch, decode, execute, and PC update, including opcode matching, operand-width handling, immediate extraction, and use of macros like `Rw()` and `RMw()`. It also introduces x86 opcode extension mechanisms, operand-size prefixes, `ModR/M` and `SIB` bytes, and how memory addresses such as `-0x2000(%ecx,%ebx,4)` are decoded. The main task for readers is to understand how NEMU's decoding helpers prepare operands and addresses so the execution phase can perform the actual data movement.

## C1 工具和基础设施

Document Path: `specs/lecture-notes/02_C阶段讲义/01_C1.md`

Summary: This document introduces C1 tools and infrastructure. The lecture content is not yet ready, so students are instructed to study using the linked slides and video instead. The main practical task is to follow the PA handout and complete PA2 phase 2 until reaching the "PA2阶段2到此结束" prompt.

## C2 支持RV32E的单周期NPC

Document Path: `specs/lecture-notes/02_C阶段讲义/02_C2.md`

Summary: This document guides students in upgrading an NPC from the minimal minirv ISA to RV32E to improve program performance by reducing instruction count. It emphasizes building debugging infrastructure for NPC, including sdb, trace support, and DiffTest with NEMU as the reference model. It then instructs students to complete the `riscv32e-npc` AM runtime, implement RV32E instructions in RTL, and rerun previous tests on the upgraded NPC. The lecture also assigns reflection and investigation tasks around ALU synthesis, signed versus unsigned behavior, processor architecture diagrams, and using higher-level debugging tools instead of relying only on waveforms.

## C3 调试技巧

Document Path: `specs/lecture-notes/02_C阶段讲义/03_C3.md`

Summary: This short document is a placeholder for the C3 lecture section on debugging techniques. The full lecture content is not yet ready, and the section currently has no programming tasks. Students are instructed to study the linked slides and video instead.

## C4 ELF文件和链接

Document Path: `specs/lecture-notes/02_C阶段讲义/04_C4.md`

Summary: This document is for the C4 lecture on ELF files and linking. The lecture notes are not yet ready, and there is no programming work for this subsection. Students are instructed to study using the linked slides and video instead.

## C5 异常处理和RT-Thread

Document Path: `specs/lecture-notes/02_C阶段讲义/05_C5.md`

Summary: This document guides students through adding exception handling and RT-Thread support after completing IOE. It first instructs them to implement trap handling in NEMU and run RT-Thread, then explains how to add required RISC-V CSRs such as `mcycle`, `mcycleh`, `mvendorid`, and `marchid` in NPC. It covers implementing CSR access, simple exception handling with `ecall` and `mret`, and running RT-Thread on NPC while noting a possible final prompt output issue. The document ends by directing students to apply for the C-stage completion assessment, which is required before participating in the B-stage tapeout assessment.

## B1 总线

Document Path: `specs/lecture-notes/03_B阶段讲义/01_B1.md`

Summary: This lecture introduces buses as hardware communication protocols between processor modules and between the CPU, memory, and devices. It explains valid/ready handshakes, asynchronous bus RTL implementation, distributed processor control, SimpleBus evolution, AXI4-Lite, APB/AXI concepts, arbitration, crossbars, and memory-mapped I/O. The document assigns implementation tasks such as refactoring NPC around bus-style module connections, adding SimpleBus and AXI4-Lite support to IFU/LSU and memory, adapting DiffTest for multi-cycle execution, testing with random delays, implementing an AXI4-Lite arbiter/Xbar, and adding UART and CLINT devices.

## B2 SoC计算机系统

Document Path: `specs/lecture-notes/03_B阶段讲义/02_B2.md`

Summary: This lecture explains how to integrate an NPC processor into the ysyxSoC environment and gradually build a usable SoC computer system. It covers AXI4/AXI4-Lite issues, MROM/SRAM startup, AM runtime support, DiffTest restoration, UART output, bootloading, flash/SPI/XIP execution, PSRAM and SDRAM simulation models, and memory testing. It then extends the system with GPIO, UART RX/TX through NVBoard, PS/2 keyboard, VGA, RT-Thread application support, and optional ChipLink access to off-chip resources. The document is task-heavy, repeatedly instructing students to implement device models/controllers, write AM tests such as char-test and mem-test, adjust linker scripts and bootloaders, RTFM/RTFSC hardware protocols, and verify behavior through simulation.

## B3 时序分析和优化

Document Path: `specs/lecture-notes/03_B阶段讲义/03_B3.md`

Summary: This document is a placeholder for a lecture section on timing analysis and optimization. It indicates that the page is still under construction. There is currently no programming content or actionable task included.

## B4 性能优化和简易缓存

Document Path: `specs/lecture-notes/03_B阶段讲义/04_B4.md`

Summary: This lecture explains how to optimize NPC performance scientifically by measuring benchmark runtime, dynamic instruction count, IPC, frequency, performance events, and Amdahl's law instead of relying on intuition. It covers memory-latency calibration in ysyxSoC, performance counters, benchmark selection, cache motivation from memory hierarchy and locality, and implementation of a simple instruction cache. It then introduces formal verification for icache correctness, cache optimization via AMAT, miss types, associativity, block size, burst transfers, cachesim-based design-space exploration, and area/performance tradeoffs. Important tasks include adding performance counters, implementing APB/AXI delay modules, implementing and verifying icache, supporting larger blocks and AXI burst transfers, recording reproducible performance data, exploring cache parameters under area limits, and handling instruction-cache coherence with `fence.i`.

## B5 流水线处理器

Document Path: `specs/lecture-notes/03_B阶段讲义/05_B5.md`

Summary: This lecture explains why, after icache optimization, improving NPC compute throughput with an instruction pipeline may be more effective than adding dcache under area constraints. It introduces pipeline principles, handshake-based pipeline implementation, and the handling of structural, data, and control hazards, including stalls, flushing, speculative execution, forwarding, and precise exceptions. It assigns students to estimate ideal and expected performance gains, implement a basic pipelined processor with exception support, validate it with microbenchmarks and formal verification, and add performance counters to locate bottlenecks. It then discusses further optimizations such as pipelined icache access, RAW bypassing, branch prediction, branchsim, and BTB design, emphasizing quantitative evaluation before RTL implementation.

## E6 完成PA1

Document Path: `specs/lecture-notes/04_E6阶段讲义/01_E6.md`

Summary: This document introduces the E6 stage task of completing PA1 from Nanjing University's Computer Systems course, explaining how PA helps students build a simplified but complete emulator-based computer system through NEMU. It emphasizes that PA develops system-level understanding across simulators, ISA, runtime environments, operating systems, libraries, and applications, while also reflecting industry processor verification workflows. Students are instructed to read the PA FAQ, use the default `riscv32` ISA, and complete PA1 topics including the simple debugger, expression evaluation, watchpoints, and required questions until the PA1 completion prompt appears.

## D1 支持RV32IM的NEMU

Document Path: `specs/lecture-notes/05_D阶段讲义/01_D1.md`

Summary: This document introduces D1, where students begin implementing a RISC-V processor simulator in C after reviewing C through PA1. Its main purpose is to build initial understanding of the RISC-V instruction set and processor behavior before moving on to RTL processor implementation. The lecture content itself is not yet ready, so students are directed to referenced slides and video materials. The required task is to complete the PA guide through PA2 Stage 1 for implementing NEMU with RV32IM support, stopping when the PA2 Stage 1 completion prompt appears.

## D2 程序的机器级表示

Document Path: `specs/lecture-notes/05_D阶段讲义/02_D2.md`

Summary: This document covers the D2 topic of machine-level program representation. The lecture note content is not yet ready, and this section currently has no programming tasks. Students are instructed to study using the linked slide decks and videos for the upper and lower parts of the topic.

## D3 运行时环境

Document Path: `specs/lecture-notes/05_D阶段讲义/03_D3.md`

Summary: This document introduces the runtime environment as an important abstraction layer between programs and computer hardware. The lecture content is not yet complete, so students are directed to the provided slides and video for study. It also explains that stronger infrastructure will be built for later NPC design work. The main task is to follow the PA materials and complete the PA2 section on programs, runtime environments, and AM.

## D4 用RTL实现迷你RISC-V处理器

Document Path: `specs/lecture-notes/05_D阶段讲义/04_D4.md`

Summary: This lecture guides students through upgrading the RTL NPC into a mini RISC-V processor supporting the minirv ISA. It covers modular RTL processor design, implementing `addi`, `jalr`, `ebreak` via DPI-C, and completing the remaining minirv instructions including arithmetic and memory operations. It also explains how to replace simple top-level memory wiring with DPI-C memory access, load programs from files, and run earlier `sum` and `mem` tests. Finally, it instructs students to integrate NPC with the AM `minirv-npc` runtime, implement `halt()` with `ebreak`, add HIT GOOD/BAD TRAP reporting, and run broader CPU and RISC-V tests.

## D5 设备和输入输出

Document Path: `specs/lecture-notes/05_D阶段讲义/05_D5.md`

Summary: This document introduces adding input/output support to NEMU and NPC after completing TRM, with an initial instruction to finish PA2 stage 3 in NEMU. It explains that RISC-V I/O is implemented through MMIO and that NPC can temporarily redirect memory accesses to simulated devices through DPI-C `pmem_read()` and `pmem_write()` without changing RTL. The notes describe implementing an NPC device model closer to a future tape-out SoC, relying on AM's IOE abstraction so the same programs can run on NEMU and NPC despite different device models. Key tasks include adding serial output at address `0x10000000`, implementing a timer using system time, running the hello and real-time clock tests, and trying the character version of Super Mario on NPC.

## D6 D阶段流片准备

Document Path: `specs/lecture-notes/05_D阶段讲义/06_D6.md`

Summary: This document guides students through D-stage tapeout preparation for NPC, including adding required CSRs, implementing a valid-signal SimpleBus, and integrating NPC with the provided ysyxSoC Verilator environment. It explains how to connect the CPU interface, boot from Flash, load binaries, run the provided hello program, and generate new binaries using the supplied loader script. It also assigns tasks to run dummy and hello programs, correctly initialize and poll UART16550 output, implement AM clock support using `mcycle`, run the real-time clock test, and try the character-based Super Mario program.
