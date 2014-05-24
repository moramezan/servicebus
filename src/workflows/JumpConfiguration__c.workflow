<?xml version="1.0" encoding="UTF-8"?>
<Workflow xmlns="http://soap.sforce.com/2006/04/metadata">
    <fieldUpdates>
        <fullName>UpdateJumpConfigurationName</fullName>
        <description>Generates a friendly description of the configured behaviour.</description>
        <field>Name</field>
        <formula>IF(
    ISBLANK(Sequence__c),
    &quot;This step must be configured&quot;,
    &quot;Diverts message to sequence &apos;&quot; + Sequence__r.Name + &quot;&apos;, never to return&quot;
)</formula>
        <name>Update Jump Configuration Name</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Formula</operation>
        <protected>false</protected>
    </fieldUpdates>
    <rules>
        <fullName>OnJumpConfigurationUpsert</fullName>
        <actions>
            <name>UpdateJumpConfigurationName</name>
            <type>FieldUpdate</type>
        </actions>
        <active>true</active>
        <description>Generates a friendly description of the configured behaviour.</description>
        <formula>true</formula>
        <triggerType>onAllChanges</triggerType>
    </rules>
</Workflow>
