# Instruction-Level Parallelism (ILP) by Joseph A. Fisher

Summarize the transcript line by line, keeping only necessary information to reach the conclusions.

URL: https://www.youtube.com/watch?v=Ri-9vA2Xltg
Catalog number: 102624696
Lot number: X6636.2013

---

Instruction-Level Parallelism (ILP) Defined 
(0:31): ILP is an architectural technique that allows the overlap of ordinary operations at the CPU level, making programs run faster without programmer intervention.

Early History and Impact 
(1:20): An old technique (over 30 years), ILP gained significant traction in the 1980s, becoming essential for fast microprocessors.

Illustrative Example of ILP 
(1:52): By overlapping operations (e.g., multiply and add), a task that might take 12 cycles sequentially could be completed in 6 cycles, demonstrating a factor of two speedup.

Historical Influence and Controversy 
(4:01): The development of ILP has been heavily influenced by beliefs about how much parallelism exists in typical programs, a question that remains controversial.

Early Parallelism Studies and Pessimism 
(5:45): Early studies with "infinite hardware" showed limited parallelism (1.5 to 2.5 factor speedup), leading to pessimism and a decline in interest in ILP.

Critique of Limit Studies: Code Transformations 
(8:04): The belief that parallelism was limited was wrong because compilers can perform code transformations to expose more ILP, a factor missed by early studies.

Critique of Limit Studies: Conditional Branches 
(10:23): A major flaw in early studies was the assumption that operations couldn't be moved past conditional branches due to potential side effects.

Rau and Foster's Experiment: Unwinding Paths 
(11:27): An experiment by Rau and Foster suggested unwinding every possible computation path to overcome the conditional branch problem, showing a huge potential speedup (average 54-55 factor).

Impracticality of Early Branch-Handling 
(14:18): Despite the high potential parallelism, their method required an impractical amount of hardware (e.g., 64,000 machine copies for a 10x speedup), leading to its dismissal.

The "Correct" Conclusion 
(15:55): The actual correct conclusion should have been that significant ILP exists, but a more practical way to tap into it was needed.

Speculative Execution as a Solution 
(16:02): This led to the idea of speculative execution, which involves picking a likely branch direction and executing operations from it, while ensuring the ability to recover if the prediction is wrong.

Branch Predictability 
(18:50): Branches are highly predictable (e.g., 40% of branches are predictable >99.5% of the time), making speculative execution a viable strategy for gaining speedup.

Two Approaches: Superscalar vs. VLIW 
(25:07): There are two main approaches to implement ILP:

Superscalar 
(25:34): Hardware performs dependence analysis and scheduling, taking an ordinary instruction stream and figuring out how to execute multiple operations simultaneously.

VLIW (Very Long Instruction Word) 
(26:07): The compiler handles all dependence analysis and scheduling before runtime, creating long instruction words that the hardware simply executes.

Speculative Execution Implementation 
(38:46): Techniques for implementing speculative execution include using shadow registers to store speculative results, or renaming variables to avoid unintended side effects.

The Exception Problem with Speculative Loads 
(43:24): A significant challenge with speculative execution, particularly with loads, is handling exceptions (e.g., loading past the end of an array) that occur on mispredicted paths.
