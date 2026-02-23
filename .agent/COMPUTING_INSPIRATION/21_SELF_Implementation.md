# 21. SELF Implementation - Urs Holzle

**Speaker**: Urs Holzle  
**URL**: https://www.youtube.com/watch?v=6SO4t6VnSv8
**Duration**: 26 minutes, 12 seconds  
**Channel**: Computer History Museum

---
Urs Hölzle's lecture, "A Third Generation SELF Implementation," discusses the challenges and solutions in combining responsiveness and efficiency in programming environments, particularly for object-oriented languages like Smalltalk or SELF. He introduces adaptive recompilation as a key technique used in the Self-93 system to achieve both fast reaction times and optimized code execution. The talk also emphasizes the importance of pause clustering as a method for accurately measuring user-perceived pauses in interactive systems, arguing against the use of raw pause times for such evaluations.

Here are the key aspects that lead to these conclusions:

Introduction to the Problem: (1:02-2:01) The speaker introduces the two main attributes desired in programming environments: responsiveness (immediate reaction to commands) and efficiency (programs running quickly).
Conflicting Goals: (2:26-3:21) Hölzle explains that responsiveness and efficiency are conflicting goals; optimizing compilers provide efficiency but introduce pauses, while interpreters are responsive but less efficient. The ideal is to achieve both.
Dynamic Compilation (Smalltalk): (4:40-5:25) Peter Deutsch and Allan Schiffman's Smalltalk system improved efficiency by using dynamic compilation, compiling source methods into machine code the first time they are called.
Dynamic Optimizing Compilation (Self-89, Self-91): (5:40-6:25) The first two Self implementations introduced dynamic optimizing compilation to generate faster code, but this led to noticeable pauses in interactive environments.
Adaptive Recompilation (Self-93): (8:29-9:12) The Self-93 system addresses the pause problem by introducing adaptive recompilation, optimizing only the "hotspots" of the program. It uses a fast non-optimizing compiler initially, followed by a slower optimizing compiler for frequently executed code.
Improved Responsiveness Demonstration: (10:49-11:16) Hölzle demonstrates the significantly reduced pauses in the Self-93 system compared to earlier versions, showing near-interpreter-like responsiveness.
Pause Clustering for Evaluation: (16:10-17:48) The speaker argues that raw pause times are "meaningless" for interactive performance and introduces pause clustering to accurately capture the user's experience by grouping short, successive pauses into longer perceived pauses.
Impact of Pause Clustering: (18:58-20:01) A graph demonstrates the significant difference in perceived pause lengths when using pause clustering, highlighting that individual pause measurements can be misleadingly optimistic.
Conclusion: (23:12-24:48) The Self-93 system successfully combines performance and interpreter-like responsiveness through adaptive recompilation, aided by advances in hardware. It emphasizes that pause clustering is crucial for evaluating interactive systems.
