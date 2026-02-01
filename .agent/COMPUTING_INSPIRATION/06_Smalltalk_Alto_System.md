# 6. Alto System Project: Smalltalk Demonstration

**Speaker**: Dan Ingalls  
**URL**: https://www.youtube.com/watch?v=uknEhXyZgsg
**Duration**: 2 hours, 8 minutes, 2 seconds  
**Channel**: Computer History Museum

---

Dan Ingalls discusses the evolution of Smalltalk, from its early versions like Smalltalk-72, designed for educational purposes with revolutionary message-sending ideas but hampered by slow execution and ambiguity, to Smalltalk-76, which introduced a compiled syntax for faster, unambiguous execution, inheritance, and a more robust object model (0:20-9:32). He explains his role in the project, including building the first interpreter and porting it to the Alto (9:42-12:56). Ingalls details Smalltalk-76's architecture, including its memory management, bytecode compilation, and the significance of its "live coding" environment (13:54-29:55). He demonstrates how users can modify system behavior on the fly, such as text selection highlighting and smooth scrolling, recounting how these capabilities impressed Steve Jobs (32:10-48:22, 52:13-55:38). Finally, Ingalls touches upon later implementations like Smalltalk-78, its portability, and the impact of the BitBLT primitive on graphics and system compactness (48:35-59:02).

Here's a breakdown of the key information:

Smalltalk-72's foundations: Began with Alan Kay's ideas and focused on "sending messages" as a revolutionary concept for programming (0:37-1:06). It was used for educational purposes and allowed users to define classes and object responses simply (1:42-1:55). However, it ran very slowly due to parsing programs as they ran (2:00-2:13) and programs' meanings were ambiguous without execution, preventing compilation for speed (2:19-3:00).
Smalltalk-76's advancements: Introduced a modern, unambiguous syntax that allowed for compilation, leading to significantly faster execution (3:07-3:24, 13:54-15:00). It supported inheritance, enabling code reuse (23:21-23:25). The system was also built with "first-class objects" for its meta-system and stack frames, making the debugger easy to write in Smalltalk itself (9:05-9:27, 23:56-24:18).
Memory and architecture: Smalltalk-76 ran on the Alto, which had limited memory (4:48-5:14). Smalltalk-78 introduced a virtual memory system to address more objects than physical memory allowed (5:45-7:10). The kernel operations were designed to fit into microcode for better performance on the Alto (19:03-19:14).
Dan Ingalls's role: He was responsible for building the first Smalltalk interpreter, initially in BASIC, and later porting it to the Alto (11:19-12:24).
Live coding and user interface: Smalltalk systems traditionally allowed for live coding, meaning the system could be changed while running (19:25-19:46). The system pioneered graphical user interface (GUI) aspects like overlapping windows and popup menus (19:55-20:12).
Steve Jobs's demonstrations: Ingalls showcased live code changes for text selection highlighting (32:10-42:52) and smooth scrolling (46:03-48:22, 54:40-55:38) to Steve Jobs, who was impressed by these capabilities.
BitBLT primitive: This single primitive could handle all graphics operations like character display, line drawing, and text scrolling, leading to a much smaller interpreter size in later versions like Smalltalk-78 (49:50-50:17, 59:02-59:09). Its self-defined bitmap display model contributed to Smalltalk's remarkable portability across different operating systems (57:56-58:12).
