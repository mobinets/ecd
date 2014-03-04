#ifndef PR_H
#define PR_H

#ifdef ENABLE_PR
  #ifndef PLATFORM_PC
    #include "PrintfUART.h"
    #define pr_init()   printfUART_init()
    #define pr(fmt, args...) do { printfUART(fmt, ##args); } while (0)
  #else
    #define pr_init()
    #define pr(fmt, args...) dbg("DBG_USR1", fmt, ##args)
  #endif 
#else
  #define pr_init()
  #define pr(fmt, args...) 
#endif // ENABLE_PR

#endif /* PR_H */
