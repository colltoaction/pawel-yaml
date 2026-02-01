# 2. Program Structure in Distributed Systems

**Speaker**: Barbara Liskov  
**URL**: https://www.youtube.com/watch?v=8M0wTX6EOVI
**Duration**: 46 minutes, 35 seconds  
**Channel**: Computer History Museum

---

Barbara Liskov discusses her work in distributed computing, focusing on the challenges of building reliable software for interconnected machines (1:58-2:38). She introduces Thor, an object-oriented database system designed to simplify distributed application development by handling generic issues like replication, fault tolerance, and caching (3:37-3:50, 32:30-33:09). Liskov emphasizes Thor's ability to support heterogeneous environments and its use of atomic transactions for data consistency (17:29-17:49, 22:53-23:37). She also highlights the need for a better communication mechanism within Thor to improve notification processes (33:30-34:20), suggesting that databases could function as a "Blackboard" for client communication (34:20-34:48).

Here is a bullet list of key information:

Introduction to Distributed Computing: Liskov began working in distributed computing around 1979, focusing on the challenge of building software for networked computers (2:01-2:38).
Argus Programming Language: Her first project in the area was designing Argus, a programming language for building distributed applications (2:44-2:56).
Transition to Thor: After Argus, her work evolved to address issues like replication algorithms and sharing in heterogeneous networks, leading to the Thor project (3:06-3:40).
Challenges in Distributed Applications: Building distributed applications is difficult because developers must solve many generic problems (5:27-6:11).
Thor's Purpose: Thor aims to provide heterogeneous access in a distributed environment to a universe of encapsulated, strongly-typed, and extensible objects (17:29-19:57).
Persistent and Highly Available Storage: Thor's persistent object storage is reliable and highly available, with automatic garbage collection (20:23-20:47).
Client Interaction with Thor: Client programs interact with Thor objects by calling their methods, with all calls occurring within atomic transactions for synchronization and consistency (20:51-23:37).
Heterogeneity Support: Thor supports heterogeneity by using its own language for object implementation (Theta) and providing "veneers" (thin layers of code) for client programs written in different languages (24:21-27:14).
Thor's Architecture: Thor is built on a client-server model, with object repositories (ORs) for persistent storage and front-ends at client workstations to manage communication and caching (28:34-31:22).
Improving Performance: Caching objects at the front end is crucial for reducing response times and offloading work from servers (31:53-32:23).
Thor's Contribution to Application Development: Thor handles generic issues like replication, fault tolerance, caching, and cache invalidation, allowing application programmers to focus on application-specific logic (32:50-33:09).
Need for Notification Mechanism: A current limitation of Thor is the lack of a robust notification mechanism, requiring polling to detect changes in the database (33:30-34:20).
Database as a "Blackboard": Liskov proposes using the database as a communication "Blackboard" to decouple senders and receivers, allowing for more sophisticated and persistent notifications (34:20-36:51).
Future Challenges: Key challenges for Thor include determining the optimal communication mechanisms and ensuring their efficient implementation (37:10-37:48).
