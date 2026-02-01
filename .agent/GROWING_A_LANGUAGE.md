# Growing a Language by Guy Steele

Summarize the transcript line by line, removing only unnecessary information to reach the conclusions.

URL: https://www.youtube.com/watch?v=lw6TaiXzHAE
Catalog number: 102706476
Lot number: X6636.2013

---

This talk, titled "Growing a Language," by Guy Steele, emphasizes that programming languages must evolve and grow over time (13:34) to remain relevant and effective. Steele argues against designing a language as a fixed, complete entity, advocating instead for a design that anticipates and facilitates ongoing development by its user community.

Key points include:

(0:48-8:01) The speaker demonstrates the difficulty of expressing complex ideas in a very limited vocabulary, likening it to programming in a small language.
(10:17-10:24) He highlights that basic concepts often require extensive definitions in small languages.
(11:31-11:35) This leads to a need to "add to the small language to make a language that is more large."
(13:34-13:37) The central argument is that language designers should "design a language that can grow," rather than aiming for a fixed small or large language.
(15:12-16:22) Historically, languages like Fortran grew significantly, while others like Pascal, without a growth plan, faced limitations.
(17:05-18:03) Steele endorses the "worse is better" philosophy, suggesting that a quickly adopted, even imperfect, language will gain traction over a perfectly designed one that takes too long to develop.
(20:16-22:01) He contrasts APL, which lacked mechanisms for user-driven growth, with Lisp, where user-defined features could seamlessly integrate as primitives, enabling rapid expansion by its user community.
(22:34-22:43) A primary goal for modern language design is to plan for growth, allowing the language to evolve as its user base expands.
(23:10-23:52) Growth can involve adding vocabulary (libraries) or modifying rules of meaning. Crucially, user-defined extensions should appear indistinguishable from built-in primitives.
(25:52-28:11) Steele advocates for the "bazaar" model of development, where a distributed community contributes, over the "cathedral" model. The bazaar model allows the design plan to "change in real time" based on user needs, fostering greater user engagement.
(29:13-30:08) Quoting Christopher Alexander, he emphasizes that "master plans alienate the users" by limiting their influence, making it essential to empower users to contribute.
(30:44-31:41) Instead of designing a fixed "thing," designers should create a "pattern" – a framework that outlines how a language can grow and change over time, leaving specific choices for later.
(33:18-40:51) Steele specifically suggests that the Java programming language should add generic types and allow users to define overloaded operators. These features would enable users to extend Java in a "smooth and clean way," making user-defined types (like complex numbers or vectors) behave like built-in ones.
(39:18-41:34) He argues against including every specialized type directly in the core language, proposing instead that the language provides "tools" for users to build their own types and libraries.
(42:21-42:27) The core message is that modern language design is no longer about creating a static "thing," but about designing a "pattern for language designs"—a tool for making more tools.
(42:53-43:00) A good programmer today "builds a working vocabulary" on top of a base language, effectively engaging in language design.
(45:25-45:54) The conclusion reiterates that the sole way to succeed is to "plan for growth with help from users," with careful curation of their contributions.
(47:21-47:49) Designers may even strategically introduce minor flaws ("warts") for a quick release, with a plan for later removal.
