# 22. Instruction-Level Parallelism - Joseph Fisher

**Speaker**: Joseph A. Fisher  
**URL**: https://www.youtube.com/watch?v=Ri-9vA2Xltg
**Duration**: 1 hour, 30 minutes, 28 seconds  
**Channel**: Computer History Museum

---

Joseph A. Fisher's lecture on Instruction-Level Parallelism (ILP) (0:28) explains how this architectural technique speeds up computers by overlapping ordinary operations without programmer intervention (0:47). He highlights its history, from early experimental machines to its rise as a "hot topic" in modern microprocessors (1:20-1:48). Fisher also addresses the controversial belief about the amount of ILP in typical programs, debunking the "Flynn bottleneck" and introducing speculative execution as a way to overcome limitations imposed by conditional branches (8:04). He then discusses the continuum between hardware-heavy superscalar machines and compiler-driven VLIW (Very Long Instruction Word) machines (24:52), emphasizing their shared goal of exploiting ILP.

Here is a breakdown of key points and their timestamps:

Definition of ILP: (0:31) ILP is an architectural technique at the CPU level that overlaps ordinary operations like multiplies and adds, making programs run faster transparently to the user.
Early History and Impact: (1:20) ILP has been around for over 30 years in the fastest computers, gaining significant traction in the 1980s and becoming essential for fast microprocessor design today.
Initial Pessimism ("Flynn Bottleneck"): (5:45) Early studies (early 1970s) suggested limited parallelism (1.5 to 2.5 factor speed-up), leading to a decline in interest, famously termed the "Flynn bottleneck" (7:47).
Debunking the Bottleneck: (8:04) Fisher argues this belief is wrong, citing code transformations by compilers (8:25) and, more significantly, the missed potential of conditional branches (10:25).
Speculative Execution Concept: (11:28) Rice and Foster's experiment showed huge potential parallelism (factor of 54-55 speed-up) if conditional branches could be "unwound" (11:54). While impractical with infinite hardware, this led to the idea of speculative execution (16:26), where operations are performed on a predicted branch path, with mechanisms to recover if the prediction is wrong (17:11).
Branch Predictability: (19:24) Branches are highly predictable (40% are 99.5%+ predictable), making speculative execution a viable technique for increasing ILP (20:50).
Hardware vs. Software Trade-offs: (24:52) The implementation of ILP involves a spectrum of choices between hardware and software.
Superscalar Machines: (25:11, 29:19) Hardware performs dependence analysis and scheduling, taking an ordinary sequential instruction stream and executing operations in parallel.
VLIW (Very Long Instruction Word) Machines: (25:41, 32:10) The compiler handles all dependence analysis and scheduling, producing code that the hardware simply executes without complex control.
Pipelining and Superpipelining: (34:03) Both superscalar and VLIW machines benefit from pipelined functional units to allow new operations to start before previous ones finish, and superpipelining (35:20) further increases the issue rate by speeding up the clock.
Challenges of Speculative Execution: (38:41) While implementation is tractable (39:15), a major challenge is handling exceptions (39:47), particularly with speculative loads (42:34).
