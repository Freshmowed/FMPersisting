# FMPersisting
Lightweight, opinionated ORM over fmdb sqlite framework

This framework provides a straightforward mapping between Objective-C model classes and sqlite databases.
It consists of just two classes: FMPersistingModel and FMPersistenceManager. FMPersistingModel can be used 
as a superclass of "model" objects that get persisted using the fmdb sqlite framework.  In many situations, 
the model subclass need only implement two methods: -tableName and -columns, which define the mapping between
a class and table name, and properties-to-columns. The PersistenceManager class will handle table creation 
(if necessary), and the subclass-to-db-table mapping for fetching, inserting, updating.

The FMPersistenceManager class provides all the standard CRUD operations for FMPersistingModel subclasses.
