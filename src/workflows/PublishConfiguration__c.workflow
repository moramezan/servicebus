<?xml version="1.0" encoding="UTF-8"?>
<Workflow xmlns="http://soap.sforce.com/2006/04/metadata">
    <fieldUpdates>
        <fullName>UpdatePublishConfigurationName</fullName>
        <description>Generates a friendly description of the configured behaviour.</description>
        <field>Name</field>
        <formula>IF(
    ISBLANK(EventType__c),
    LEFT(&quot;This step must be configured&quot;, 80),
    LEFT(&quot;Broadcasts the message to all sequences subscribed to &apos;&quot; + EventType__r.Name + &quot;&apos;&quot;, 80)
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
        <description>Generates a friendly description of the configured behaviour.</description>
        <formula>true</formula>
        <triggerType>onAllChanges</triggerType>
    </rules>
</Workflow>
