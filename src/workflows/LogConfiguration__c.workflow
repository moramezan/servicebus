<?xml version="1.0" encoding="UTF-8"?>
<Workflow xmlns="http://soap.sforce.com/2006/04/metadata">
    <fieldUpdates>
        <fullName>UpdateLogConfigurationName</fullName>
        <field>Name</field>
        <formula>IF (
    AND( ISBLANK(DynamicGroupIdentifier__c)  , ISBLANK(StaticGroupIdentifier__c) ),
    &quot;Defines a Log Entry Grouping using the Sequence Name&quot;,
    IF (
        NOT( ISBLANK(DynamicGroupIdentifier__c) ) ,
        &quot;Defines a Log Entry Grouping using the data object&apos;s &quot; + DynamicGroupIdentifier__c + &quot; field&quot;,
        IF (
            NOT( ISBLANK(StaticGroupIdentifier__c) ),
            &quot;Defines a Log Entry Grouping using the constant &quot; + StaticGroupIdentifier__c,
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
