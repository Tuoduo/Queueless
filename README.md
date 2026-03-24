# QueueLess
Our mission is to provide a cost-effective and agile system that prioritizes customer satisfaction. By integrating technology into daily workflows, 
we aim to reduce expenses and save time for both owners and customers.  

Key Features:  
-> Online Queue Registration: Customers can join a line from their mobile devices without being physically present.  
-> Real-time Position Tracking: Users can see their exact place in the queue and estimated waiting times.  
-> Smart Inventory Management: Business owners can track stock levels (e.g., baklava, churros) and set items as "out-of-stock" manually or automatically.  
-> VIP & Urgent Prioritization: Owners can prioritize specific cases to handle urgent or VIP customers first.  
-> Secure Authentication: User data is protected through a secure login mechanism.  

Architecture:  
&nbsp;&nbsp;&nbsp;&nbsp;We followed a Layered Architecture to ensure a clear separation between the User Interface, Business Management, and Database layers.  
-> Event-Driven Approach: The system uses an "Event Bus" to handle asynchronous interactions, such as updating the queue UI the moment a new customer joins .  
-> Design Pattern: We implemented the Observer Pattern. The QueueManager acts as the Subject that automatically notifies all Customer (Observer) objects when the queue order changes.  

Technical Details:  
-> Frontend: Flutter (Web & Mobile)  
-> Backend: .NET / C# (Web API)  
-> Database: PostgreSQL (SQL)  
-> Patterns: Observer Pattern (C++ core logic included)  
