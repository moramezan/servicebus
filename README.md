# Apex Microservice Open Specification

The Apex Microservice Open Specification evolved in a crazy way. It started two years ago by writing down some services we wanted to be able to run on Salesforce, regardless of whether they were implementable. Then we started to reverse-engineer a container for them.

That process showed us how we needed to change the services to make them behave more consistently, and also to make them orchestratable. How to better define their boundaries whether they are consumed synchronously or with a message-driven API. Iterating like this, the definition advanced to the stage where it extends effortlessly to meet new requirements.

AMOS is used every day in AppExchange products and by Salesforce consultants. If you like the results, please comment and contribute.

# Goals

**Avoid package dependencies**. These [become difficult to manage if there is shared code leveraged in multiple apps](https://success.salesforce.com/ideaview?id=08730000000BqDaAAK). Prefer callee-agnostic service inputs and outputs while maintaining expressiveness, like `Map<String,Object>`

**Avoid service state**. Maintaining portability between Sandbox and Production environments encourages low coupling and stateless services, favoured for easier debugging and unit testing.

**Avoid cross cutting concerns**. Anything secondary to the meaningful business intent of a service must be the responsibility of a container, instead of being duplicated inside the service:
- **Governor limit management**; if the service is limit-bound, that must form part of the service definition.
- **Savepoints and rollback**; automatic, services succeed or fail entirely as one transaction by default.
- **Exception handling**; the input data and call stack trace must be preserved for later examination and replay.
- **Bulkification**; one invocation must not inhibit subsequent invocations, side effects separate from callouts.
- **Persistence**; transient data for service communication must not require service-specific staging objects.

**Be context agnostic**. Apex triggers, Batch jobs, Future methods, Schedulable context, DML operations on setup objects. Web service callouts. These must not have implications on what we can and can't do.

**Be discoverable**. Business functions spawn a diversity of services. Their existence must be apparent using supported Apex reflection mechanisms. But without [entering their namespaces](https://developer.salesforce.com/docs/atlas.en-us.salesforce_app_limits_cheatsheet.meta/salesforce_app_limits_cheatsheet/salesforce_app_limits_platform_apexgov.htm#d28247e121); a tightly governed limit.

# Signature

Each service is a single, logical Apex program:
- it handles one input,
- it emits zero, one, or many outputs,

```
Event[] execute(Event);
```

The service inputs and outputs take the form of events. An event is a loosely structured object with parameters set as keys and values. All event parameters are optional. These domain-agnostic events can be routed in different ways to the services that operate on them.
