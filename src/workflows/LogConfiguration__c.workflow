<?xml version="1.0" encoding="UTF-8"?>
<Workflow xmlns="http://soap.sforce.com/2006/04/metadata">
    <fieldUpdates>
        <fullName>UpdateLogConfigurationName</fullName>
        <field>Name</field>
        <formula>IF (
    AND( ISBLANK(GroupInstruction__c)  , ISBLANK(GroupIdentifier__c) ),
    &quot;Defines a Log Entry Grouping using the Chain Name&quot;,
    IF (
        NOT( ISBLANK(GroupInstruction__c) ) ,
        &quot;Defines a Log Entry Grouping using the data object&apos;s &quot; + GroupInstruction__c + &quot; field&quot;,
        IF (
            NOT( ISBLANK(GroupIdentifier__c) ),
            &quot;Defines a Log Entry Grouping using the constant &quot; + GroupIdentifier__c,
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
