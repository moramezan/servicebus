<?xml version="1.0" encoding="UTF-8"?>
<Workflow xmlns="http://soap.sforce.com/2006/04/metadata">
    <fieldUpdates>
        <fullName>UpdatePublishConfigurationName</fullName>
        <field>Name</field>
        <formula>IF(
    ISBLANK(EventType__c),
    &quot;This step must be configured&quot;,
    &quot;Fires all sequences subscribed to the &apos;&quot; + EventType__r.Name + &quot;&apos; event&quot;
)</formula>
        <name>Update Publish Configuration Name</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Formula</operation>
        <protected>false</protected>
    </fieldUpdates>
    <rules>
        <fullName>OnPublishConfigurationUpsert</fullName>
        <actions>
            <name>UpdatePublishConfigurationName</name>
            <type>FieldUpdate</type>
        </actions>
        <active>true</active>
        <formula>true</formula>
        <triggerType>onAllChanges</triggerType>
    </rules>
</Workflow>
