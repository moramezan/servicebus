<?xml version="1.0" encoding="UTF-8"?>
<Workflow xmlns="http://soap.sforce.com/2006/04/metadata">
    <fieldUpdates>
        <fullName>UpdateSubscribeConfigurationName</fullName>
        <field>Name</field>
        <formula>IF(
    ISBLANK(EventType__c),
    &quot;This step must be configured.&quot;,
    &quot;Fires when the &apos;&quot; + EventType__r.Name + &quot;&apos; event is published.&quot;
)</formula>
        <name>Update Subscribe Configuration Name</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Formula</operation>
        <protected>false</protected>
    </fieldUpdates>
    <rules>
        <fullName>OnSubscribeConfigurationUpsert</fullName>
        <actions>
            <name>UpdateSubscribeConfigurationName</name>
            <type>FieldUpdate</type>
        </actions>
        <active>true</active>
        <formula>true</formula>
        <triggerType>onAllChanges</triggerType>
    </rules>
</Workflow>
