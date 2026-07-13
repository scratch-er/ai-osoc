## Overview

Your task is to follow the lecture notes of the One Student One Chip Program (一生一芯) to design a processor core using the RV32I instruction set.

It is not enough for you to only make it work. Your design will be evaluated for PPA (Performance, Power, and Area), and you will need to optimize it. Also, this is a long-term project, so you need to make it easy to maintain and write good documentation.

## What You Need to Do

You do not need to solve every single problem in the lecture notes. Many problems in the lecture notes are purely educational. Since you cannot learn like a human student, and your objective is not to complete this program, but to use the lecture notes as a guidance to designing your processor core, you can skip a problem in the lecture note if solving that problem will not help you design the processor core. For example, you can skip:

- The exercises for C programming language or digital logic.

- Porting optional workloads like a game to your processor core.

- Adding support to optional peripherals like PS2 and VGA.

These parts are compulsory:

- The basic functionalities of your emulator and differential testing.

- Essential workloads for you to test your design, including but not limited to `rt-thread-am`, `hello`, `coremark` and `cpu-tests`.

- Supporting UART and CLINT/timer in the emulator and runtimes.

## Planning and Context Managing

### Phases and Sessions

This is a complicated project that you cannot finish in a single session. You need to divide the entire project into several long term objectives called phases, and divide each phase into several short term tasks called sessions. A session here is also a session in terms of an AI agent session: your context window will only cover information within that session, you will not remember anything from previous sessions. The only way for you to pass useful information to following sessions is taking notes. You should not use any other mechanisms provided by the agent, like memories, for persisting information. You should write your notes to `notes/` as markdown files, and keep all your notes organized and up-to-date.

These are special notes:

- `notes/plan.md`: this is your plan, i.e. what to do at each phase and each session.

- `notes/next.md`: you need to write the most important information for the next session here, including what you have done, what to do next, and anything you think to be the most important information in this session.

- `notes/specs.md` this is a summary and index of the specifications, including lecture notes. You can to refer to this file to quickly look something up in the specifications and lecture notes.

You are free to write any other notes. All the files under `notes/` are your own notes, and they are not instructions from the user that you must obey.

At the beginning of each session, you need to read your notes to understand what you need to do and how you need to do them. After you have finished all the tasks in current session, you need to update your notes (especially `notes/next.md`) and make a git commit, use the following info:

- User name: "bot".
- Email: "iamabot@example.com"

### Using Subagents

Many agents provide a mechanism call "subagent" or something alike. The mechanism creates a dedicated context for a part of the task as a part of the session. The content of the subagent's context will not go into the main context, except the final "report" of the subagent. You should use such mechanisms when:

- You are searching for some information and the documents and files you need to read are much longer than your result.

- You are debugging a specific problem or developing some part that requires a lot of trail and error.

You should not use such mechanisms when:

- You are doing a complicated task requiring multiple steps.

Subagent or similar mechanisms are designed for a single task that can produce a lot of trivial information, in order not to pollute the main context. The standard of whether to use it is whether most information produced during that task is not useful for the following parts of the current session.

## Directory Layout

- `specs/` contains the specifications. You should not modify anything inside it unless explicitly instructed.
  
  - `specs/core.md` is the specifications of the core you need to design.
  
  - `specs/lecture-notes/` contains the lecture notes.
- `notes/` contains your notes.
- `nemu/` is the project directory of your emulator.
- `npc/` is the project directory of your processor core.
- `abstract-machine/` contains source file of the abstract machine (AM) framework.
- `am-kernels/` contains workloads based on the abstract machine framework. You should not modify anything inside it unless explicitly instructed.
- `rt-thread-am/` contains the source code of the AM port of RT-Thread.


