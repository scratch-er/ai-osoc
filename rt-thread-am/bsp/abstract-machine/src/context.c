#include <am.h>
#include <klib.h>
#include <rtthread.h>

struct thread_start_args {
  void (*tentry)(void *);
  void *parameter;
  void (*texit)(void);
};

static Context **switch_from = NULL;
static Context **switch_to = NULL;

static Context* ev_handler(Event e, Context *c) {
  switch (e.event) {
    case EVENT_YIELD:
      if (switch_from != NULL) {
        *switch_from = c;
      }
      if (switch_to != NULL) {
        c = *switch_to;
      }
      switch_from = NULL;
      switch_to = NULL;
      break;
    default: printf("Unhandled event ID = %d\n", e.event); assert(0);
  }
  return c;
}

void __am_cte_init() {
  cte_init(ev_handler);
}

void rt_hw_context_switch_to(rt_ubase_t to) {
  switch_from = NULL;
  switch_to = (Context **)to;
  yield();
}

void rt_hw_context_switch(rt_ubase_t from, rt_ubase_t to) {
  switch_from = (Context **)from;
  switch_to = (Context **)to;
  yield();
}

void rt_hw_context_switch_interrupt(rt_ubase_t from, rt_ubase_t to, rt_thread_t from_thread, rt_thread_t to_thread) {
  assert(0);
}

static void thread_start(void *arg) {
  struct thread_start_args *args = (struct thread_start_args *)arg;
  args->tentry(args->parameter);
  args->texit();
  assert(0);
}

rt_uint8_t *rt_hw_stack_init(void *tentry, void *parameter, rt_uint8_t *stack_addr, void *texit) {
  uintptr_t sp = (uintptr_t)stack_addr;
  sp &= ~(uintptr_t)(sizeof(uintptr_t) - 1);
  sp -= sizeof(struct thread_start_args);

  struct thread_start_args *args = (struct thread_start_args *)sp;
  args->tentry = (void (*)(void *))tentry;
  args->parameter = parameter;
  args->texit = (void (*)(void))texit;

  Area stack = { .start = NULL, .end = args };
  return (rt_uint8_t *)kcontext(stack, thread_start, args);
}
