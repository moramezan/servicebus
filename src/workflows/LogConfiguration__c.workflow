<?xml version="1.0" encoding="UTF-8"?>
<Workflow xmlns="http://soap.sforce.com/2006/04/metadata">
    <fieldUpdates>
        <fullName>UpdateLogConfigurationName</fullName>
        <field>Name</field>
        <formula>IF (
    AND(ISBLANK(DynamicGroupIdentifier__c), ISBLANK(StaticGroupIdentifier__c)),
    LEFT(&quot;Creates a Log Group based on the name of this sequence&quot;, 80),
    IF(
        NOT(ISBLANK(DynamicGroupIdentifier__c)),
        LEFT(&quot;Creates a Log Group named by &apos;&quot; + DynamicGroupIdentifier__c + &quot;&apos; on the message data&quot;, 80),
        IF(
            NOT(ISBLANK(StaticGroupIdentifier__c)),
            LEFT(&quot;Creates a Log Group named &apos;&quot; + StaticGroupIdentifier__c + &quot;&apos;&quot;, 80),
            &quot;never gets here&quot;
        )
    )
)</formula>
        <name>Update Log Configuration Name</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Formula</operation>
        <protected>false</protected>
    </fieldUpdates>
    <rules>
        <fullName>OnLogInitializerConfigurationUpsert</fullName>
        <actions>
            <name>UpdateLogConfigurationName</name>
            <type>FieldUpdate</type>
        </actions>
        <active>true</active>
        <formula>true</formula>
        <triggerType>onAllChanges</triggerType>
    </rules>
</Workflow>
